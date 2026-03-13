param(
    [int]$Port = 8787,
    [string]$ConfigPath = "C:\Users\ngath\.codex\config.toml",
    [string]$ProxyBaseUrl = "http://127.0.0.1:8787",
    [string]$DirectBaseUrl = "https://llmgate.app/v1",
    [int]$PollSeconds = 3,
    [bool]$SwitchBackWhenProxyUp = $true,
    [switch]$RunOnce
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($PollSeconds -lt 1) {
    $PollSeconds = 1
}

$statusScript = Join-Path $PSScriptRoot "context_guard_proxy_status.ps1"
if (-not (Test-Path -LiteralPath $statusScript)) {
    throw "Missing status script: $statusScript"
}

$artifactsDir = Join-Path $PSScriptRoot "artifacts"
if (-not (Test-Path -LiteralPath $artifactsDir)) {
    New-Item -ItemType Directory -Path $artifactsDir | Out-Null
}
$logPath = Join-Path $artifactsDir "context_guard_failover_watchdog.log"

function Write-WatchdogLog {
    param(
        [string]$Message
    )
    $line = "{0} {1}" -f ([datetimeoffset]::UtcNow.ToString("o")), $Message
    try {
        Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    } catch {
        # Ignore log write failures.
    }
}

Write-WatchdogLog "watchdog_started port=$Port poll_seconds=$PollSeconds switchback=$SwitchBackWhenProxyUp config=$ConfigPath"

while ($true) {
    try {
        $status = & $statusScript `
            -Port $Port `
            -ConfigPath $ConfigPath `
            -AutoFailover $true `
            -SwitchBackWhenProxyUp $SwitchBackWhenProxyUp `
            -ProxyBaseUrl $ProxyBaseUrl `
            -DirectBaseUrl $DirectBaseUrl

        if ($null -ne $status) {
            Write-WatchdogLog ("status action={0} reason={1} base={2}" -f $status.FailoverAction, $status.FailoverReason, $status.ConfigBaseUrl)
        }
    } catch {
        Write-WatchdogLog ("watchdog_error detail={0}" -f $_.Exception.Message)
    }

    if ($RunOnce.IsPresent) {
        break
    }

    Start-Sleep -Seconds $PollSeconds
}

Write-WatchdogLog "watchdog_stopped run_once=$($RunOnce.IsPresent)"
