#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${1:-http://10.0.2.2:8080}"

echo "Flutter version:"
flutter --version

echo "Installing packages..."
flutter pub get

echo "Analyzing project..."
flutter analyze

echo "Running tests..."
flutter test

echo "Building Android debug APK..."
flutter build apk --debug -t lib/main_clean.dart --dart-define="API_BASE_URL=${API_BASE_URL}"

echo "APK created: build/app/outputs/flutter-apk/app-debug.apk"
