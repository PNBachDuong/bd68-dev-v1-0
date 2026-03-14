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
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'

    function Add-UniqueSkillLine {
        param(
            [System.Collections.Generic.List[string]]$Bucket,
            [System.Collections.Generic.HashSet[string]]$Seen,
            [string]$Line
        )

        if ([string]::IsNullOrWhiteSpace($Line)) {
            return
        }
        if ($Seen.Add($Line)) {
            $Bucket.Add($Line)
        }
    }

    if ($null -ne $ActiveSkillLines -and $ActiveSkillLines.Count -gt 0) {
        foreach ($line in $ActiveSkillLines) {
            Add-UniqueSkillLine -Bucket $skillLines -Seen $seen -Line $line
        }
    } else {
        Add-UniqueSkillLine -Bucket $skillLines -Seen $seen -Line "Skill: context-optimization: bật | vai trò: lọc ngữ cảnh liên quan, giảm nhiễu"
        Add-UniqueSkillLine -Bucket $skillLines -Seen $seen -Line "Skill: context-window-management: bật | mục tiêu: giữ ổn định cửa sổ ngữ cảnh"

        if ($null -ne $ProxyInputTokens -and $ProxyInputTokens -ge $CompressionOnThreshold) {
            Add-UniqueSkillLine -Bucket $skillLines -Seen $seen -Line "Skill: context-compression: bật | điều kiện: input lớn (>= $CompressionOnThreshold)"
        }

        if ($null -ne $ProxyInputTokens -and $ProxyInputTokens -gt 0 -and $null -ne $CachedInputTokens -and $CachedInputTokens -gt 0) {
            $cacheRawPct = ($CachedInputTokens / [double]$ProxyInputTokens) * 100
            $cacheHitPct = [math]::Round([math]::Min(100.0, [math]::Max(0.0, $cacheRawPct)), 1)
            Add-UniqueSkillLine -Bucket $skillLines -Seen $seen -Line "Prompt cache: bật | tái sử dụng input: ~$cacheHitPct% ($CachedInputTokens/$ProxyInputTokens tokens) | tác động: tiết kiệm token cao"
        }
    }

    if ($null -ne $RetrievalLines -and $RetrievalLines.Count -gt 0) {
        foreach ($line in $RetrievalLines) {
            Add-UniqueSkillLine -Bucket $skillLines -Seen $seen -Line $line
        }
    }

    $skillLine = if ($skillLines.Count -gt 0) { ($skillLines -join "`n") } else { "Skill: không có mục kích hoạt trong lượt này" }

    return [pscustomobject]@{
        GuardLine = $guardLine
        SkillLine = $skillLine
        CombinedLine = "$guardLine`n$skillLine"
    }
}
