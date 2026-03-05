/// Feature vector order for the 1094-dim ensemble input.
///
/// The scaler and base models expect features in this exact order.
/// Feature extraction (e.g. Wav2Vec2 + Librosa) must produce a vector
/// assembled as below before calling [OnnxInferenceService.runEnsemble].
///
/// Total: 2 + 13 + 13 + 40 + 1024 = 1094.
abstract class EnsembleFeatureOrder {
  /// Length of the feature vector.
  static const int length = 1094;

  /// 1. centroid_mean, log_energy (2)
  static const int centroidMean = 0;
  static const int logEnergy = 1;

  /// 2. mfcc_1 to mfcc_13 (13)
  static const int mfccStart = 2;
  static const int mfccCount = 13;

  /// 3. mfcc_std_1 to mfcc_std_13 (13)
  static const int mfccStdStart = 15;
  static const int mfccStdCount = 13;

  /// 4. mel_1 to mel_40 (40)
  static const int melStart = 28;
  static const int melCount = 40;

  /// 5. ssl_0 to ssl_1023 (1024)
  static const int sslStart = 68;
  static const int sslCount = 1024;
}
