param(
    [string]$AppApk = "build/app/outputs/apk/debug/app-debug.apk",
    [string]$TestApk = "build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk",
    [string]$ApiBaseUrl = "https://koom.servemp3.com",
    [string]$Project = "koom-9f163",
    [string]$Device = "model=Pixel2.arm,version=30,locale=ru,orientation=portrait",
    [string]$Timeout = "15m",
    [string]$ResultsDir = "",
    [string]$ResultsBucket = "",
    [string]$TestAuthPhone = "+996555555555",
    [string]$TestActor2Phone = "+996700000001",
    [string]$TestActor3Phone = "+996700000002",
    [string]$TestActor4Phone = "+996700000003",
    [string]$TestActor5Phone = "+996700000004",
    [string]$TestAuthCode = "111111",
    [string]$TestAuthDisplayName = "Koom QA Owner",
    [string]$TestActor2DisplayName = "Koom QA Supporter",
    [string]$TestActor3DisplayName = "Koom QA Opponent",
    [string]$TestActor4DisplayName = "Koom QA Observer",
    [string]$TestActor5DisplayName = "Koom QA Reviewer",
    [string]$TestExpectedUserRole = "user",
    [string]$TestExpectedGroupRole = "owner",
    [switch]$Build
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is not installed or not available in PATH."
    }
}

function Invoke-Checked {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE."
    }
}

function Invoke-GcloudTestLab {
    param(
        [string[]]$Arguments,
        [string]$ResultsDir,
        [string]$ResultsBucket
    )
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = @(& gcloud.cmd @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    foreach ($line in $output) {
        if ($line -is [System.Management.Automation.ErrorRecord]) {
            Write-Host $line.Exception.Message
        } else {
            Write-Host $line
        }
    }
    if ($exitCode -eq 0 -or $exitCode -eq 10) {
        return
    }

    $joinedOutput = $output -join "`n"
    if ($joinedOutput -match "TEST_QUOTA_EXCEEDED|Insufficient testing quota") {
        $artifactPath = if ([string]::IsNullOrWhiteSpace($ResultsBucket)) {
            $ResultsDir
        } else {
            "gs://$ResultsBucket/$ResultsDir"
        }
        throw "Firebase Test Lab quota exceeded before device execution. No app logcat/XML/video was produced for $artifactPath. Increase Test Lab quota, wait for quota reset, or run against a billing-enabled project."
    }

    throw "gcloud Firebase Test Lab run failed with exit code $exitCode."
}

Require-Command "gcloud.cmd"

$fallbackFlutterBin = "F:\dev\flutter\bin"
if (-not (Get-Command "flutter" -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $fallbackFlutterBin "flutter.bat"))) {
    $env:PATH = "$fallbackFlutterBin;$env:PATH"
}

$androidStudioJbr = "G:\Android\jbr"
if ((Test-Path (Join-Path $androidStudioJbr "bin\java.exe")) -and
    (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME "bin\java.exe")))) {
    $env:JAVA_HOME = $androidStudioJbr
}

