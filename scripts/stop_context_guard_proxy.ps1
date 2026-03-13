param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$pidFile = Join-Path $PSScriptRoot "artifacts\context_guard_proxy.pid"
if (-not (Test-Path -LiteralPath $pidFile)) {
    [pscustomobject]@{
        Stopped = $false
        Reason = "pid_file_not_found"
    }
    exit 0
}

$rawPid = (Get-Content -LiteralPath $pidFile -Raw).Trim()
if ($rawPid -notmatch '^\d+$') {
    Remove-Item -LiteralPath $pidFile -Force
    [pscustomobject]@{
        Stopped = $false
        Reason = "pid_file_invalid"
    }
    exit 0
}

$proxyPid = [int]$rawPid
try {
    $proc = Get-Process -Id $proxyPid -ErrorAction Stop
    Stop-Process -Id $proxyPid -Force
    Remove-Item -LiteralPath $pidFile -Force
    [pscustomobject]@{
        Stopped = $true
        Pid = $proxyPid
        Name = $proc.ProcessName
    }
} catch {
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Stopped = $false
        Pid = $proxyPid
        Reason = "process_not_found_or_already_stopped"
    }
}
