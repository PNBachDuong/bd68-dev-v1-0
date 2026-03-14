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
        [string]$ProxyLocalState = "",
        [int]$CompressionOnThreshold = 120000,
        [int]$CompressionOffThreshold = 90000
    )

    $inputPart = if ($null -eq $ProxyInputTokens) { "N/A" } else { "~$ProxyInputTokens tokens" }
    $outputPart = if ($null -eq $ProxyOutputTokens) { "N/A" } else { "~$ProxyOutputTokens tokens" }
    $guardLine = "Guard: $GuardContextState | Mode: $Mode | Input: $inputPart | Output: $outputPart | trigger mềm: $SoftTriggerState"

    $compressionState = "N/A (thiếu Input)"
    if ($null -ne $ProxyInputTokens) {
        if ($ProxyInputTokens -ge $CompressionOnThreshold) {
            $compressionState = "bật (giảm token cho input lớn)"
        } elseif ($ProxyInputTokens -le $CompressionOffThreshold) {
            $compressionState = "tắt (input thấp)"
        } else {
            $compressionState = "hysteresis (giữ trạng thái trước)"
        }
    }

    $skillLine = "SkillGate: context-optimization=bật (tối ưu ngữ cảnh); context-window-management=bật (ổn định cửa sổ); context-compression=$compressionState; prompt-caching=N/A (cần cache-hit telemetry); hierarchical-agent-memory=tắt mặc định (chỉ bật khi đa phiên + memory ổn định)"

    return [pscustomobject]@{
        GuardLine = $guardLine
        SkillLine = $skillLine
        CombinedLine = "$guardLine`n$skillLine"
    }
}
