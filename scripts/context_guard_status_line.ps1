function New-ContextGuardStatusLine {
    param(
        [ValidateSet("bật", "tắt")]
        [string]$GuardContextState,
        [string]$Mode = "N/A",
        [Nullable[int]]$ProxyInputTokens = $null,
        [Nullable[int]]$ProxyOutputTokens = $null,
        [ValidateSet("chưa kích hoạt", "đã kích hoạt")]
        [string]$SoftTriggerState = "chưa kích hoạt",
        [bool]$IsStale = $false,
        [Nullable[int]]$AgeSeconds = $null,
        [string]$ProxyLocalState = ""
    )

    $inputPart = if ($null -eq $ProxyInputTokens) { "N/A" } else { "~$ProxyInputTokens tokens" }
    $outputPart = if ($null -eq $ProxyOutputTokens) { "N/A" } else { "~$ProxyOutputTokens tokens" }
    return "Guard: $GuardContextState | Mode: $Mode | Input: $inputPart | Output: $outputPart | trigger mềm: $SoftTriggerState"
}
