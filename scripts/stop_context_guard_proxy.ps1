param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

$watchdogPidFile = Join-Path $PSScriptRoot "artifacts\context_guard_failover_watchdog.pid"
$watchdogStopped = $false
$watchdogPid = $null
$watchdogReason = ""
$watchdogScriptName = "context_guard_failover_watchdog.ps1"
$proxyScriptName = "context_guard_proxy.js"

if (Test-Path -LiteralPath $watchdogPidFile) {
    $rawWatchdogPid = (Get-Content -LiteralPath $watchdogPidFile -Raw).Trim()
    if ($rawWatchdogPid -match '^\d+$') {
        $watchdogPid = [int]$rawWatchdogPid
        try {
            $null = Get-Process -Id $watchdogPid -ErrorAction Stop
            $watchdogCmd = Get-ProcessCommandLine -Pid $watchdogPid
            if ($watchdogCmd -match [regex]::Escape($watchdogScriptName)) {
                Stop-Process -Id $watchdogPid -Force
                $watchdogStopped = $true
                $watchdogReason = "stopped"
            } else {
                $watchdogStopped = $false
                $watchdogReason = "pid_reused_not_watchdog"
            }
        } catch {
            $watchdogStopped = $false
            $watchdogReason = "process_not_found_or_already_stopped"
        }
    } else {
        $watchdogReason = "pid_file_invalid"
    }

    Remove-Item -LiteralPath $watchdogPidFile -Force -ErrorAction SilentlyContinue
}

$pidFile = Join-Path $PSScriptRoot "artifacts\context_guard_proxy.pid"
if (-not (Test-Path -LiteralPath $pidFile)) {
    [pscustomobject]@{
        Stopped = $false
        Reason = "pid_file_not_found"
        WatchdogStopped = $watchdogStopped
        WatchdogPid = $watchdogPid
        WatchdogReason = if ([string]::IsNullOrWhiteSpace($watchdogReason)) { "pid_file_not_found" } else { $watchdogReason }
    }
    exit 0
}

$rawPid = (Get-Content -LiteralPath $pidFile -Raw).Trim()
if ($rawPid -notmatch '^\d+$') {
    Remove-Item -LiteralPath $pidFile -Force
    [pscustomobject]@{
        Stopped = $false
        Reason = "pid_file_invalid"
        WatchdogStopped = $watchdogStopped
        WatchdogPid = $watchdogPid
        WatchdogReason = if ([string]::IsNullOrWhiteSpace($watchdogReason)) { "pid_file_not_found" } else { $watchdogReason }
    }
    exit 0
}

$proxyPid = [int]$rawPid
try {
    $proc = Get-Process -Id $proxyPid -ErrorAction Stop
    $proxyCmd = Get-ProcessCommandLine -Pid $proxyPid
    if ($proxyCmd -match [regex]::Escape($proxyScriptName)) {
        Stop-Process -Id $proxyPid -Force
        Remove-Item -LiteralPath $pidFile -Force
        [pscustomobject]@{
            Stopped = $true
            Pid = $proxyPid
            Name = $proc.ProcessName
            WatchdogStopped = $watchdogStopped
            WatchdogPid = $watchdogPid
            WatchdogReason = if ([string]::IsNullOrWhiteSpace($watchdogReason)) { "not_running" } else { $watchdogReason }
        }
    } else {
        Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Stopped = $false
            Pid = $proxyPid
            Reason = "pid_reused_not_proxy_process"
            WatchdogStopped = $watchdogStopped
            WatchdogPid = $watchdogPid
            WatchdogReason = if ([string]::IsNullOrWhiteSpace($watchdogReason)) { "not_running" } else { $watchdogReason }
        }
    }
} catch {
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Stopped = $false
        Pid = $proxyPid
        Reason = "process_not_found_or_already_stopped"
        WatchdogStopped = $watchdogStopped
        WatchdogPid = $watchdogPid
        WatchdogReason = if ([string]::IsNullOrWhiteSpace($watchdogReason)) { "not_running" } else { $watchdogReason }
    }
}
