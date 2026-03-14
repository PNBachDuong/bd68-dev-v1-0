function New-ContextGuardStatusLine {
    param(
        [ValidateSet("bật", "tắt")]
        [string]$GuardContextState,
        [string]$Mode = "N/A",
        [Nullable[int]]$ProxyInputTokens = $null,
        [Nullable[int]]$ProxyOutputTokens = $null,
        [Nullable[int]]$CachedInputTokens = $null,
        [ValidateSet("chưa kích hoạt", "đã kích hoạt")]
        [string]$SoftTriggerState = "chưa kích hoạt",
        [bool]$IsStale = $false,
        [Nullable[int]]$AgeSeconds = $null,
        [string]$ProxyLocalState = "",
        [int]$CompressionOnThreshold = 120000,
        [int]$CompressionOffThreshold = 90000,
        [string[]]$ActiveSkillLines = @(),
        [string[]]$RetrievalLines = @()
    )

    $inputPart = if ($null -eq $ProxyInputTokens) { "N/A" } else { "~$ProxyInputTokens tokens" }
    $outputPart = if ($null -eq $ProxyOutputTokens) { "N/A" } else { "~$ProxyOutputTokens tokens" }
    $guardLine = "Guard: $GuardContextState | Mode: $Mode | Input: $inputPart | Output: $outputPart | trigger mềm: $SoftTriggerState"

    $skillLines = New-Object System.Collections.Generic.List[string]

    if ($null -ne $ActiveSkillLines -and $ActiveSkillLines.Count -gt 0) {
        foreach ($line in $ActiveSkillLines) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $skillLines.Add($line)
            }
        }
    } else {
        $contextOptimizationPct = $null
        if ($null -ne $ProxyInputTokens -and $ProxyInputTokens -gt 0 -and $null -ne $CachedInputTokens -and $CachedInputTokens -ge 0) {
            $rawPct = ($CachedInputTokens / [double]$ProxyInputTokens) * 100
            $contextOptimizationPct = [math]::Round([math]::Min(100.0, [math]::Max(0.0, $rawPct)), 1)
        }

        if ($null -ne $contextOptimizationPct) {
            $skillLines.Add("Skill: context-optimization: bật | tối ưu ~$contextOptimizationPct% (ước tính)")
        } else {
            $skillLines.Add("Skill: context-optimization: bật | tối ưu: không đủ dữ liệu chính xác (ước tính)")
        }
        $skillLines.Add("Skill: context-window-management: bật | mục tiêu: giữ ổn định cửa sổ ngữ cảnh")

        if ($null -ne $ProxyInputTokens -and $ProxyInputTokens -ge $CompressionOnThreshold) {
            $skillLines.Add("Skill: context-compression: bật | điều kiện: input lớn (>= $CompressionOnThreshold)")
        }

        if ($null -ne $ProxyInputTokens -and $ProxyInputTokens -gt 0 -and $null -ne $CachedInputTokens -and $CachedInputTokens -gt 0) {
            $cacheRawPct = ($CachedInputTokens / [double]$ProxyInputTokens) * 100
            $cacheHitPct = [math]::Round([math]::Min(100.0, [math]::Max(0.0, $cacheRawPct)), 1)
            $skillLines.Add("Skill: prompt-caching: bật | cache hit ~$cacheHitPct% (ước tính)")
        }
    }

    if ($null -ne $RetrievalLines -and $RetrievalLines.Count -gt 0) {
        foreach ($line in $RetrievalLines) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $skillLines.Add($line)
            }
        }
    }

    $skillLine = if ($skillLines.Count -gt 0) { ($skillLines -join "`n") } else { "Skill: không có mục kích hoạt trong lượt này" }

    return [pscustomobject]@{
        GuardLine = $guardLine
        SkillLine = $skillLine
        CombinedLine = "$guardLine`n$skillLine"
    }
}
