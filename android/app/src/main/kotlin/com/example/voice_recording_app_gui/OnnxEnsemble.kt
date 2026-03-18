package com.example.voice_recording_app_gui

/**
 * Stacked ensemble pipeline: Serial (scaler) → Parallel (5 base models) → Serial (meta_learner).
 * Feature order: centroid_mean, log_energy, mfcc_1..13, mfcc_std_1..13, mel_1..40, ssl_0..1023 = 1092.
 * Deployed scaler/base models in this app are trained for 1092 inputs.
 */
object OnnxEnsemble {
    const val FEATURE_DIM = 1092

    val SCALER = "models/onnx_models/scaler.onnx"
    val CNN = "models/onnx_models/cnn_model.onnx"
    val CNNLSTM = "models/onnx_models/cnnlstm_model.onnx"
    val TCN = "models/onnx_models/tcn_model.onnx"
    val TSSD = "models/onnx_models/tssd_model.onnx"
    val RF = "models/onnx_models/rf_model.onnx"
    val META_LEARNER = "models/onnx_models/meta_learner.onnx"

    /** Order of base model outputs for meta_learner input: [RF, CNN, LSTM, TCN, TSSD]. */
    val BASE_MODELS_FOR_META = listOf(RF, CNN, CNNLSTM, TCN, TSSD)

    /** All 7 models to load for the pipeline. */
    fun allModels(): List<String> = listOf(SCALER) + BASE_MODELS_FOR_META + META_LEARNER

    /**
     * Thresholds (hardened system):
     * > 0.85: Synthetic (Definitive AI)
     * 0.45–0.85: Synthetic (Probable AI)
     * 0.15–0.45: Suspicious (Inconclusive)
     * < 0.15: Real (Authentic Human)
     */
    fun verdict(probability: Double): String = when {
        probability > 0.85 -> "synthetic_definitive"
        probability >= 0.45 -> "synthetic_probable"
        probability >= 0.15 -> "suspicious"
        else -> "real"
    }
}
