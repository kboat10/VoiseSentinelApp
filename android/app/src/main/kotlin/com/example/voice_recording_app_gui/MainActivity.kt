package com.example.voice_recording_app_gui

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val EXTRA_RECORD_CALL = "record_call"
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
                    if (audioPath == null) {
                        result.error("INVALID_ARGS", "audioPath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val waveform = AudioDecoder.decodeTo16kMonoFloat(audioPath)
                            ?: run {
                                result.error("DECODE_FAILED", "Could not decode audio file", null)
                                return@setMethodCallHandler
                            }
                        val acousticFeatures = FeatureExtractor.extract(waveform)
                        val wav2vec = wav2vec2Extractor ?: run {
                            result.error("WAV2VEC2_UNAVAILABLE", "Wav2Vec2 extractor not initialized", null)
                            return@setMethodCallHandler
                        }
                        val modelPath = call.argument<String>("wav2vecModelPath")
                        if (!wav2vec.isLoaded()) {
                            val loaded = if (modelPath != null && modelPath.isNotEmpty()) {
                                wav2vec.loadFromPath(modelPath)
                            } else {
                                wav2vec.load()
                            }
                            if (!loaded) {
                                result.error("WAV2VEC2_UNAVAILABLE", "Wav2Vec2 model not found. Download from API or run: python scripts/export_wav2vec2_onnx.py", null)
                                return@setMethodCallHandler
                            }
                        }
                        val sslFeatures = wav2vec.extract(waveform)
                            ?: run {
                                result.error("SSL_EXTRACT_FAILED", "Wav2Vec2 inference failed", null)
                                return@setMethodCallHandler
                            }
                        val fullFeatures = FloatArray(OnnxEnsemble.FEATURE_DIM)
                        System.arraycopy(acousticFeatures, 0, fullFeatures, 0, 68)
                        System.arraycopy(sslFeatures, 0, fullFeatures, 68, 1024)
                        result.success(fullFeatures.map { it.toDouble() })
                    } catch (e: Exception) {
                        result.error("EXTRACT_FAILED", e.message, null)
                    }
                }
                "loadModel" -> {
                    val path = call.argument<String>("assetPath")
                    if (path == null) {
                        result.error("INVALID_ARGS", "assetPath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        onnxHelper?.loadModel(path)
                        result.success("loaded")
                    } catch (e: Exception) {
                        result.error("LOAD_FAILED", e.message, null)
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
                    val shape = shapeList.map { it.toLong() }.toLongArray()
                    val values = valuesList.map { it.toFloat() }.toFloatArray()
                    try {
                        val output = onnxHelper?.runInference(assetPath, shape, values)
                        result.success(output)
                    } catch (e: Exception) {
                        result.error("INFERENCE_FAILED", e.message, null)
                    }
                }
                "unloadModel" -> {
                    val path = call.argument<String>("modelAssetPath")
                    if (path != null) onnxHelper?.unloadModel(path)
                    result.success(null)
                }
                "loadEnsembleModels" -> {
                    try {
                        onnxHelper?.loadEnsembleModels()
                        result.success("loaded")
                    } catch (e: Exception) {
                        result.error("LOAD_FAILED", e.message, null)
                    }
                }
                "runEnsemble" -> {
                    val featuresList = call.argument<List<Number>>("features")
                    if (featuresList == null || featuresList.size != OnnxEnsemble.FEATURE_DIM) {
                        result.error("INVALID_ARGS", "features must be a list of ${OnnxEnsemble.FEATURE_DIM} numbers", null)
                        return@setMethodCallHandler
                    }
                    val features = FloatArray(featuresList.size) { featuresList[it].toFloat() }
                    try {
                        val (probability, verdict) = onnxHelper!!.runEnsemble(features)
                        result.success(mapOf(
                            "probability" to probability,
                            "verdict" to verdict,
                        ))
                    } catch (e: Exception) {
                        result.error("ENSEMBLE_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        onnxHelper?.close()
        onnxHelper = null
        wav2vec2Extractor?.close()
        wav2vec2Extractor = null
        super.onDestroy()
    }
}
