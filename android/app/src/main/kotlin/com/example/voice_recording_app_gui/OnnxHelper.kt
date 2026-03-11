package com.example.voice_recording_app_gui

import android.content.Context
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.File
import java.io.FileOutputStream
import java.nio.FloatBuffer
import java.util.Collections

/**
 * Loads ONNX models from assets and runs inference.
 * Supports single-model inference and full stacked-ensemble pipeline (scaler → 5 base → meta_learner).
 */
class OnnxHelper(private val context: Context) {

    private val env = OrtEnvironment.getEnvironment()
    private val sessions = mutableMapOf<String, OrtSession>()

    /**
     * Copies model from assets to cache and loads it. Call once per model before runInference.
     * @param assetPath e.g. "models/ensemble.onnx" or "models/model1.onnx"
     */
    fun loadModel(assetPath: String): String {
        val fileName = assetPath.substringAfterLast('/')
        val cacheFile = File(context.cacheDir, "onnx_$fileName")
        if (!cacheFile.exists()) {
            context.assets.open(assetPath).use { input ->
                FileOutputStream(cacheFile).use { output ->
                    input.copyTo(output)
                }
            }
        }
        if (sessions.containsKey(assetPath)) {
            sessions[assetPath]?.close()
        }
        sessions[assetPath] = env.createSession(cacheFile.absolutePath, OrtSession.SessionOptions())
        return "loaded"
    }

    /**
     * Runs inference.
     * @param modelAssetPath same path used in loadModel, e.g. "models/ensemble.onnx"
     * @param inputShape e.g. [1, 80, 100] for (batch, features, time)
     * @param inputValues flat list of Float values in row-major order
     * @return map: "output" -> list of Float (or multiple keys if model has multiple outputs)
     */
    fun runInference(
        modelAssetPath: String,
        inputShape: LongArray,
        inputValues: FloatArray
    ): Map<String, List<Float>> {
        val session = sessions[modelAssetPath]
            ?: throw IllegalStateException("Model not loaded: $modelAssetPath. Call loadModel first.")
        val inputNames = session.inputNames
        if (inputNames.isEmpty()) throw IllegalStateException("Model has no inputs")
        val inputName = inputNames.iterator().next()
        val tensor = OnnxTensor.createTensor(env, FloatBuffer.wrap(inputValues), inputShape)
        try {
            val inputs = Collections.singletonMap(inputName, tensor)
            val result = session.run(inputs)
            val outputMap = mutableMapOf<String, List<Float>>()
            for (name in session.outputNames) {
                val outputTensor = result.get(name).get() as OnnxTensor
                val shape = outputTensor.info.shape
                val numElements = shape.map { it.toInt() }.reduce(Int::times)
                val floats = extractFloatsFromTensor(outputTensor, numElements)
                if (floats != null) {
                    outputMap[name] = floats.toList()
                }
                outputTensor.close()
            }
            result.close()
            return outputMap
        } finally {
            tensor.close()
        }
    }

    /**
     * Unloads a model and frees native resources.
     */
    fun unloadModel(modelAssetPath: String) {
        sessions.remove(modelAssetPath)?.close()
    }

    /**
     * Loads all 7 models required for the stacked ensemble pipeline.
     */
    fun loadEnsembleModels() {
        for (path in OnnxEnsemble.allModels()) {
            loadModel(path)
        }
    }

    /**
     * Runs the full Serial-Parallel-Serial ensemble pipeline.
     * @param rawFeatures 1092-dim vector (centroid_mean, log_energy, mfcc_1..13, mfcc_std_1..13, mel_1..40, ssl_0..1023)
     * @return Pair(probability, verdict) where verdict is one of: real, suspicious, synthetic_probable, synthetic_definitive
     */
    fun runEnsemble(rawFeatures: FloatArray): Pair<Double, String> {
        if (rawFeatures.size != OnnxEnsemble.FEATURE_DIM) {
            throw IllegalArgumentException("Expected ${OnnxEnsemble.FEATURE_DIM} features, got ${rawFeatures.size}")
        }
        // 1. Scaler: [1, 1092] -> [1, 1092]
        val scaled = runInference(OnnxEnsemble.SCALER, longArrayOf(1L, OnnxEnsemble.FEATURE_DIM.toLong()), rawFeatures)
        val scaledList = scaled.values.single()
        val scaledVector = FloatArray(OnnxEnsemble.FEATURE_DIM) { scaledList[it] }

        // 2. Base models (parallel). Order for meta: [RF, CNN, LSTM, TCN, TSSD]
        val baseProbs = FloatArray(5)
        val shape1092x1 = longArrayOf(1L, OnnxEnsemble.FEATURE_DIM.toLong(), 1L)
        val shape1092 = longArrayOf(1L, OnnxEnsemble.FEATURE_DIM.toLong())

        OnnxEnsemble.BASE_MODELS_FOR_META.forEachIndexed { idx, modelPath ->
            val out = runInference(
                modelPath,
                if (modelPath == OnnxEnsemble.RF) shape1092 else shape1092x1,
                if (modelPath == OnnxEnsemble.RF) scaledVector else scaledVector
            )
            baseProbs[idx] = extractProbability(out)
        }

        // 3. Meta-learner: [1, 5] -> get synthetic probability (Sklearn: output[1][0][1])
        val metaOut = runInference(OnnxEnsemble.META_LEARNER, longArrayOf(1L, 5L), baseProbs)
        val pFinal = extractMetaSyntheticProbability(metaOut)

        val verdict = OnnxEnsemble.verdict(pFinal)
        return Pair(pFinal, verdict)
    }

    /** Safely extract float array from tensor; handles Float, Double, INT8, fp16, etc. */
    private fun extractFloatsFromTensor(tensor: OnnxTensor, size: Int): FloatArray? {
        tensor.getFloatBuffer()?.let { fb ->
            val arr = FloatArray(size)
            fb.get(arr)
            return arr
        }
        tensor.getDoubleBuffer()?.let { db ->
            return FloatArray(size) { db.get().toFloat() }
        }
        tensor.getByteBuffer()?.let { bb ->
            val bytes = ByteArray(size)
            bb.get(bytes)
            return FloatArray(size) { bytes[it].toInt().toFloat() }
        }
        tensor.getShortBuffer()?.let { sb ->
            return FloatArray(size) { sb.get().toFloat() }
        }
        return null
    }

    /** Extract single probability from base model output (P(synthetic)); handle [1], [1,1], or [1,2] shapes. */
    private fun extractProbability(outputMap: Map<String, List<Float>>): Float {
        val values = outputMap.values.single()
        return when (values.size) {
            1 -> values[0]
            2 -> values[1] // second class = synthetic
            else -> values[0]
        }
    }

    /** Meta-learner (Sklearn GBM): get probability of synthetic class; output[1][0][1] -> second output tensor, index 1. */
    private fun extractMetaSyntheticProbability(outputMap: Map<String, List<Float>>): Double {
        // Sklearn ONNX often has label + probabilities; we want the probabilities tensor (2 values), take [1].
        for (values in outputMap.values) {
            if (values.size >= 2) return values[1].toDouble()
            if (values.size == 1) return values[0].toDouble()
        }
        return outputMap.values.single().first().toDouble()
    }

    fun close() {
        sessions.values.forEach { it.close() }
        sessions.clear()
    }
}
