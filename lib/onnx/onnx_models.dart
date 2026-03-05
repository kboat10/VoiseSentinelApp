/// Asset paths for ONNX models in android/app/src/main/assets/models/onnx_models/
///
/// Pipeline: scaler → base models → meta_learner.
/// Meta-learner input order: [RF, CNN, LSTM, TCN, TSSD].
const String kOnnxScaler = 'models/onnx_models/scaler.onnx';
const String kOnnxCnn = 'models/onnx_models/cnn_model.onnx';
const String kOnnxCnnLstm = 'models/onnx_models/cnnlstm_model.onnx';
const String kOnnxTcn = 'models/onnx_models/tcn_model.onnx';
const String kOnnxTssd = 'models/onnx_models/tssd_model.onnx';
const String kOnnxRf = 'models/onnx_models/rf_model.onnx';
const String kOnnxMetaLearner = 'models/onnx_models/meta_learner.onnx';

/// Feature vector length (centroid_mean, log_energy, mfcc 1-13, mfcc_std 1-13, mel 1-40, ssl 0-1023).
const int kEnsembleFeatureDim = 1094;

/// Base models in the order required for meta_learner input: [RF, CNN, LSTM, TCN, TSSD].
const List<String> kOnnxBaseModelsForMeta = [
  kOnnxRf,
  kOnnxCnn,
  kOnnxCnnLstm,
  kOnnxTcn,
  kOnnxTssd,
];

/// All models in pipeline order (scaler, then base models in meta order, then meta_learner).
const List<String> kOnnxPipeline = [
  kOnnxScaler,
  ...kOnnxBaseModelsForMeta,
  kOnnxMetaLearner,
];
