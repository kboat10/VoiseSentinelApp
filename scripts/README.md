# Scripts

## Wav2Vec2 (facebook/wav2vec2-xls-r-300m)

The app’s 1094-dim feature vector includes **ssl_0..ssl_1023** from a Wav2Vec2-style encoder. To get the model and use it on device:

### 1. Export the encoder to ONNX (one-time)

From the project root:

```bash
pip install transformers torch huggingface_hub
python scripts/export_wav2vec2_onnx.py --output ./onnx_export
```

This will:

- Download **facebook/wav2vec2-xls-r-300m** from Hugging Face
- Export the encoder to `onnx_export/wav2vec2_encoder.onnx`
- Save the processor config to `onnx_export/` (for 16 kHz preprocessing)

### 2. Add the ONNX to the app

Copy the encoder ONNX into Android assets:

```bash
cp onnx_export/wav2vec2_encoder.onnx android/app/src/main/assets/models/onnx_models/
```

Then load and run it via the existing ONNX Runtime method channel (input: raw 16 kHz audio; output: last_hidden_state for SSL features).

### 3. Optional: download config from the app

To fetch only config/preprocessor files (e.g. for preprocessing settings) at runtime:

```dart
import 'package:voice_recording_app_gui/onnx/huggingface_download.dart';

final files = await HuggingFaceDownload.downloadWav2Vec2Config(
  repoId: 'facebook/wav2vec2-xls-r-300m',
);
// files['config.json'], files['preprocessor_config.json']
```

The full PyTorch model (~1.2 GB) is not runnable on Android directly; use the exported ONNX from step 1.
