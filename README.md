# Voice Sentinel Mobile

Flutter mobile app for AI-powered deepfake voice detection. Record calls, analyze audio, and get real-time verdicts (Real / Suspicious / Synthetic).

## Features

- **Call recording** — Put call on speaker, record, and analyze
- **Call detection** — Incoming call triggers "Tap to record" notification (Android)
- **Dual-path analysis** — Online (API) or offline (on-device ONNX)
- **Mobile bundle API** — Download Wav2Vec2 model from backend

## Prerequisites

- Flutter SDK 3.0+
- Android device/emulator (API 23+)

## Running the app

```bash
flutter pub get
flutter run
```

## App-only mobile logs (Android)

To avoid full device log noise and show only this app's process logs:

1. Start app run: `Task: Flutter Run (Android)`
2. Start filtered logs: `Task: Android App-Only Logs`

The log task uses `scripts/mobile_app_logs.ps1` and filters `adb logcat` by the app PID.

## Testing

See [TESTING.md](TESTING.md) for setup, test scenarios, and troubleshooting.

## Architecture

- **Feature extraction:** Acoustic (68 dims) + Wav2Vec2 SSL (1024 dims) → 1092-dim vector
- **Ensemble:** Scaler → 5 base models (RF, CNN, CNN-LSTM, TCN, TSSD) → meta-learner
- **Backend:** `http://45.55.247.199/api`
- **Docs:** [docs/ONNX_BACKEND_SPEC.md](docs/ONNX_BACKEND_SPEC.md) for backend implementation details
