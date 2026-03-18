# Building on Windows

If `flutter run` or `flutter build apk` fails on Windows, try these steps:

## 1. Clean and retry
```powershell
flutter clean
flutter pub get
flutter run -d <device-id>
```

## 2. If Gradle fails with "What went wrong: 26" or similar
- **Kill stuck processes:** Close Android Studio, then run:
  ```powershell
  taskkill /F /IM java.exe /T 2>$null
  taskkill /F /IM gradle.exe /T 2>$null
  ```
- **Clear Gradle caches:** Delete `C:\Users\<You>\.gradle\caches` and `C:\Users\<You>\.gradle\wrapper\dists` (optional; Gradle will re-download)
- **Retry:** `flutter clean` then `flutter run`

## 3. Get full error details
```powershell
cd android
.\gradlew.bat assembleDebug --stacktrace
```
This shows the real error instead of the truncated "26".

## 4. Memory issues
If the build runs out of memory, edit `android/gradle.properties` and reduce:
```
org.gradle.jvmargs=-Xmx1536m ...
```

## 5. Path issues
- Avoid spaces and special characters in the project path
- Prefer `C:\Dev\VoiseSentinelApp` over `C:\Users\egale\Downloads\VoiseSentinelApp-main`
