param(
    [string]$ApkPath = "build/app/outputs/flutter-apk/app-debug.apk",
    [string]$ApiBaseUrl = "https://koom.servemp3.com",
    [string]$Project = "koom-9f163",
    [string]$Device = "model=Pixel2.arm,version=30,locale=ru,orientation=portrait",
    [string]$Timeout = "10m",
    [string]$ResultsDir = "",
    [string]$ResultsBucket = "",
    [string]$RoboDirectives = "",
    [switch]$Build
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is not installed or not available in PATH."
    }
}

Require-Command "gcloud"

$fallbackFlutterBin = "F:\dev\flutter\bin"
if (-not (Get-Command "flutter" -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $fallbackFlutterBin "flutter.bat"))) {
    $env:PATH = "$fallbackFlutterBin;$env:PATH"
}

if ([string]::IsNullOrWhiteSpace($ResultsDir)) {
    $ResultsDir = "mobilechat-robo-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}

if ($Build) {
    Require-Command "flutter"
    Write-Host "Installing Flutter packages..." -ForegroundColor Cyan
    flutter pub get

    Write-Host "Building debug APK for Firebase Test Lab..." -ForegroundColor Cyan
    flutter build apk --debug -t lib/main.dart --dart-define="API_BASE_URL=$ApiBaseUrl"
}

if (-not (Test-Path $ApkPath)) {
    throw "APK not found: $ApkPath. Build it first or run this script with -Build."
}

$argsList = @(
    "--project", $Project,
    "firebase", "test", "android", "run",
    "--type", "robo",
    "--app", $ApkPath,
    "--device", $Device,
    "--timeout", $Timeout,
    "--results-dir", $ResultsDir,
    "--record-video"
)

if (-not [string]::IsNullOrWhiteSpace($ResultsBucket)) {
    $argsList += @("--results-bucket", $ResultsBucket)
}

if (-not [string]::IsNullOrWhiteSpace($RoboDirectives)) {
    $argsList += @("--robo-directives", $RoboDirectives)
}

Write-Host "Running Firebase Test Lab Robo test..." -ForegroundColor Cyan
Write-Host "gcloud $($argsList -join ' ')"
& gcloud @argsList
