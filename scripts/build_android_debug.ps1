param(
    [string]$ApiBaseUrl = "http://10.0.2.2:8080"
)

$ErrorActionPreference = "Stop"

Write-Host "Flutter version:" -ForegroundColor Cyan
flutter --version

Write-Host "Installing packages..." -ForegroundColor Cyan
flutter pub get

Write-Host "Analyzing project..." -ForegroundColor Cyan
flutter analyze

Write-Host "Running tests..." -ForegroundColor Cyan
flutter test

Write-Host "Building Android debug APK..." -ForegroundColor Cyan
flutter build apk --debug -t lib/main_clean.dart --dart-define=API_BASE_URL=$ApiBaseUrl

Write-Host "APK created:" -ForegroundColor Green
Write-Host "build/app/outputs/flutter-apk/app-debug.apk"
