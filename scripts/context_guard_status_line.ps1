function New-ContextGuardStatusLine {
    param(
        [ValidateSet("đang bật", "đang tắt")]
        [string]$ProxyLocalState,
        [ValidateSet("bật", "tắt")]
        [string]$GuardContextState,
        [string]$Mode = "N/A",
        [Nullable[int]]$ProxyInputTokens = $null,
        [Nullable[int]]$ProxyOutputTokens = $null,
        [ValidateSet("chưa kích hoạt", "đã kích hoạt")]
        [string]$SoftTriggerState = "chưa kích hoạt",
        [bool]$IsStale = $false,
        [Nullable[int]]$AgeSeconds = $null
    )

    $inputPart = if ($null -eq $ProxyInputTokens) { "N/A" } else { "~$ProxyInputTokens tokens" }
    $outputPart = if ($null -eq $ProxyOutputTokens) { "N/A" } else { "~$ProxyOutputTokens tokens" }
    return "Proxy local: $ProxyLocalState | Guard: $GuardContextState | Mode: $Mode | Proxy Input: $inputPart | Proxy Output: $outputPart | trigger mềm: $SoftTriggerState"
}
