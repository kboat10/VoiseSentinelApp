# ONNX Stacked Ensemble — Backend Implementation Spec

This document describes the **Serial-Parallel-Serial** execution flow for building a backend using the ONNX models from the Voice Sentinel system. The system is a "Stacked Ensemble" where base models' outputs become inputs for the final meta-learner.

---

## 1. High-Level Execution Flow

1. **Feature Extraction (Raw to Tensor):** Process raw audio into a **1,092-dimensional vector**.
2. **Normalization (The Scaler):** Pass raw features through `scaler.onnx` to standardize the distribution.
3. **Base Inference (Parallel):** Feed the scaled vector into the **5 Base Models** simultaneously.
4. **Meta-Inference (Orchestrator):** Stack the 5 resulting probabilities into a new vector and pass it through `meta_learner.onnx`.
5. **Forensic Thresholding:** Map the final probability to the confidence scale.

---

## 2. Input/Output Specifications

### A. The Scaler (`scaler.onnx`)

Standardizes the raw data so the models see the same "scale" used during training.

| Property | Value |
|----------|-------|
| **Input Shape** | `[1, 1092]` (Float32) |
| **Output Shape** | `[1, 1092]` (Float32) |

### B. Base Models (The 5 Workers)

These models look for different artifacts (Spatial, Temporal, and Statistical).

| Model | Input Shape | Output |
|-------|-------------|--------|
| `rf_model.onnx` | `[1, 1092]` | Single float $P$ ∈ [0, 1] |
| `cnn_model.onnx` | `[1, 1092, 1]` | Single float $P$ ∈ [0, 1] |
| `cnnlstm_model.onnx` | `[1, 1092, 1]` | Single float $P$ ∈ [0, 1] |
| `tcn_model.onnx` | `[1, 1092, 1]` | Single float $P$ ∈ [0, 1] |
| `tssd_model.onnx` | `[1, 1092, 1]` | Single float $P$ ∈ [0, 1] |

**Note:** CNN, CNN-LSTM, TCN, and TSSD require an added "channel" dimension. Reshape the scaled `[1, 1092]` vector to `[1, 1092, 1]` before inference.

### C. The Meta-Learner (`meta_learner.onnx`)

Acts as the "Judge" who knows which base models to trust in specific scenarios.

| Property | Value |
|----------|-------|
| **Input Shape** | `[1, 5]` (Float32) — Order: [RF, CNN, CNN-LSTM, TCN, TSSD] |
| **Output** | Final forensic score $P_{final}$ |

**Handling the Meta-Learner Output:** The Meta-Learner was converted from Scikit-Learn (Gradient Boosting). The ONNX output typically returns:
1. The classification label (0 or 1).
2. A list of probabilities for both classes.

**Logic:** Extract `output[1][0][1]` to get the Synthetic probability.

---

## 3. Feature Order (Critical)

The 1,092-element vector must be assembled in this exact order:

| Index | Feature | Count |
|-------|---------|-------|
| 0–1 | `centroid_mean`, `log_energy` | 2 |
| 2–14 | `mfcc_1` to `mfcc_13` | 13 |
| 15–27 | `mfcc_std_1` to `mfcc_std_13` | 13 |
| 28–67 | `mel_1` to `mel_40` | 40 |
| 68–1091 | `ssl_0` to `ssl_1023` | 1024 |

**Total:** 2 + 13 + 13 + 40 + 1024 = **1092**

---

## 4. Logic Summary Table

| Stage | Component | Input Dim | Output Dim | Why? |
|-------|-----------|-----------|------------|------|
| 1 | Wav2Vec2 + Librosa | Audio File | 1092 | Converts sound to math. |
| 2 | `scaler.onnx` | [1, 1092] | [1, 1092] | Standardizes values. |
| 3 | Base Ensemble | [1, 1092, 1] | 1 (each) | Captures diverse artifacts. |
| 4 | `meta_learner.onnx` | [1, 5] | 1 | Corrects base model biases. |
| 5 | Thresholding | float | string | Provides forensic verdict. |

---

## 5. Final Threshold Scale (Hardened System)

| Probability | Verdict |
|-------------|---------|
| > 0.85 | Synthetic (Definitive AI) |
| 0.45 – 0.85 | Synthetic (Probable AI) |
| 0.15 – 0.45 | Suspicious (Inconclusive) |
| < 0.15 | Real (Authentic Human) |

---

## 6. Feature Extraction Details

### DSP Features (68 dims)

- **Spectral centroid:** Mean across frames of `sum(freq * magnitude) / sum(magnitude)`.
- **Log energy:** `log(sum(waveform²))`.
- **MFCC:** 13 coefficients per frame → mean (13) + std (13) across frames.
- **Mel spectrogram:** 40 mel bands → mean across time.

**Suggested params:** frame=1024, hop=512, n_mels=40, n_mfcc=13.

### SSL Features (1024 dims)

- **Wav2Vec2:** Use `facebook/wav2vec2-xls-r-300m` encoder.
- Extract `last_hidden_state` and **mean-pool across the time dimension**.
- Result: 1024-dim vector.

---

## 7. Model Files

Located in `android/app/src/main/assets/models/onnx_models/`:

- `scaler.onnx`
- `rf_model.onnx`
- `cnn_model.onnx`
- `cnnlstm_model.onnx`
- `tcn_model.onnx`
- `tssd_model.onnx`
- `meta_learner.onnx`
