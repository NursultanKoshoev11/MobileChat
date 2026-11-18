# Android build guide

This project is prepared for Android debug APK builds from Flutter.

## Requirements

Install these tools locally:

1. Flutter SDK
2. Android Studio or Android SDK command-line tools
3. JDK 17
4. Android SDK Platform 36 (`compileSdk 36`, `targetSdk 36` in `android/app/build.gradle`)

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

Release and profile builds refuse to start with a non-HTTPS `API_BASE_URL`; plain HTTP is
only allowed in debug builds (the debug manifest also enables cleartext traffic).

## Firebase push notifications

Push notifications use this Firebase config file:

```text
android/app/google-services.json
```

The file **is tracked in the repository** (it was force-added even though `.gitignore` lists it),
so CI and local builds use it by default. It contains only client identifiers, not server
secrets, but the Firebase/Google API key inside it must be restricted in Google Cloud Console
(Android apps: package `com.nursultankoshoev.mobilechat` + release/upload SHA-1 fingerprints)
and Firebase App Check should be enabled. See `STORE_RELEASE_SETUP.md`.

If `google-services.json` exists, the Android Gradle build applies the Google Services plugin
automatically. Debug builds still work without it (push disabled at runtime); profile and
release builds fail without it unless it is provided via the `GOOGLE_SERVICES_JSON_B64`
GitHub Actions secret.

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
koom-debug-apk
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
