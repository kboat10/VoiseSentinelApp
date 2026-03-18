param(
    [string]$ApplicationId = "",
    [int]$WaitTimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"

function Get-ApplicationIdFromGradle {
    $gradlePath = Join-Path $PSScriptRoot "..\android\app\build.gradle.kts"
    if (-not (Test-Path $gradlePath)) {
        return $null
    }

    $match = Select-String -Path $gradlePath -Pattern 'applicationId\s*=\s*"([^"]+)"' | Select-Object -First 1
    if (-not $match) {
        return $null
    }

    return $match.Matches[0].Groups[1].Value
}

if (-not $ApplicationId) {
    $ApplicationId = Get-ApplicationIdFromGradle
}

if (-not $ApplicationId) {
    Write-Error "Could not determine applicationId. Pass -ApplicationId explicitly."
}

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Error "adb is not available in PATH. Install Android platform-tools and ensure adb is reachable."
}

Write-Host "Filtering Android logs for app: $ApplicationId"
Write-Host "Waiting for app process to start..."

$deadline = (Get-Date).AddSeconds($WaitTimeoutSeconds)
$appPid = $null

while (-not $appPid -and (Get-Date) -lt $deadline) {
    try {
        $candidate = (adb shell pidof -s $ApplicationId 2>$null).Trim()
        if ($candidate) {
            $appPid = $candidate
            break
        }
    }
    catch {
        # Device might not be ready yet.
    }

    Start-Sleep -Seconds 1
}

if (-not $appPid) {
    Write-Error "Timed out waiting for process $ApplicationId. Start the app and retry."
}

Write-Host "Attached to PID: $appPid"
Write-Host "Press Ctrl+C to stop."

adb logcat --pid $appPid -v time
