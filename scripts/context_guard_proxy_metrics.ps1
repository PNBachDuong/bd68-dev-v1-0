param(
    [string]$LogPath = ".\scripts\artifacts\context_guard_proxy.log",
    [int]$ScanTail = 300,
    [int]$MinPreTokens = 0,
    [int]$StaleAfterSeconds = 90,
    [int]$ProxyPort = 8787,
    [switch]$AutoProbeWhenStale = $true,
    [int]$ProbeTimeoutSeconds = 12,
    [string]$ProbeModel = "gpt-5.4",
    [string]$ProbeInput = "ping"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$statusLineScript = Join-Path $PSScriptRoot "context_guard_status_line.ps1"
if (-not (Test-Path -LiteralPath $statusLineScript)) {
    throw "Missing status line helper: $statusLineScript"
}
. $statusLineScript

function Test-ProxyLocalRunning {
    param([int]$Port)
    try {
        $healthUrl = "http://127.0.0.1:$Port/__guard/health"
        $healthRaw = curl.exe -s $healthUrl
        return -not [string]::IsNullOrWhiteSpace($healthRaw)
    } catch {
        return $false
    }
}

function Invoke-ProxyProbe {
    param(
        [int]$Port,
        [int]$TimeoutSec,
        [string]$Model,
        [string]$InputText
    )
    $probeUrl = "http://127.0.0.1:$Port/v1/responses"
    $probeBody = @{
        model = $Model
        input = $InputText
        max_output_tokens = 1
        store = $false
    } | ConvertTo-Json -Compress
    try {
        $null = Invoke-WebRequest -Uri $probeUrl -Method Post -ContentType "application/json" -Body $probeBody -TimeoutSec $TimeoutSec
        return [pscustomobject]@{
            Attempted = $true
            Succeeded = $true
            Error = $null
        }
    } catch {
        return [pscustomobject]@{
            Attempted = $true
            Succeeded = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-LatestProxyMatch {
    param(
        [string]$Path,
        [int]$Tail,
        [string]$Pattern,
        [int]$MinimumPreTokens
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            Found = $false
            Reason = "log_not_found"
            Hit = $null
        }
    }

    $lines = Get-Content -LiteralPath $Path -Tail $Tail
    $hit = $null
    $fallback = $null
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $m = [regex]::Match($lines[$i], $Pattern)
        if ($m.Success) {
            if ($null -eq $fallback) {
                $fallback = $m
            }
            $preCandidate = [int]$m.Groups["pre"].Value
            if ($preCandidate -ge $MinimumPreTokens) {
                $hit = $m
                break
            }
        }
    }
    if ($null -eq $hit -and $null -ne $fallback) {
        $hit = $fallback
    }
    if ($null -eq $hit) {
        return [pscustomobject]@{
            Found = $false
            Reason = "no_proxy_response_line_found"
            Hit = $null
        }
    }
    return [pscustomobject]@{
        Found = $true
        Reason = ""
        Hit = $hit
    }
}

function Get-AgeInfo {
    param(
        [System.Text.RegularExpressions.Match]$Match,
        [int]$StaleSeconds
    )
    $ageSeconds = $null
    $isStale = $false
    try {
        $ts = [datetimeoffset]::Parse($Match.Groups["ts"].Value, [System.Globalization.CultureInfo]::InvariantCulture)
        $ageSeconds = [int][math]::Max(0, [math]::Round(([datetimeoffset]::UtcNow - $ts).TotalSeconds))
        if ($ageSeconds -gt $StaleSeconds) {
            $isStale = $true
        }
    } catch {
        $isStale = $false
    }
    return [pscustomobject]@{
        AgeSeconds = $ageSeconds
        IsStale = $isStale
    }
}

$pattern = '^(?<ts>\S+)\s+method=POST\s+path=/(?:v1/)?responses\s+trigger=(?<trigger>\S+)\s+mode=(?<mode>\S+)\s+applied=(?<applied>\S+)(?:\s+pre_chars=(?<prechars>\d+)\s+post_chars=(?<postchars>\d+))?\s+pre=(?<pre>\d+)\s+post=(?<post>\d+)\s+reduction_pct=(?<reduction>[\d.]+)(?:\s+model_in=(?<modelin>\S+)\s+model_out=(?<modelout>\S+)\s+resp_stream=(?<respstream>\S+)\s+usage_parse=(?<usageparse>\S+))?\s+parse_error=(?<parse>\S+)\s+duration_ms=(?<duration>\d+)'
$proxyLocalRunning = Test-ProxyLocalRunning -Port $ProxyPort
$proxyLocalState = if ($proxyLocalRunning) { "đang bật" } else { "đang tắt" }

$probeAttempted = $false
$probeSucceeded = $false
$probeError = $null
$lookup = Get-LatestProxyMatch -Path $LogPath -Tail $ScanTail -Pattern $pattern -MinimumPreTokens $MinPreTokens
if (-not $lookup.Found -and $AutoProbeWhenStale -and $proxyLocalRunning) {
    $probeResult = Invoke-ProxyProbe -Port $ProxyPort -TimeoutSec $ProbeTimeoutSeconds -Model $ProbeModel -InputText $ProbeInput
    $probeAttempted = $probeResult.Attempted
    $probeSucceeded = $probeResult.Succeeded
    $probeError = $probeResult.Error
    Start-Sleep -Milliseconds 350
    $lookup = Get-LatestProxyMatch -Path $LogPath -Tail $ScanTail -Pattern $pattern -MinimumPreTokens $MinPreTokens
}

if (-not $lookup.Found) {
    $statusLine = New-ContextGuardStatusLine `
        -ProxyLocalState $proxyLocalState `
        -GuardContextState "tắt" `
        -Mode "N/A" `
        -ProxyInputTokens $null `
        -ProxyOutputTokens $null `
        -SoftTriggerState "chưa kích hoạt"
    [pscustomobject]@{
        Found = $false
        Reason = $lookup.Reason
        LogPath = $LogPath
        ScanTail = $ScanTail
        MinPreTokens = $MinPreTokens
        StaleAfterSeconds = $StaleAfterSeconds
        ProxyPort = $ProxyPort
        ProxyLocalRunning = $proxyLocalRunning
        ProxyLocalState = $proxyLocalState
        ProbeAttempted = $probeAttempted
        ProbeSucceeded = $probeSucceeded
        ProbeError = $probeError
        StatusFormatVersion = "v1"
        StatusLine = $statusLine
    }
    exit 0
}

$hit = $lookup.Hit
$ageInfo = Get-AgeInfo -Match $hit -StaleSeconds $StaleAfterSeconds
$ageSeconds = $ageInfo.AgeSeconds
$isStale = $ageInfo.IsStale

if ($isStale -and $AutoProbeWhenStale -and $proxyLocalRunning) {
    $probeResult = Invoke-ProxyProbe -Port $ProxyPort -TimeoutSec $ProbeTimeoutSeconds -Model $ProbeModel -InputText $ProbeInput
    $probeAttempted = $probeResult.Attempted
    $probeSucceeded = $probeResult.Succeeded
    $probeError = $probeResult.Error
    Start-Sleep -Milliseconds 350
    $lookupAfterProbe = Get-LatestProxyMatch -Path $LogPath -Tail $ScanTail -Pattern $pattern -MinimumPreTokens $MinPreTokens
    if ($lookupAfterProbe.Found) {
        $hit = $lookupAfterProbe.Hit
        $ageInfo = Get-AgeInfo -Match $hit -StaleSeconds $StaleAfterSeconds
        $ageSeconds = $ageInfo.AgeSeconds
        $isStale = $ageInfo.IsStale
    }
}

$pre = [int]$hit.Groups["pre"].Value
$post = [int]$hit.Groups["post"].Value
$trigger = $hit.Groups["trigger"].Value
$mode = $hit.Groups["mode"].Value
$applied = ($hit.Groups["applied"].Value -eq "true")
$reduction = [double]$hit.Groups["reduction"].Value
$modelInRaw = $hit.Groups["modelin"].Value
$modelOutRaw = $hit.Groups["modelout"].Value
$modelIn = if ([string]::IsNullOrWhiteSpace($modelInRaw) -or $modelInRaw -eq "na") { $null } else { [int]$modelInRaw }
$modelOut = if ([string]::IsNullOrWhiteSpace($modelOutRaw) -or $modelOutRaw -eq "na") { $null } else { [int]$modelOutRaw }
$responseStreamed = $hit.Groups["respstream"].Value
$usageParse = $hit.Groups["usageparse"].Value

$softState = if ($trigger -eq "inactive") { "chưa kích hoạt" } else { "đã kích hoạt" }
$guardState = if ($applied) { "bật" } else { "tắt" }

if ($isStale) {
    $statusLine = New-ContextGuardStatusLine `
        -ProxyLocalState $proxyLocalState `
        -GuardContextState "tắt" `
        -Mode "N/A" `
        -ProxyInputTokens $null `
        -ProxyOutputTokens $null `
        -SoftTriggerState "chưa kích hoạt" `
        -IsStale $true `
        -AgeSeconds $ageSeconds
} else {
    $statusLine = New-ContextGuardStatusLine `
        -ProxyLocalState $proxyLocalState `
        -GuardContextState $guardState `
        -Mode $mode `
        -ProxyInputTokens $pre `
        -ProxyOutputTokens $post `
        -SoftTriggerState $softState `
        -IsStale $false `
        -AgeSeconds $ageSeconds
}

[pscustomobject]@{
    Found = $true
    TimestampUtc = $hit.Groups["ts"].Value
    Trigger = $trigger
    Mode = $mode
    Applied = $applied
    ProxyInputTokensEstimate = $pre
    ProxyOutputTokensEstimate = $post
    ModelInputTokens = $modelIn
    ModelOutputTokens = $modelOut
    ResponseStreamed = if ([string]::IsNullOrWhiteSpace($responseStreamed)) { "unknown" } else { $responseStreamed }
    UsageParse = if ([string]::IsNullOrWhiteSpace($usageParse)) { "unknown" } else { $usageParse }
    ReductionPct = $reduction
    ParseError = $hit.Groups["parse"].Value
    DurationMs = [int]$hit.Groups["duration"].Value
    LogPath = (Resolve-Path -LiteralPath $LogPath).Path
    MinPreTokens = $MinPreTokens
    StaleAfterSeconds = $StaleAfterSeconds
    AgeSeconds = $ageSeconds
    IsStale = $isStale
    ProxyPort = $ProxyPort
    ProxyLocalRunning = $proxyLocalRunning
    ProxyLocalState = $proxyLocalState
    ProbeAttempted = $probeAttempted
    ProbeSucceeded = $probeSucceeded
    ProbeError = $probeError
    StatusFormatVersion = "v1"
    StatusLine = $statusLine
}