if ([string]::IsNullOrWhiteSpace($ResultsDir)) {
    $ResultsDir = "mobilechat-integration-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}

if ($Build) {
    Require-Command "flutter"
    Write-Host "Installing Flutter packages..." -ForegroundColor Cyan
    Invoke-Checked "flutter" @("pub", "get")

    Write-Host "Preparing Flutter Android build files..." -ForegroundColor Cyan
    Invoke-Checked "flutter" @(
        "build", "apk", "--debug",
        "-t", "lib/main.dart",
        "--dart-define=API_BASE_URL=$ApiBaseUrl",
        "--dart-define=TEST_AUTH_PHONE=$TestAuthPhone",
        "--dart-define=TEST_ACTOR2_PHONE=$TestActor2Phone",
        "--dart-define=TEST_ACTOR3_PHONE=$TestActor3Phone",
        "--dart-define=TEST_ACTOR4_PHONE=$TestActor4Phone",
        "--dart-define=TEST_ACTOR5_PHONE=$TestActor5Phone",
        "--dart-define=TEST_AUTH_CODE=$TestAuthCode",
        "--dart-define=TEST_AUTH_DISPLAY_NAME=$TestAuthDisplayName",
        "--dart-define=TEST_ACTOR2_DISPLAY_NAME=$TestActor2DisplayName",
        "--dart-define=TEST_ACTOR3_DISPLAY_NAME=$TestActor3DisplayName",
        "--dart-define=TEST_ACTOR4_DISPLAY_NAME=$TestActor4DisplayName",
        "--dart-define=TEST_ACTOR5_DISPLAY_NAME=$TestActor5DisplayName",
        "--dart-define=TEST_EXPECTED_USER_ROLE=$TestExpectedUserRole",
        "--dart-define=TEST_EXPECTED_GROUP_ROLE=$TestExpectedGroupRole"
    )

    Write-Host "Building Android instrumentation test APK..." -ForegroundColor Cyan
    Push-Location android
    try {
        Invoke-Checked ".\gradlew.bat" @("app:assembleAndroidTest", "-Ptarget=integration_test/app_flow_test.dart")

        $dartDefines = @(
            "API_BASE_URL=$ApiBaseUrl",
            "TEST_AUTH_PHONE=$TestAuthPhone",
            "TEST_ACTOR2_PHONE=$TestActor2Phone",
            "TEST_ACTOR3_PHONE=$TestActor3Phone",
            "TEST_ACTOR4_PHONE=$TestActor4Phone",
            "TEST_ACTOR5_PHONE=$TestActor5Phone",
            "TEST_AUTH_CODE=$TestAuthCode",
            "TEST_AUTH_DISPLAY_NAME=$TestAuthDisplayName",
            "TEST_ACTOR2_DISPLAY_NAME=$TestActor2DisplayName",
            "TEST_ACTOR3_DISPLAY_NAME=$TestActor3DisplayName",
            "TEST_ACTOR4_DISPLAY_NAME=$TestActor4DisplayName",
            "TEST_ACTOR5_DISPLAY_NAME=$TestActor5DisplayName",
            "TEST_EXPECTED_USER_ROLE=$TestExpectedUserRole",
            "TEST_EXPECTED_GROUP_ROLE=$TestExpectedGroupRole"
        ) | ForEach-Object {
            [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_))
        }

        Write-Host "Building debug APK with the integration test entrypoint..." -ForegroundColor Cyan
        Invoke-Checked ".\gradlew.bat" @(
            "app:assembleDebug",
            "-Ptarget=integration_test/app_flow_test.dart",
            "-Pdart-defines=$($dartDefines -join ',')"
        )
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path $AppApk)) {
    throw "App APK not found: $AppApk. Build it first or run this script with -Build."
}

if (-not (Test-Path $TestApk)) {
    throw "Android test APK not found: $TestApk. Build it first or run this script with -Build."
}

$argsList = @(
    "--project", $Project,
    "firebase", "test", "android", "run",
    "--type", "instrumentation",
    "--app", $AppApk,
    "--test", $TestApk,
    "--device", $Device,
    "--timeout", $Timeout,
    "--results-dir", $ResultsDir,
    "--record-video"
)

if (-not [string]::IsNullOrWhiteSpace($ResultsBucket)) {
    $argsList += @("--results-bucket", $ResultsBucket)
}

Write-Host "Running Firebase Test Lab Flutter integration test..." -ForegroundColor Cyan
Write-Host "gcloud $($argsList -join ' ')"
Invoke-GcloudTestLab $argsList $ResultsDir $ResultsBucket

if (-not [string]::IsNullOrWhiteSpace($ResultsBucket)) {
    Write-Host "Checking Firebase Test Lab XML results..." -ForegroundColor Cyan
    $xmlPaths = @(& gcloud.cmd storage ls -r "gs://$ResultsBucket/$ResultsDir/**/test_result_*.xml" 2>$null)
    if ($xmlPaths.Count -eq 0) {
        Write-Warning "No Test Lab XML result files found in gs://$ResultsBucket/$ResultsDir."
    } else {
        $tests = 0
        $failures = 0
        $errors = 0
        foreach ($xmlPath in $xmlPaths) {
            [xml]$xml = (& gcloud.cmd storage cat $xmlPath) -join "`n"
            $suites = @()
            if ($xml.testsuite) {
                $suites += $xml.testsuite
            }
            if ($xml.testsuites -and $xml.testsuites.testsuite) {
                $suites += $xml.testsuites.testsuite
            }
            foreach ($suite in $suites) {
                $tests += [int]$suite.tests
                $failures += [int]$suite.failures
                $errors += [int]$suite.errors
            }
        }
        Write-Host "Firebase XML summary: tests=$tests failures=$failures errors=$errors" -ForegroundColor Cyan
        if ($tests -eq 0) {
            throw "Firebase Test Lab did not execute any instrumentation tests."
        }
        if ($failures -gt 0 -or $errors -gt 0) {
            throw "Firebase Test Lab reported failed instrumentation tests."
        }
    }
}
