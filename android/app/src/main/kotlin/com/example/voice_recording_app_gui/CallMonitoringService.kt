package com.example.voice_recording_app_gui

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Foreground service that records call-adjacent audio chunks from microphone,
 * runs on-device inference per chunk, and alerts on suspicious/fake detections.
 */
class CallMonitoringService : Service() {

    private val running = AtomicBoolean(false)
    private val worker = Executors.newSingleThreadExecutor()
    private var onnxHelper: OnnxHelper? = null
    private var wav2vec2Extractor: Wav2Vec2Extractor? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        onnxHelper = OnnxHelper(this)
        wav2vec2Extractor = Wav2Vec2Extractor(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        when (action) {
            ACTION_STOP -> {
                stopMonitoring()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                startMonitoring()
                return START_STICKY
            }
            else -> return START_STICKY
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startMonitoring() {
        if (running.getAndSet(true)) {
            return
        }

        startForeground(NOTIFICATION_ID_FOREGROUND, ongoingNotification("Starting call monitoring..."))

        worker.submit {
            runCatching { onnxHelper?.loadEnsembleModels() }
                .onFailure { Log.w(TAG, "Could not pre-load ensemble models: ${it.message}") }

            while (running.get()) {
                val chunkSeconds = CallMonitorPrefs.chunkSeconds(this)
                val chunkFile = File(cacheDir, "call_chunk_${System.currentTimeMillis()}.m4a")
                val recorded = recordChunk(chunkFile, chunkSeconds)
                if (!running.get()) break

                if (!recorded) {
                    updateOngoingNotification("Chunk capture failed; retrying...")
                    safeDelete(chunkFile)
                    continue
                }

                val outcome = analyzeChunk(chunkFile)
                safeDelete(chunkFile)

                if (outcome == null) {
                    updateOngoingNotification("Chunk analyzed: no score")
                    continue
                }

                val scorePercent = (outcome.syntheticProbability * 100.0)
                val band = when {
                    outcome.syntheticProbability > 0.45 -> "fake"
                    outcome.syntheticProbability > 0.15 -> "suspicious"
                    else -> "safe"
                }
                updateOngoingNotification("Last chunk: $band (${String.format("%.1f", scorePercent)}% synthetic)")

                when {
                    outcome.syntheticProbability > 0.45 -> {
                        pushRiskAlert(
                            title = "Potentially Fake Voice Detected",
                            text = "High-risk chunk: ${String.format("%.1f", scorePercent)}% synthetic.",
                            shouldVibrate = CallMonitorPrefs.vibrateAlert(this),
                        )
                    }
                    outcome.syntheticProbability > 0.15 -> {
                        pushRiskAlert(
                            title = "Suspicious Voice Pattern",
                            text = "Suspicious chunk: ${String.format("%.1f", scorePercent)}% synthetic.",
                            shouldVibrate = false,
                        )
                    }
                }
            }

            stopSelf()
        }
    }

    private fun stopMonitoring() {
        running.set(false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun recordChunk(outputFile: File, chunkSeconds: Int): Boolean {
        var recorder: MediaRecorder? = null
        return try {
            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            recorder.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(64000)
                setAudioSamplingRate(16000)
                setOutputFile(outputFile.absolutePath)
                prepare()
                start()
            }

            val endAt = System.currentTimeMillis() + (chunkSeconds * 1000L)
            while (running.get() && System.currentTimeMillis() < endAt) {
                Thread.sleep(150)
            }

            runCatching { recorder.stop() }
            true
        } catch (e: Exception) {
            Log.w(TAG, "recordChunk failed: ${e.message}")
            false
        } finally {
            runCatching { recorder?.reset() }
            runCatching { recorder?.release() }
        }
    }

    private fun analyzeChunk(audioFile: File): ChunkOutcome? {
        return try {
            val waveform = AudioDecoder.decodeTo16kMonoFloat(audioFile.absolutePath) ?: return null
            val acoustic = FeatureExtractor.extract(waveform)

            val wav2vec = wav2vec2Extractor ?: return null
            if (!wav2vec.isLoaded()) {
                val modelFile = File(filesDir, "wav2vec2_quantized.onnx")
                val loaded = if (modelFile.exists() && modelFile.length() > 0L) {
                    wav2vec.loadFromPath(modelFile.absolutePath)
                } else {
                    wav2vec.load()
                }
                if (!loaded) return null
            }

            val ssl = wav2vec.extract(waveform) ?: return null
            if (acoustic.size != 68 || ssl.size != 1024) return null

            val full = FloatArray(OnnxEnsemble.FEATURE_DIM)
            System.arraycopy(acoustic, 0, full, 0, 68)
            System.arraycopy(ssl, 0, full, 68, 1024)

            val helper = onnxHelper ?: return null
            val (probability, verdict) = helper.runEnsemble(full)
            Log.i(TAG, "chunk_result synthetic_probability=$probability verdict=$verdict")
            ChunkOutcome(probability)
        } catch (e: Exception) {
            Log.w(TAG, "analyzeChunk failed: ${e.message}")
            null
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_FOREGROUND,
                    "Call Monitoring",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Foreground service status for continuous call monitoring"
                },
            )
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ALERTS,
                    "Call Risk Alerts",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Alerts for suspicious or fake voice detection"
                },
            )
        }
    }

    private fun ongoingNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_FOREGROUND)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("Voice Sentinel monitoring active")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun updateOngoingNotification(text: String) {
        val notification = ongoingNotification(text)
        try {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID_FOREGROUND, notification)
        } catch (_: SecurityException) {
        }
    }

    private fun pushRiskAlert(title: String, text: String, shouldVibrate: Boolean) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ALERTS)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(this).notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
        } catch (_: SecurityException) {
        }

        if (shouldVibrate) {
            vibrateOnce()
        }
    }

    private fun vibrateOnce() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator.vibrate(VibrationEffect.createOneShot(300, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(300, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(300)
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun safeDelete(file: File) {
        runCatching { file.delete() }
    }

    override fun onDestroy() {
        running.set(false)
        runCatching { onnxHelper?.close() }
        onnxHelper = null
        runCatching { wav2vec2Extractor?.close() }
        wav2vec2Extractor = null
        worker.shutdownNow()
        super.onDestroy()
    }

    private data class ChunkOutcome(
        val syntheticProbability: Double,
    )

    companion object {
        private const val TAG = "VoiceSentinelCallMon"

        const val ACTION_START = "com.example.voice_recording_app_gui.ACTION_START_CALL_MONITORING"
        const val ACTION_STOP = "com.example.voice_recording_app_gui.ACTION_STOP_CALL_MONITORING"

        private const val CHANNEL_FOREGROUND = "voice_sentinel_monitoring"
        private const val CHANNEL_ALERTS = "voice_sentinel_risk_alerts"
        private const val NOTIFICATION_ID_FOREGROUND = 23001
    }
}
