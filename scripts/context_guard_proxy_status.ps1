param(
    [int]$Port = 8787,
    [string]$ConfigPath = "C:\Users\ngath\.codex\config.toml"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$pidFile = Join-Path $PSScriptRoot "artifacts\context_guard_proxy.pid"
$proxyPid = $null
$running = $false
$portPid = $null

if (Test-Path -LiteralPath $pidFile) {
    $raw = (Get-Content -LiteralPath $pidFile -Raw).Trim()
    if ($raw -match '^\d+$') {
        $proxyPid = [int]$raw
        try {
            $null = Get-Process -Id $proxyPid -ErrorAction Stop
            $running = $true
        } catch {
            $running = $false
        }
    }
}

$healthOk = $false
$healthBody = ""
try {
    $healthUrl = "http://127.0.0.1:$Port/__guard/health"
    $healthBody = curl.exe -s $healthUrl
    if (-not [string]::IsNullOrWhiteSpace($healthBody)) {
        $healthOk = $true
    }
} catch {
    $healthOk = $false
}

try {
    $lines = netstat -ano | Select-String ":$Port"
    foreach ($line in $lines) {
        $txt = $line.ToString().Trim()
        if ($txt -match "LISTENING\s+(\d+)$") {
            $portPid = [int]$matches[1]
            break
        }
    }
} catch {
    $portPid = $null
}

if (-not $running -and $healthOk) {
    $running = $true
}

if ($null -ne $portPid) {
    if (-not $running) {
        $running = $true
    }
    if ($null -eq $proxyPid -or $proxyPid -ne $portPid) {
        $proxyPid = $portPid
        try {
            $pidDir = Split-Path -Parent $pidFile
            if (-not (Test-Path -LiteralPath $pidDir)) {
                New-Item -ItemType Directory -Path $pidDir | Out-Null
            }
            $proxyPid | Set-Content -LiteralPath $pidFile -Encoding ASCII
        } catch {
            # ignore pid file refresh errors
        }
    }
}

$baseUrl = ""
if (Test-Path -LiteralPath $ConfigPath) {
    $txt = Get-Content -LiteralPath $ConfigPath -Raw
    $m = [regex]::Match($txt, '(\[model_providers\.llmgate\][^\[]*?base_url\s*=\s*")([^"]*)(")', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($m.Success) {
        $baseUrl = $m.Groups[2].Value
    }
}

[pscustomobject]@{
    ProxyRunning = $running
    ProxyPid = $proxyPid
    PortPid = $portPid
    HealthOk = $healthOk
    HealthBody = $healthBody
    ConfigBaseUrl = $baseUrl
}
