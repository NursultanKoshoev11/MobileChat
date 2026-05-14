# Android build guide

This project is prepared for Android debug APK builds from Flutter.

## Requirements

Install these tools locally:

1. Flutter SDK
2. Android Studio or Android SDK command-line tools
3. JDK 17
4. Android SDK Platform 35

Check your environment:

```bash
flutter doctor
```

## Build debug APK on Windows

From the repository root:

```powershell
.\scripts\build_android_debug.ps1 -ApiBaseUrl "http://10.0.2.2:8080"
```

The APK will be created here:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Build debug APK on macOS/Linux

From the repository root:

```bash
chmod +x scripts/build_android_debug.sh
./scripts/build_android_debug.sh "http://10.0.2.2:8080"
```

The APK will be created here:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Backend URL examples

For Android emulator:

```text
http://10.0.2.2:8080
```

For a real Android phone on the same Wi-Fi network, use your computer local IP:

```text
http://192.168.1.10:8080
```

For production, use HTTPS:

```text
https://api.example.com
```

## Firebase push notifications

The app can build without Firebase config, but push notifications require this file:

```text
android/app/google-services.json
```

Do not commit `google-services.json` to the repository. It is ignored by `.gitignore`.

If `google-services.json` exists, the Android Gradle build applies the Google Services plugin automatically. If it does not exist, the APK still builds, but Firebase push notifications are disabled at runtime.

## GitHub Actions build

The workflow is here:

```text
.github/workflows/android.yml
```

Open GitHub Actions and run:

```text
Android APK -> Run workflow
```

After it finishes, download the artifact:

```text
mobilechat-debug-apk
```

## Release signing

For release builds, copy:

```text
android/key.properties.example
```

to:

```text
android/key.properties
```

Then fill your keystore values. Do not commit `android/key.properties` or `.jks` files.
