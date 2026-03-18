# Voice Sentinel Mobile — Testing Guide

## Prerequisites

- Flutter SDK (3.0+)
- Android device or emulator (API 23+)
- Backend API at `http://45.55.247.199/api` (for online analysis and model download)

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Wav2Vec2 model (offline analysis)

**Option A: Download from API (recommended)**

- Ensure device has internet on first use
- Open app → Record tab (model prefetches in background)
- Or: Settings → Offline Models → Download Wav2Vec2 model (~300MB)

**Option B: Export locally**

```bash
pip install transformers torch huggingface_hub
python scripts/export_wav2vec2_onnx.py --output ./onnx_export
cp onnx_export/wav2vec2_encoder.onnx android/app/src/main/assets/models/onnx_models/
```

### 3. Run the app

```bash
flutter run
```

## Test Scenarios

### Manual recording

1. Open app → Get Started (or skip welcome)
2. Put a call on speaker (or play audio near the mic)
3. Tap **Start Recording**
4. Tap **Stop & Analyze**
5. Verify analysis result (Real / Suspicious / Synthetic)

### Call detection (Android only)

1. Grant **Phone** and **Notifications** permissions when prompted
2. Receive an incoming call (or make an outbound call)
3. Notification appears: "Tap to record this call for analysis"
4. Tap notification → app opens → "Record Call" dialog
5. Tap **Start Recording** → recording begins

### Online vs offline

- **Online:** Recording is sent to API; analysis runs on backend
- **Offline:** Recording is analyzed on-device (requires Wav2Vec2 model)

Toggle airplane mode to test both paths.

### History

1. Record and analyze
2. Open **History** tab
3. Tap a recording to view full analysis
4. Long-press to delete

## Permissions

| Permission | Purpose |
|------------|---------|
| Microphone | Recording audio |
| Phone state | Call detection |
| Notifications | "Record call" notification |
| Internet | API calls, model download |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Wav2Vec2 model not found" | Download from Settings or export locally |
| No call notification | Grant Phone + Notifications permissions |
| Analysis fails offline | Ensure Wav2Vec2 model is downloaded |
| API errors | Check backend at `http://45.55.247.199/api` is reachable |
