# ONNX models

Models live in **onnx_models/** and are loaded via ONNX Runtime (method channel from Flutter).

## Files in this pipeline

| File | Role |
|------|------|
| `scaler.onnx` | Preprocessing: scale input features before base models |
| `cnn_model.onnx` | Base model (CNN) |
| `cnnlstm_model.onnx` | Base model (CNN-LSTM) |
| `tcn_model.onnx` | Base model (Temporal CNN) |
| `tssd_model.onnx` | Base model |
| `rf_model.onnx` | Base model (Random Forest) |
| `meta_learner.onnx` | Ensemble: combines base model outputs → final prediction |

**Typical flow:** audio → features → **scaler** → base models (cnn, cnnlstm, tcn, tssd, rf) → **meta_learner** → label/score.

## Wav2Vec2 encoder (optional)

To get SSL features (ssl_0..ssl_1023) for the 1094-dim vector, use the Wav2Vec2 encoder in ONNX form. From the repo root run:

```bash
pip install transformers torch huggingface_hub
python scripts/export_wav2vec2_onnx.py --output ./onnx_export
cp onnx_export/wav2vec2_encoder.onnx android/app/src/main/assets/models/onnx_models/
```

Model ID: **facebook/wav2vec2-xls-r-300m**. See `scripts/README.md` for details.

## Asset paths in code

Use these paths when calling `loadModel` / `runInference`:

- `models/onnx_models/scaler.onnx`
- `models/onnx_models/cnn_model.onnx`
- `models/onnx_models/cnnlstm_model.onnx`
- `models/onnx_models/tcn_model.onnx`
- `models/onnx_models/tssd_model.onnx`
- `models/onnx_models/rf_model.onnx`
- `models/onnx_models/meta_learner.onnx`
