package com.example.voice_recording_app_gui

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.nio.FloatBuffer
import java.util.Collections
import java.util.Locale
import kotlin.math.sqrt

/**
 * Extracts 1024-dim SSL features from waveform using Wav2Vec2 encoder ONNX.
 * Input: 16kHz mono float waveform.
 * Output: mean-pooled last_hidden_state (1024 dims).
 */
class Wav2Vec2Extractor(private val context: Context) {

    companion object {
        const val ASSET_PATH = "models/onnx_models/wav2vec2_encoder.onnx"
        const val EMBEDDING_DIM = 1024
    }

    private val env = OrtEnvironment.getEnvironment()
    private var session: OrtSession? = null

    fun isLoaded(): Boolean = session != null

    /**
     * Load the Wav2Vec2 encoder ONNX model from assets. Call once before extract.
     */
    fun load(): Boolean {
        return try {
            val cacheFile = File(context.cacheDir, "wav2vec2_encoder.onnx")
            if (!cacheFile.exists()) {
                try {
                    context.assets.open(ASSET_PATH).use { input ->
                        FileOutputStream(cacheFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                } catch (_: Exception) {
                    return false
                }
            }
            session?.close()
            session = env.createSession(cacheFile.absolutePath, OrtSession.SessionOptions())
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Load the Wav2Vec2 encoder from a file path (e.g. downloaded from API).
     */
    fun loadFromPath(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return false
            session?.close()
            session = env.createSession(file.absolutePath, OrtSession.SessionOptions())
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Extract 1024-dim SSL embedding from waveform.
     * Supports both standard and quantized Wav2Vec2 models (dynamic input/output names).
     * @param waveform 16kHz mono float array, normalized (zero mean, unit variance recommended)
     * @return FloatArray of 1024 dims, or null if model not loaded or inference fails
     */
    fun extract(waveform: FloatArray): FloatArray? {
        val sess = session ?: return null
        if (waveform.isEmpty()) return null

        return try {
            val normalized = normalizeWaveform(waveform)
            val inputName = sess.inputNames.iterator().nextOrNull() ?: "input_values"
            val inputTensor = OnnxTensor.createTensor(env, FloatBuffer.wrap(normalized), longArrayOf(1, normalized.size.toLong()))
            val inputs = Collections.singletonMap(inputName, inputTensor)
            val result = sess.run(inputs)
            inputTensor.close()

            val outputName = if (sess.outputNames.contains("last_hidden_state")) "last_hidden_state"
                else sess.outputNames.iterator().nextOrNull() ?: run {
                result.close()
                return null
            }
            val outputTensor = result.get(outputName)?.get() as? OnnxTensor ?: run {
                result.close()
                return null
            }
            val outputType = outputTensor.info.type.toString().uppercase(Locale.US)
            if (outputType.contains("INT") || outputType.contains("UINT")) {
                outputTensor.close()
                result.close()
                throw IllegalStateException(
                    "Unsupported Wav2Vec2 output type: $outputType. Integer/quantized outputs require explicit dequantization parameters."
                )
            }

            val shape = outputTensor.info.shape
            val batch = shape[0].toInt()
            val seqLen: Int
            val hiddenSize: Int
            when (shape.size) {
                3 -> { seqLen = shape[1].toInt(); hiddenSize = shape[2].toInt() }
                2 -> { seqLen = 1; hiddenSize = shape[1].toInt() }
                else -> {
                    outputTensor.close()
                    result.close()
                    throw IllegalStateException("Wav2Vec2 output shape must be [batch,seq,hidden] or [batch,hidden], got ${shape.size} dims")
                }
            }
            val buffer = extractFloatBuffer(outputTensor, batch * seqLen * hiddenSize)
                ?: run {
                outputTensor.close()
                result.close()
                return null
            }
            outputTensor.close()
            result.close()

            if (hiddenSize != EMBEDDING_DIM) {
                throw IllegalStateException("Wav2Vec2 hidden size $hiddenSize != expected $EMBEDDING_DIM")
            }
            val pooled = FloatArray(hiddenSize)
            for (h in 0 until hiddenSize) {
                var sum = 0.0
                for (t in 0 until seqLen) {
                    sum += buffer[t * hiddenSize + h]
                }
                pooled[h] = (sum / seqLen).toFloat()
            }
            pooled
        } catch (e: Exception) {
            e.printStackTrace()
            throw e
        }
    }

    private fun <T> Iterator<T>.nextOrNull(): T? = if (hasNext()) next() else null

    private fun extractFloatBuffer(tensor: OnnxTensor, size: Int): FloatArray? {
        return try {
            tensor.getFloatBuffer()?.let { fb ->
                val buffer = FloatArray(size)
                fb.get(buffer)
                return buffer
            }
            tensor.getDoubleBuffer()?.let { db ->
                return FloatArray(size) { db.get().toFloat() }
            }
            tensor.getByteBuffer()?.let {
                throw IllegalStateException(
                    "Wav2Vec2 returned byte tensor. Quantized outputs require dequantization before feature use."
                )
            }
            tensor.getShortBuffer()?.let {
                throw IllegalStateException(
                    "Wav2Vec2 returned short tensor. Quantized outputs require dequantization before feature use."
                )
            }
            tensor.getIntBuffer()?.let {
                throw IllegalStateException(
                    "Wav2Vec2 returned int tensor. Quantized outputs require dequantization before feature use."
                )
            }
            tensor.getLongBuffer()?.let {
                throw IllegalStateException(
                    "Wav2Vec2 returned long tensor. Quantized outputs require dequantization before feature use."
                )
            }
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun normalizeWaveform(waveform: FloatArray): FloatArray {
        var mean = 0.0
        for (v in waveform) mean += v
        mean /= waveform.size
        var variance = 0.0
        for (v in waveform) {
            val d = v - mean
            variance += d * d
        }
        variance = sqrt(variance / waveform.size).coerceAtLeast(1e-8)
        return FloatArray(waveform.size) { ((waveform[it] - mean) / variance).toFloat() }
    }

    fun close() {
        session?.close()
        session = null
    }
}
