param(
    [int]$Port = 8787,
    [string]$UpstreamBaseUrl = "https://llmgate.app/v1",
    [int]$SoftThresholdTokens = 200000,
    [int]$EscalateThresholdTokens = 240000,
    [int]$HardThresholdTokens = 250000,
    [switch]$ApplyAtSoftThreshold,
    [switch]$DisableApplyAtSoftThreshold,
    [string]$LogPath = ".\scripts\artifacts\context_guard_proxy.log",
    [int]$WatchdogPollSeconds = 3,
    [bool]$WatchdogSwitchBackWhenProxyUp = $true,
    [switch]$EnableFailoverWatchdog,
    [switch]$DisableFailoverWatchdog,
    [switch]$Background
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($SoftThresholdTokens -gt $EscalateThresholdTokens -or $EscalateThresholdTokens -gt $HardThresholdTokens) {
    throw "Invalid thresholds: require Soft <= Escalate <= Hard."
}

$scriptPath = Join-Path $PSScriptRoot "context_guard_proxy.js"
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Missing proxy script: $scriptPath"
}
$nodePath = (Get-Command node -ErrorAction Stop).Source

$resolvedLogPath = ""
if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $resolvedLogPath = if ([System.IO.Path]::IsPathRooted($LogPath)) {
        $LogPath
    } else {
        Join-Path (Get-Location).Path $LogPath
    }
    $resolvedLogPath = [System.IO.Path]::GetFullPath($resolvedLogPath)
    $logDir = Split-Path -Parent $resolvedLogPath
    if (-not [string]::IsNullOrWhiteSpace($logDir) -and -not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
}

$applyAtSoft = $true
if ($DisableApplyAtSoftThreshold.IsPresent) {
    $applyAtSoft = $false
}
if ($ApplyAtSoftThreshold.IsPresent) {
    $applyAtSoft = $true
}

$env:CONTEXT_GUARD_PROXY_PORT = [string]$Port
$env:CONTEXT_GUARD_UPSTREAM_BASE_URL = $UpstreamBaseUrl
$env:CONTEXT_GUARD_SOFT_THRESHOLD = [string]$SoftThresholdTokens
$env:CONTEXT_GUARD_ESCALATE_THRESHOLD = [string]$EscalateThresholdTokens
$env:CONTEXT_GUARD_HARD_THRESHOLD = [string]$HardThresholdTokens
$env:CONTEXT_GUARD_APPLY_AT_SOFT = $applyAtSoft ? "true" : "false"
$env:CONTEXT_GUARD_LOG_FILE = $resolvedLogPath

$watchdogEnabled = $true
if ($DisableFailoverWatchdog.IsPresent) {
    $watchdogEnabled = $false
}
if ($EnableFailoverWatchdog.IsPresent) {
    $watchdogEnabled = $true
}
if ($WatchdogPollSeconds -lt 1) {
    $WatchdogPollSeconds = 1
}

$watchdogPid = $null
$watchdogPidFile = Join-Path $PSScriptRoot "artifacts\context_guard_failover_watchdog.pid"
$watchdogScriptPath = Join-Path $PSScriptRoot "context_guard_failover_watchdog.ps1"
$proxyScriptName = [System.IO.Path]::GetFileName($scriptPath)
$watchdogScriptName = [System.IO.Path]::GetFileName($watchdogScriptPath)

function Get-ProcessCommandLine {
    param([int]$Pid)
    try {
        $procInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $Pid"
        if ($null -eq $procInfo) {
            return ""
        }
        return [string]$procInfo.CommandLine
    } catch {
        return ""
    }
}

