#!/usr/bin/env bash
set -euo pipefail

APP_APK="${APP_APK:-build/app/outputs/apk/debug/app-debug.apk}"
TEST_APK="${TEST_APK:-build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk}"
GCP_PROJECT="${GCP_PROJECT:-koom-9f163}"
DEVICE="${FIREBASE_TEST_DEVICE:-model=Pixel2.arm,version=30,locale=ru,orientation=portrait}"
TIMEOUT="${FIREBASE_INSTRUMENTATION_TIMEOUT:-15m}"
RESULTS_DIR="${FIREBASE_RESULTS_DIR:-mobilechat-integration-$(date +%Y%m%d-%H%M%S)}"

if [ ! -f "$APP_APK" ]; then
  echo "App APK not found: $APP_APK"
  exit 1
fi

if [ ! -f "$TEST_APK" ]; then
  echo "Android test APK not found: $TEST_APK"
  echo "Build it with: (cd android && ./gradlew app:assembleAndroidTest -Ptarget=integration_test/app_flow_test.dart)"
  exit 1
fi

gcloud config set project "$GCP_PROJECT" >/dev/null

CMD=(
  gcloud firebase test android run
  --type instrumentation
  --app "$APP_APK"
  --test "$TEST_APK"
  --device "$DEVICE"
  --timeout "$TIMEOUT"
  --results-dir "$RESULTS_DIR"
  --record-video
)

if [ -n "${FIREBASE_RESULTS_BUCKET:-}" ]; then
  CMD+=(--results-bucket "$FIREBASE_RESULTS_BUCKET")
fi

echo "Running Firebase Test Lab instrumentation test:"
printf ' %q' "${CMD[@]}"
echo
"${CMD[@]}"
