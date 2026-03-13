param(
    [string]$LogPath = ".\scripts\artifacts\context_guard_proxy.log",
    [int]$ScanTail = 300,
    [int]$MinPreTokens = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $LogPath)) {
    [pscustomobject]@{
        Found = $false
        Reason = "log_not_found"
        LogPath = $LogPath
    }
    exit 0
}

$lines = Get-Content -LiteralPath $LogPath -Tail $ScanTail
$pattern = '^(?<ts>\S+)\s+method=POST\s+path=/v1/responses\s+trigger=(?<trigger>\S+)\s+mode=(?<mode>\S+)\s+applied=(?<applied>\S+)\s+pre=(?<pre>\d+)\s+post=(?<post>\d+)\s+reduction_pct=(?<reduction>[\d.]+)(?:\s+model_in=(?<modelin>\S+)\s+model_out=(?<modelout>\S+)\s+resp_stream=(?<respstream>\S+)\s+usage_parse=(?<usageparse>\S+))?\s+parse_error=(?<parse>\S+)\s+duration_ms=(?<duration>\d+)'

$hit = $null
$fallback = $null
for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    $m = [regex]::Match($lines[$i], $pattern)
    if ($m.Success) {
        if ($null -eq $fallback) {
            $fallback = $m
        }
        $preCandidate = [int]$m.Groups["pre"].Value
        if ($preCandidate -ge $MinPreTokens) {
            $hit = $m
            break
        }
    }
}

if ($null -eq $hit -and $null -ne $fallback) {
    $hit = $fallback
}

if ($null -eq $hit) {
    [pscustomobject]@{
        Found = $false
        Reason = "no_proxy_response_line_found"
        LogPath = $LogPath
        ScanTail = $ScanTail
        MinPreTokens = $MinPreTokens
    }
    exit 0
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

$statusLine = "Guard Context: $guardState | Proxy Input: ~$pre tokens | Proxy Output: ~$post tokens | trigger mềm: $softState"

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
    StatusLine = $statusLine
}
