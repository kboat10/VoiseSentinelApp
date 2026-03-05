package com.example.voice_recording_app_gui

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.example.voice_recording_app_gui/onnx"
    private var onnxHelper: OnnxHelper? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        onnxHelper = OnnxHelper(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
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
        super.onDestroy()
    }
}
