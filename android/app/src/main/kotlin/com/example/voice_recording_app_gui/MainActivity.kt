package com.example.voice_recording_app_gui

import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.File
import java.util.concurrent.Executors
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val EXTRA_RECORD_CALL = "record_call"
        private const val TAG = "VoiceSentinelExtract"
    }

    private val channelName = "com.example.voice_recording_app_gui/onnx"
    private var pendingRecordCall = false

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkRecordCallIntent(intent)
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        checkRecordCallIntent(intent)
    }

    private fun checkRecordCallIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_RECORD_CALL, false) == true) {
            pendingRecordCall = true
        }
    }
    private var onnxHelper: OnnxHelper? = null
    private var wav2vec2Extractor: Wav2Vec2Extractor? = null
    private val bgExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        onnxHelper = OnnxHelper(this)
        wav2vec2Extractor = Wav2Vec2Extractor(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndClearRecordCallIntent" -> {
                    val had = pendingRecordCall
                    pendingRecordCall = false
                    result.success(had)
                }
                "extractFeaturesFromAudio" -> {
                    val audioPath = call.argument<String>("audioPath")
                    val wav2vecModelPath = call.argument<String>("wav2vecModelPath")
                    if (audioPath.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "audioPath is required", null)
                        return@setMethodCallHandler
                    }
                    bgExecutor.submit {
                        try {
                            val waveform = AudioDecoder.decodeTo16kMonoFloat(audioPath)
                            if (waveform == null) {
                                mainHandler.post { result.error("DECODE_FAILED", "Could not decode audio file", null) }
                                return@submit
                            }
                            val acousticFeatures = FeatureExtractor.extract(waveform)
                            val wav2vec = wav2vec2Extractor
                            if (wav2vec == null) {
                                mainHandler.post { result.error("WAV2VEC2_UNAVAILABLE", "Wav2Vec2 extractor not initialized", null) }
                                return@submit
                            }
                            if (!wav2vec.isLoaded()) {
                                val loaded = if (!wav2vecModelPath.isNullOrEmpty()) {
                                    val file = File(wav2vecModelPath)
                                    if (!file.exists() || file.length() == 0L) {
                                        mainHandler.post { result.error("WAV2VEC2_UNAVAILABLE", "Downloaded model file not found or empty. Try downloading again from Settings.", null) }
                                        return@submit
                                    }
                                    wav2vec.loadFromPath(wav2vecModelPath)
                                } else {
                                    wav2vec.load()
                                }
                                if (!loaded) {
                                    mainHandler.post { result.error("WAV2VEC2_UNAVAILABLE", "Wav2Vec2 model not found. Please wait for the model to download.", null) }
                                    return@submit
                                }
                            }
                            val sslFeatures = wav2vec.extract(waveform)
                            if (sslFeatures == null) {
                                mainHandler.post { result.error("SSL_EXTRACT_FAILED", "Wav2Vec2 inference failed", null) }
                                return@submit
                            }
                            if (acousticFeatures.size != 68 || sslFeatures.size != 1024) {
                                mainHandler.post { result.error("EXTRACT_FAILED", "Feature size mismatch: acoustic=${acousticFeatures.size} ssl=${sslFeatures.size}", null) }
                                return@submit
                            }
                            val fullFeatures = FloatArray(OnnxEnsemble.FEATURE_DIM)
                            System.arraycopy(acousticFeatures, 0, fullFeatures, 0, 68)
                            System.arraycopy(sslFeatures, 0, fullFeatures, 68, 1024)

                            val acousticNonFinite = countNonFinite(acousticFeatures)
                            val sslNonFinite = countNonFinite(sslFeatures)
                            val fullNonFinite = countNonFinite(fullFeatures)
                            Log.i(
                                TAG,
                                "feature_check waveform=${waveform.size} acoustic=${acousticFeatures.size} ssl=${sslFeatures.size} full=${fullFeatures.size} nonFinite(acoustic=$acousticNonFinite, ssl=$sslNonFinite, full=$fullNonFinite)"
                            )
                            if (fullNonFinite > 0) {
                                mainHandler.post {
                                    result.error(
                                        "EXTRACT_FAILED",
                                        "Feature integrity check failed: $fullNonFinite non-finite values",
                                        null
                                    )
                                }
                                return@submit
                            }

                            mainHandler.post { result.success(fullFeatures.map { it.toDouble() }) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("EXTRACT_FAILED", e.message, null) }
                        }
                    }
                }
                "loadModel" -> {
                    val path = call.argument<String>("assetPath")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "assetPath is required", null)
                        return@setMethodCallHandler
                    }
                    bgExecutor.submit {
                        try {
                            val helper = onnxHelper
                            if (helper == null) {
                                mainHandler.post { result.error("LOAD_FAILED", "ONNX helper not initialized", null) }
                                return@submit
                            }
                            helper.loadModel(path)
                            mainHandler.post { result.success("loaded") }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("LOAD_FAILED", e.message, null) }
                        }
                    }
                }
                "runInference" -> {
                    val assetPath = call.argument<String>("modelAssetPath")
                    val shapeList = call.argument<List<Int>>("inputShape")
                    val valuesList = call.argument<List<Number>>("inputValues")
                    if (assetPath == null || shapeList == null || valuesList == null) {
                        result.error("INVALID_ARGS", "modelAssetPath, inputShape, inputValues required", null)
                        return@setMethodCallHandler
                    }
                    bgExecutor.submit {
                        val helper = onnxHelper
                        if (helper == null) {
                            mainHandler.post { result.error("INFERENCE_FAILED", "ONNX helper not initialized", null) }
                            return@submit
                        }
                        val shape = shapeList.map { it.toLong() }.toLongArray()
                        val values = valuesList.map { it.toFloat() }.toFloatArray()
                        try {
                            val output = helper.runInference(assetPath, shape, values)
                            mainHandler.post { result.success(output) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("INFERENCE_FAILED", e.message, null) }
                        }
                    }
                }
                "unloadModel" -> {
                    val path = call.argument<String>("modelAssetPath")
                    if (path != null) onnxHelper?.unloadModel(path)
                    result.success(null)
                }
                "loadEnsembleModels" -> {
                    bgExecutor.submit {
                        try {
                            val helper = onnxHelper
                            if (helper == null) {
                                mainHandler.post { result.error("LOAD_FAILED", "ONNX helper not initialized", null) }
                                return@submit
                            }
                            helper.loadEnsembleModels()
                            mainHandler.post { result.success("loaded") }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("LOAD_FAILED", e.message, null) }
                        }
                    }
                }
                "runEnsemble" -> {
                    val featuresList = call.argument<List<Number>>("features")
                    if (featuresList == null || featuresList.size != OnnxEnsemble.FEATURE_DIM) {
                        result.error("INVALID_ARGS", "features must be a list of ${OnnxEnsemble.FEATURE_DIM} numbers", null)
                        return@setMethodCallHandler
                    }
                    bgExecutor.submit {
                        val helper = onnxHelper
                        if (helper == null) {
                            mainHandler.post { result.error("ENSEMBLE_FAILED", "ONNX helper not initialized", null) }
                            return@submit
                        }
                        val features = FloatArray(featuresList.size) { featuresList[it].toFloat() }
                        try {
                            val (probability, verdict) = helper.runEnsemble(features)
                            Log.i(TAG, "ensemble_result probability=$probability verdict=$verdict")
                            mainHandler.post {
                                result.success(mapOf(
                                    "probability" to probability,
                                    "verdict" to verdict,
                                ))
                            }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("ENSEMBLE_FAILED", e.message, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun countNonFinite(arr: FloatArray): Int {
        var nonFinite = 0
        for (v in arr) {
            if (!v.isFinite()) nonFinite++
        }
        return nonFinite
    }

    override fun onDestroy() {
        onnxHelper?.close()
        onnxHelper = null
        wav2vec2Extractor?.close()
        wav2vec2Extractor = null
        bgExecutor.shutdown()
        super.onDestroy()
    }
}
