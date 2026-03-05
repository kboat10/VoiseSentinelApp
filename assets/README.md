# Assets

## Logo and branding

Store brand assets here so the app can load them at runtime.

- **`images/voice_sentinel_logo.png`** – Full logo (icon + “Voice Sentinel” text). Used on the Welcome screen.
- **`images/voice_sentinel_icon.png`** – Icon only. Used in the app bar and small UI spots.

Both are registered in `pubspec.yaml` under `flutter.assets`. To add more images, put them in `images/` and reference them as `assets/images/your_file.png`.

## App icon / splash

For the launcher icon and splash screen, use Flutter’s standard places:

- **App icon:** Replace `android/app/src/main/res/mipmap-*/ic_launcher.png` (and adaptive icons) or use a package like `flutter_launcher_icons`.
- **Splash:** Use `flutter_native_splash` or replace the default splash drawable in `android`/`ios`.
