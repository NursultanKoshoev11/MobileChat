# Mobile APK QA with Firebase Test Lab

This folder documents the APK testing flow for MobileChat.

## What was added

- `.github/workflows/mobile-firebase-qa.yml` — manual GitHub Actions workflow that builds the debug APK, runs static checks, runs Firebase Robo, and runs Flutter `integration_test` on Firebase Test Lab.
- `scripts/run_firebase_robo.sh` — local/CI wrapper for Firebase Robo crawl.
- `scripts/run_firebase_integration_testlab.sh` — local/CI wrapper for Flutter integration tests on Firebase Test Lab.
- Existing test used by the workflow: `integration_test/app_flow_test.dart`.

## Why both Robo and integration_test are used

Robo is useful for crash discovery and automatic screen exploration. It is not enough for full business validation because Flutter screens often do not expose every control as stable native Android resource IDs.

The deterministic flow is handled by `integration_test/app_flow_test.dart`, which logs in with test auth values and performs a safe UI crawl through major screens.

## Required GitHub secrets

Set these in GitHub repository settings before running the workflow:

```text
GCP_SA_KEY
FIREBASE_RESULTS_BUCKET        optional
TEST_AUTH_PHONE                optional, defaults to +996700000001
TEST_AUTH_CODE                 optional, defaults to 111111
TEST_AUTH_DISPLAY_NAME         optional, defaults to Firebase Test User
```

`GCP_SA_KEY` must be a Google Cloud service account JSON with permission to run Firebase Test Lab in project `koom-9f163`.

## Manual workflow run

Open GitHub Actions, choose **Mobile Firebase Test Lab QA**, and run it with:

```text
api_base_url = https://koom.servemp3.com
run_robo = true
run_integration = true
```

## Local run after building APK

```bash
flutter pub get
flutter build apk --debug -t lib/main.dart --dart-define=API_BASE_URL=https://koom.servemp3.com
bash scripts/run_firebase_robo.sh build/app/outputs/flutter-apk/app-debug.apk

cd android
./gradlew app:assembleAndroidTest -Ptarget=../integration_test/app_flow_test.dart
cd ..
bash scripts/run_firebase_integration_testlab.sh
```

## What counts as passed

A run is acceptable only when:

- `flutter analyze` passes;
- `flutter test` passes;
- debug APK builds successfully;
- Firebase Robo completes without crash/fatal failure;
- Firebase instrumentation test completes without Flutter test failure;
- Test Lab artifacts contain screenshots, video, and logs for review.
