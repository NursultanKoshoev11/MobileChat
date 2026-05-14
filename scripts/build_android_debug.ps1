param(
    [string]$ApiBaseUrl = "http://10.0.2.2:8080"
)

$ErrorActionPreference = "Stop"

function Backup-FileIfExists($Path, $BackupRoot) {
    if (Test-Path $Path) {
        $Target = Join-Path $BackupRoot $Path
        New-Item -ItemType Directory -Force -Path (Split-Path $Target) | Out-Null
        Copy-Item $Path $Target -Force
    }
}

function Restore-FileIfExists($Path, $BackupRoot) {
    $Source = Join-Path $BackupRoot $Path
    if (Test-Path $Source) {
        New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
        Copy-Item $Source $Path -Force
    }
}

$AndroidConfigFiles = @(
    "android\settings.gradle",
    "android\build.gradle",
    "android\app\build.gradle",
    "android\app\src\main\AndroidManifest.xml",
    "android\app\src\debug\AndroidManifest.xml",
    "android\app\src\main\kotlin\com\nursultankoshoev\mobilechat\MainActivity.kt",
    "android\app\src\main\res\values\styles.xml",
    "android\app\src\main\res\values\colors.xml",
    "android\app\src\main\res\drawable\launch_background.xml",
    "android\app\src\main\res\drawable\ic_launcher_foreground.xml",
    "android\app\src\main\res\mipmap-anydpi-v26\ic_launcher.xml"
)

Write-Host "Flutter version:" -ForegroundColor Cyan
flutter --version

if (!(Test-Path "android\gradlew.bat")) {
    Write-Host "Android Gradle wrapper is missing. Generating Android platform files..." -ForegroundColor Yellow
    $BackupRoot = Join-Path $env:TEMP ("mobilechat-android-backup-" + [guid]::NewGuid().ToString())
    foreach ($File in $AndroidConfigFiles) { Backup-FileIfExists $File $BackupRoot }
    flutter create --platforms=android --project-name mobile_chat .
    foreach ($File in $AndroidConfigFiles) { Restore-FileIfExists $File $BackupRoot }
    Remove-Item $BackupRoot -Recurse -Force -ErrorAction SilentlyContinue
}

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