function Start-FailoverWatchdog {
    param(
        [switch]$Enabled
    )

    if (-not $Enabled.IsPresent) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $watchdogScriptPath)) {
        throw "Missing watchdog script: $watchdogScriptPath"
    }

    $watchdogPidDir = Split-Path -Parent $watchdogPidFile
    if (-not (Test-Path -LiteralPath $watchdogPidDir)) {
        New-Item -ItemType Directory -Path $watchdogPidDir | Out-Null
    }

    if (Test-Path -LiteralPath $watchdogPidFile) {
        $rawWatchdogPid = (Get-Content -LiteralPath $watchdogPidFile -Raw).Trim()
        if ($rawWatchdogPid -match '^\d+$') {
            $existingWatchdogPid = [int]$rawWatchdogPid
            try {
                $null = Get-Process -Id $existingWatchdogPid -ErrorAction Stop
                $cmd = Get-ProcessCommandLine -Pid $existingWatchdogPid
                if ($cmd -match [regex]::Escape($watchdogScriptName)) {
                    return $existingWatchdogPid
                }
            } catch {
                # stale pid file; continue
            }
        }
    }

    $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    $watchdogArgs = @(
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $watchdogScriptPath,
        "-Port", [string]$Port,
        "-PollSeconds", [string]$WatchdogPollSeconds,
        "-SwitchBackWhenProxyUp", [string]$WatchdogSwitchBackWhenProxyUp
    )

    $watchdogProc = Start-Process -FilePath $pwshPath -ArgumentList $watchdogArgs -PassThru -WindowStyle Hidden
    $watchdogProc.Id | Set-Content -LiteralPath $watchdogPidFile -Encoding ASCII
    return $watchdogProc.Id
}

if ($Background.IsPresent) {
    $pidFile = Join-Path $PSScriptRoot "artifacts\context_guard_proxy.pid"
    $pidDir = Split-Path -Parent $pidFile
    if (-not (Test-Path -LiteralPath $pidDir)) {
        New-Item -ItemType Directory -Path $pidDir | Out-Null
    }

    if (Test-Path -LiteralPath $pidFile) {
        $rawPid = (Get-Content -LiteralPath $pidFile -Raw).Trim()
        if ($rawPid -match '^\d+$') {
            $existingPid = [int]$rawPid
            $existingAlive = $false
            try {
                $null = Get-Process -Id $existingPid -ErrorAction Stop
                $cmd = Get-ProcessCommandLine -Pid $existingPid
                if ($cmd -match [regex]::Escape($proxyScriptName)) {
                    $existingAlive = $true
                } else {
                    $existingAlive = $false
                }
            } catch {
                $existingAlive = $false
            }
            if ($existingAlive) {
                throw "Proxy already running with PID $existingPid. Stop it first."
            }
        }
    }

    $quotedScriptPath = '"' + $scriptPath + '"'
    $proc = Start-Process -FilePath $nodePath -ArgumentList @($quotedScriptPath) -PassThru -WindowStyle Hidden
    $proc.Id | Set-Content -LiteralPath $pidFile -Encoding ASCII

    $watchdogPid = Start-FailoverWatchdog -Enabled:($watchdogEnabled)

    Start-Sleep -Milliseconds 800

    [pscustomobject]@{
        Started = $true
        Mode = "background"
        Pid = $proc.Id
        Port = $Port
        UpstreamBaseUrl = $UpstreamBaseUrl
        SoftThresholdTokens = $SoftThresholdTokens
        EscalateThresholdTokens = $EscalateThresholdTokens
        HardThresholdTokens = $HardThresholdTokens
        ApplyAtSoftThreshold = $applyAtSoft
        PidFile = $pidFile
        LogPath = $resolvedLogPath
        FailoverWatchdogEnabled = $watchdogEnabled
        FailoverWatchdogPid = $watchdogPid
        FailoverWatchdogPidFile = $watchdogPidFile
        WatchdogPollSeconds = $WatchdogPollSeconds
        HealthUrl = "http://127.0.0.1:$Port/__guard/health"
    }
    exit 0
}

$watchdogPid = Start-FailoverWatchdog -Enabled:($watchdogEnabled)

[pscustomobject]@{
    Started = $true
    Mode = "foreground"
    Port = $Port
    UpstreamBaseUrl = $UpstreamBaseUrl
    SoftThresholdTokens = $SoftThresholdTokens
    EscalateThresholdTokens = $EscalateThresholdTokens
    HardThresholdTokens = $HardThresholdTokens
    ApplyAtSoftThreshold = $applyAtSoft
    LogPath = $resolvedLogPath
    FailoverWatchdogEnabled = $watchdogEnabled
    FailoverWatchdogPid = $watchdogPid
    FailoverWatchdogPidFile = $watchdogPidFile
    WatchdogPollSeconds = $WatchdogPollSeconds
    HealthUrl = "http://127.0.0.1:$Port/__guard/health"
}

& $nodePath $scriptPath
