param(
    [string]$LogPath = ".\scripts\artifacts\context_guard_thread.log",
    [int]$ScanTail = 300,
    [int]$StaleAfterSeconds = 90
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $LogPath)) {
    $legacyLogPath = ".\scripts\artifacts\context_guard_proxy.log"
    if (Test-Path -LiteralPath $legacyLogPath) {
        $LogPath = $legacyLogPath
    }
}

if (-not (Test-Path -LiteralPath $LogPath)) {
    [pscustomobject]@{
        Found = $false
        Reason = "log_not_found"
        LogPath = $LogPath
    }
    exit 0
}

$lines = Get-Content -LiteralPath $LogPath -Tail $ScanTail
$pattern = '^(?<ts>\S+)\s+method=(?<method>\S+)\s+path=(?<path>\S+)\s+trigger=(?<trigger>\S+)\s+mode=(?<mode>\S+)\s+applied=(?<applied>\S+)(?:\s+pre_chars=(?<prechars>\d+)\s+post_chars=(?<postchars>\d+))?\s+pre=(?<pre>\d+)\s+post=(?<post>\d+)\s+reduction_pct=(?<reduction>[\d.]+)\s+model_in=(?<modelin>\S+)\s+model_out=(?<modelout>\S+)\s+resp_stream=(?<respstream>\S+)\s+usage_parse=(?<usageparse>\S+)\s+parse_error=(?<parse>\S+)\s+duration_ms=(?<duration>\d+)'

$hit = $null
for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    $m = [regex]::Match($lines[$i], $pattern)
    if ($m.Success) {
        $hit = $m
        break
    }
}

if ($null -eq $hit) {
    [pscustomobject]@{
        Found = $false
        Reason = "no_thread_response_line_found"
        LogPath = $LogPath
        ScanTail = $ScanTail
    }
    exit 0
}

$toNullableInt = {
    param([string]$raw)
    if ([string]::IsNullOrWhiteSpace($raw) -or $raw -eq "na") { return $null }
    return [int]$raw
}

$ts = [datetimeoffset]::Parse($hit.Groups["ts"].Value, [System.Globalization.CultureInfo]::InvariantCulture)
$ageSeconds = [int][math]::Max(0, [math]::Round(([datetimeoffset]::UtcNow - $ts).TotalSeconds))
$isStale = $ageSeconds -gt $StaleAfterSeconds

$preTokens = [int]$hit.Groups["pre"].Value
$postTokens = [int]$hit.Groups["post"].Value
$preCharsRaw = $hit.Groups["prechars"].Value
$postCharsRaw = $hit.Groups["postchars"].Value
$preChars = if ([string]::IsNullOrWhiteSpace($preCharsRaw)) { $null } else { [int]$preCharsRaw }
$postChars = if ([string]::IsNullOrWhiteSpace($postCharsRaw)) { $null } else { [int]$postCharsRaw }

$modelIn = & $toNullableInt $hit.Groups["modelin"].Value
$modelOut = & $toNullableInt $hit.Groups["modelout"].Value

$clientToProxy = if ($null -ne $preChars) {
    "input -> thread: ~$preTokens tokens (chars=$preChars)"
} else {
    "input -> thread: ~$preTokens tokens"
}

$proxyToLlmgate = if ($null -ne $postChars) {
    "thread -> llmgate: ~$postTokens tokens (chars=$postChars)"
} else {
    "thread -> llmgate: ~$postTokens tokens"
}

$llmgateToProxy = if ($null -eq $modelIn -and $null -eq $modelOut) {
    "llmgate -> thread: model usage N/A (need successful upstream usage fields)"
} else {
    "llmgate -> thread: model_in=$modelIn model_out=$modelOut"
}

[pscustomobject]@{
    Found = $true
    TimestampUtc = $hit.Groups["ts"].Value
    AgeSeconds = $ageSeconds
    IsStale = $isStale
    Method = $hit.Groups["method"].Value
    Path = $hit.Groups["path"].Value
    Trigger = $hit.Groups["trigger"].Value
    Mode = $hit.Groups["mode"].Value
    Applied = ($hit.Groups["applied"].Value -eq "true")
    ProxyInputChars = $preChars
    ProxyOutputChars = $postChars
    ProxyInputTokensEstimate = $preTokens
    ProxyOutputTokensEstimate = $postTokens
    ThreadInputChars = $preChars
    ThreadOutputChars = $postChars
    ThreadInputTokensEstimate = $preTokens
    ThreadOutputTokensEstimate = $postTokens
    ReductionPct = [double]$hit.Groups["reduction"].Value
    ModelInputTokens = $modelIn
    ModelOutputTokens = $modelOut
    UsageParse = $hit.Groups["usageparse"].Value
    ResponseStreamed = $hit.Groups["respstream"].Value
    ParseError = $hit.Groups["parse"].Value
    DurationMs = [int]$hit.Groups["duration"].Value
    RequestPath = "$clientToProxy | $proxyToLlmgate"
    ResponsePath = $llmgateToProxy
}
