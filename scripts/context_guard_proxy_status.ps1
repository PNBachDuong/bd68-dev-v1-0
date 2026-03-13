param(
    [int]$Port = 8787,
    [string]$ConfigPath = "C:\Users\ngath\.codex\config.toml",
    [bool]$AutoFailover = $true,
    [bool]$SwitchBackWhenProxyUp = $true,
    [string]$ProxyBaseUrl = "http://127.0.0.1:8787",
    [string]$DirectBaseUrl = "https://llmgate.app/v1",
    [ValidateSet("auto", "up", "down")]
    [string]$HealthOverride = "auto"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$statusLineScript = Join-Path $PSScriptRoot "context_guard_status_line.ps1"
if (-not (Test-Path -LiteralPath $statusLineScript)) {
    throw "Missing status line helper: $statusLineScript"
}
. $statusLineScript

function Get-LlmgateBaseUrl {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    $txt = Get-Content -LiteralPath $Path -Raw
    $m = [regex]::Match($txt, '(\[model_providers\.llmgate\][^\[]*?base_url\s*=\s*")([^"]*)(")', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($m.Success) {
        return $m.Groups[2].Value
    }
    return ""
}

function Set-LlmgateBaseUrl {
    param(
        [string]$Path,
        [string]$BaseUrl
    )

    $text = ""
    if (Test-Path -LiteralPath $Path) {
        $text = Get-Content -LiteralPath $Path -Raw
    }

    if ([string]::IsNullOrWhiteSpace($text)) {
        $newText = "[model_providers.llmgate]`r`nbase_url = `"$BaseUrl`"`r`n"
        Set-Content -LiteralPath $Path -Value $newText -Encoding UTF8
        return
    }

    $pattern = '(\[model_providers\.llmgate\][^\[]*?base_url\s*=\s*")([^"]*)(")'
    $m = [regex]::Match($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($m.Success) {
        $start = $m.Groups[2].Index
        $length = $m.Groups[2].Length
        $newText = $text.Remove($start, $length).Insert($start, $BaseUrl)
        Set-Content -LiteralPath $Path -Value $newText -Encoding UTF8
        return
    }

    $sectionPattern = '(?m)^\[model_providers\.llmgate\]\s*$'
    $sectionMatch = [regex]::Match($text, $sectionPattern)
    if ($sectionMatch.Success) {
        $insertAt = $sectionMatch.Index + $sectionMatch.Length
        $insertText = "`r`nbase_url = `"$BaseUrl`"`r`n"
        $newText = $text.Insert($insertAt, $insertText)
        Set-Content -LiteralPath $Path -Value $newText -Encoding UTF8
        return
    }

    $newText = $text.TrimEnd() + "`r`n`r`n[model_providers.llmgate]`r`nbase_url = `"$BaseUrl`"`r`n"
    Set-Content -LiteralPath $Path -Value $newText -Encoding UTF8
}

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

if ($HealthOverride -eq "up") {
    $healthOk = $true
    if ([string]::IsNullOrWhiteSpace($healthBody)) {
        $healthBody = '{"ok":true,"source":"override"}'
    }
} elseif ($HealthOverride -eq "down") {
    $healthOk = $false
    if ([string]::IsNullOrWhiteSpace($healthBody)) {
        $healthBody = '{"ok":false,"source":"override"}'
    }
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

$baseUrl = Get-LlmgateBaseUrl -Path $ConfigPath
$failoverAction = "none"
$failoverReason = ""
$failoverOldBaseUrl = $baseUrl
$failoverNewBaseUrl = $baseUrl

if ($AutoFailover -and (Test-Path -LiteralPath $ConfigPath)) {
    if (-not $healthOk) {
        if ($baseUrl -eq $ProxyBaseUrl) {
            try {
                Set-LlmgateBaseUrl -Path $ConfigPath -BaseUrl $DirectBaseUrl
                $failoverAction = "switched_to_direct"
                $failoverReason = "proxy_down"
                $failoverNewBaseUrl = $DirectBaseUrl
                $baseUrl = $DirectBaseUrl
            } catch {
                $failoverAction = "switch_failed"
                $failoverReason = "proxy_down_write_denied"
                $failoverNewBaseUrl = $baseUrl
            }
        } else {
            $failoverReason = "proxy_down_no_proxy_baseurl_in_config"
        }
    } elseif ($SwitchBackWhenProxyUp) {
        if ($baseUrl -eq $DirectBaseUrl) {
            try {
                Set-LlmgateBaseUrl -Path $ConfigPath -BaseUrl $ProxyBaseUrl
                $failoverAction = "switched_to_proxy"
                $failoverReason = "proxy_up"
                $failoverNewBaseUrl = $ProxyBaseUrl
                $baseUrl = $ProxyBaseUrl
            } catch {
                $failoverAction = "switch_failed"
                $failoverReason = "proxy_up_write_denied"
                $failoverNewBaseUrl = $baseUrl
            }
        } else {
            $failoverReason = "proxy_up_no_direct_baseurl_in_config"
        }
    } else {
        $failoverReason = "switchback_disabled"
    }
} elseif ($AutoFailover -and -not (Test-Path -LiteralPath $ConfigPath)) {
    $failoverReason = "config_not_found"
}

$proxyLocalState = if ($healthOk) { "đang bật" } else { "đang tắt" }
$guardState = if ($healthOk -and $baseUrl -eq $ProxyBaseUrl) { "bật" } else { "tắt" }
$softState = "chưa kích hoạt"
$statusLine = New-ContextGuardStatusLine `
    -ProxyLocalState $proxyLocalState `
    -GuardContextState $guardState `
    -Mode "N/A" `
    -ProxyInputTokens $null `
    -ProxyOutputTokens $null `
    -SoftTriggerState $softState `
    -IsStale $false

[pscustomobject]@{
    ProxyRunning = $running
    ProxyPid = $proxyPid
    PortPid = $portPid
    HealthOk = $healthOk
    HealthBody = $healthBody
    ConfigBaseUrl = $baseUrl
    AutoFailover = $AutoFailover
    SwitchBackWhenProxyUp = $SwitchBackWhenProxyUp
    ProxyBaseUrl = $ProxyBaseUrl
    DirectBaseUrl = $DirectBaseUrl
    FailoverAction = $failoverAction
    FailoverReason = $failoverReason
    FailoverOldBaseUrl = $failoverOldBaseUrl
    FailoverNewBaseUrl = $failoverNewBaseUrl
    HealthOverride = $HealthOverride
    StatusFormatVersion = "v1"
    StatusLine = $statusLine
}
