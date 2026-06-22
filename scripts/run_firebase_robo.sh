#!/usr/bin/env bash
set -euo pipefail

APK_PATH="${1:-build/app/outputs/flutter-apk/app-debug.apk}"
GCP_PROJECT="${GCP_PROJECT:-koom-9f163}"
DEVICE="${FIREBASE_TEST_DEVICE:-model=Pixel2,version=30,locale=ru,orientation=portrait}"
TIMEOUT="${FIREBASE_ROBO_TIMEOUT:-10m}"
RESULTS_DIR="${FIREBASE_RESULTS_DIR:-mobilechat-robo-$(date +%Y%m%d-%H%M%S)}"

if [ ! -f "$APK_PATH" ]; then
  echo "APK not found: $APK_PATH"
  exit 1
fi

gcloud config set project "$GCP_PROJECT" >/dev/null

CMD=(
  gcloud firebase test android run
  --type robo
  --app "$APK_PATH"
  --device "$DEVICE"
  --timeout "$TIMEOUT"
  --results-dir "$RESULTS_DIR"
  --record-video
)

if [ -n "${FIREBASE_RESULTS_BUCKET:-}" ]; then
  CMD+=(--results-bucket "$FIREBASE_RESULTS_BUCKET")
fi

# Optional raw gcloud robo directives, for example:
# FIREBASE_ROBO_DIRECTIVES='text:phone=+996700000001,text:code=111111'
if [ -n "${FIREBASE_ROBO_DIRECTIVES:-}" ]; then
  CMD+=(--robo-directives "$FIREBASE_ROBO_DIRECTIVES")
fi

echo "Running Firebase Test Lab Robo test:"
printf ' %q' "${CMD[@]}"
echo
"${CMD[@]}"
