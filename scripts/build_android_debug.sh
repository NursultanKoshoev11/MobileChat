#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${1:-http://10.0.2.2:8080}"
ANDROID_CONFIG_FILES=(
  "android/settings.gradle"
  "android/build.gradle"
  "android/app/build.gradle"
  "android/app/src/main/AndroidManifest.xml"
  "android/app/src/debug/AndroidManifest.xml"
  "android/app/src/main/kotlin/com/nursultankoshoev/mobilechat/MainActivity.kt"
  "android/app/src/main/res/values/styles.xml"
  "android/app/src/main/res/values/colors.xml"
  "android/app/src/main/res/drawable/launch_background.xml"
  "android/app/src/main/res/drawable/ic_launcher_foreground.xml"
  "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
)

echo "Flutter version:"
flutter --version

if [[ ! -f "android/gradlew" ]]; then
  echo "Android Gradle wrapper is missing. Generating Android platform files..."
  BACKUP_ROOT="$(mktemp -d)"
  for file in "${ANDROID_CONFIG_FILES[@]}"; do
    if [[ -f "$file" ]]; then
      mkdir -p "$BACKUP_ROOT/$(dirname "$file")"
      cp "$file" "$BACKUP_ROOT/$file"
    fi
  done
  flutter create --platforms=android --project-name mobile_chat .
  for file in "${ANDROID_CONFIG_FILES[@]}"; do
    if [[ -f "$BACKUP_ROOT/$file" ]]; then
      mkdir -p "$(dirname "$file")"
      cp "$BACKUP_ROOT/$file" "$file"
    fi
  done
  rm -rf "$BACKUP_ROOT"
fi

echo "Installing packages..."
flutter pub get

echo "Analyzing project..."
flutter analyze

echo "Running tests..."
flutter test

echo "Building Android debug APK..."
flutter build apk --debug -t lib/main_clean.dart --dart-define="API_BASE_URL=${API_BASE_URL}"

echo "APK created: build/app/outputs/flutter-apk/app-debug.apk"
