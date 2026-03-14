param(
    [string]$CodexRoot = "C:\Users\ngath\.codex",
    [int]$ScanTail = 600,
    [int]$UsageScanTail = 2000,
    [int]$MaxRecentFiles = 60,
    [int]$MaxLibrariesPerSource = 3,
    [int]$SoftThresholdTokens = 200000,
    [int]$EscalateThresholdTokens = 240000,
    [int]$HardThresholdTokens = 250000,

    # Legacy compatibility params (kept to avoid breaking existing calls).
    [string]$LogPath = "",
    [int]$MinPreTokens = 0,
    [int]$StaleAfterSeconds = 0,
    [int]$ProxyPort = 8787,
    [switch]$AutoProbeWhenStale = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($SoftThresholdTokens -gt $EscalateThresholdTokens -or $EscalateThresholdTokens -gt $HardThresholdTokens) {
    throw "Invalid thresholds: require Soft <= Escalate <= Hard."
}

$statusLineScript = Join-Path $PSScriptRoot "context_guard_status_line.ps1"
if (-not (Test-Path -LiteralPath $statusLineScript)) {
    throw "Missing status line helper: $statusLineScript"
}
. $statusLineScript

function Convert-ToNullableInt {
    param($Value)
    try {
        if ($null -eq $Value) {
            return $null
        }
        $asText = [string]$Value
        if ([string]::IsNullOrWhiteSpace($asText)) {
            return $null
        }
        return [int]$Value
    } catch {
        return $null
    }
}

function Get-RecentSessionFiles {
    param(
        [string]$Root,
        [int]$Limit
    )
    $all = @()
    $paths = @(
        (Join-Path $Root "sessions"),
        (Join-Path $Root "archived_sessions")
    )

    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p) {
            try {
                $all += Get-ChildItem -Path $p -Recurse -File -Filter "*.jsonl" -ErrorAction SilentlyContinue
            } catch {
                # Ignore scan errors for one path and continue with others.
            }
        }
    }

    if ($all.Count -eq 0) {
        return @()
    }

    return $all | Sort-Object LastWriteTime -Descending | Select-Object -First $Limit
}

function Get-LatestTokenEventFromFile {
    param(
        [string]$Path,
        [int]$Tail
    )
    $lines = @()
    try {
        $lines = Get-Content -LiteralPath $Path -Tail $Tail -ErrorAction Stop
    } catch {
        return $null
    }

    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $line = $lines[$i]
        if (-not [regex]::IsMatch($line, '"type"\s*:\s*"token_count"')) {
            continue
        }

        try {
            $obj = $line | ConvertFrom-Json -ErrorAction Stop
            $info = $obj.payload.info
            if ($null -eq $info) {
                continue
            }

            return [pscustomobject]@{
                SessionFile = $Path
                Timestamp = [string]$obj.timestamp
                LastInputTokens = Convert-ToNullableInt $info.last_token_usage.input_tokens
                LastCachedInputTokens = Convert-ToNullableInt $info.last_token_usage.cached_input_tokens
                LastOutputTokens = Convert-ToNullableInt $info.last_token_usage.output_tokens
                TotalInputTokens = Convert-ToNullableInt $info.total_token_usage.input_tokens
                TotalOutputTokens = Convert-ToNullableInt $info.total_token_usage.output_tokens
                ModelContextWindow = Convert-ToNullableInt $info.model_context_window
            }
        } catch {
            continue
        }
    }

    return $null
}

function Parse-JsonObjectOrNull {
    param([string]$JsonText)
    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        return $null
    }
    try {
        return $JsonText | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
}

function Get-AddonStatusFromRuntime {
    param([string]$Root)

    $configPath = Join-Path $Root "config.toml"
    $serenaConfigured = $false
    if (Test-Path -LiteralPath $configPath) {
        try {
            $configText = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop
            if ($configText -match '(?ms)^\[mcp_servers\.serena\]\s*.*?(?=^\[|\z)') {
                $serenaConfigured = $true
            }
        } catch {
            $serenaConfigured = $false
        }
    }

    $gstackLitePath = Join-Path $Root "skills\gstack-lite\SKILL.md"
    $gstackLiteInstalled = Test-Path -LiteralPath $gstackLitePath

    $lines = New-Object System.Collections.Generic.List[string]
    if ($serenaConfigured) {
        $lines.Add("Serena: bật (on-demand) | mục đích: local code retrieval/edit")
    }
    if ($gstackLiteInstalled) {
        $lines.Add("gstack-lite: bật (on-demand) | gate: product/engineering/ship")
    }

    return [pscustomobject]@{
        SerenaConfigured = $serenaConfigured
        GstackLiteInstalled = $gstackLiteInstalled
        AddonLines = @($lines)
    }
}

function Get-RetrievalUsageFromFile {
    param(
        [string]$Path,
        [int]$Tail,
        [int]$MaxLibraries
    )

    $lines = @()
    try {
        $lines = Get-Content -LiteralPath $Path -Tail $Tail -ErrorAction Stop
    } catch {
        $lines = @()
    }

    $context7Libs = New-Object System.Collections.Generic.List[string]
    $contextHubLibs = New-Object System.Collections.Generic.List[string]
    $context7Calls = 0
    $contextHubCalls = 0
    $context7Used = $false
    $contextHubUsed = $false
    $serenaCalls = 0
    $serenaUsed = $false
    $gstackLiteUsed = $false

    foreach ($line in $lines) {
        if (-not $gstackLiteUsed -and $line -match '(?i)gstack-lite|product-gate|engineering-gate|ship-gate') {
            $gstackLiteUsed = $true
        }

        if (-not $line.Contains("function_call")) {
            continue
        }

        $entry = Parse-JsonObjectOrNull -JsonText $line
        if ($null -eq $entry) {
            continue
        }

        $payload = $entry.payload
        if ($null -eq $payload -or [string]$payload.type -ne "function_call") {
            continue
        }

        $name = [string]$payload.name
        $argumentsRaw = [string]$payload.arguments
        $arguments = Parse-JsonObjectOrNull -JsonText $argumentsRaw

        if ($name -like "mcp__*serena*") {
            $serenaUsed = $true
            $serenaCalls++
            continue
        }

        if ($name -like "mcp__chub__*") {
            $contextHubUsed = $true
            $contextHubCalls++
            if ($null -ne $arguments) {
                $idProp = $arguments.PSObject.Properties["id"]
                $id = if ($null -ne $idProp) { [string]$idProp.Value } else { "" }
                if (-not [string]::IsNullOrWhiteSpace($id) -and -not $contextHubLibs.Contains($id)) {
                    $contextHubLibs.Add($id)
                }
            }
            continue
        }

        if ($name -like "mcp__*context7*") {
            $context7Used = $true
            $context7Calls++
            if ($null -eq $arguments) {
                continue
            }

            $candidateFields = @(
                "libraryId",
                "library_id",
                "libraryName",
                "library_name",
                "context7CompatibleLibraryID"
            )
            foreach ($field in $candidateFields) {
                    $value = $arguments.PSObject.Properties[$field]
                    if ($null -ne $value) {
                        $text = [string]$value.Value
                        # Keep library-like identifiers only (avoid generic free-text queries).
                        if (-not [string]::IsNullOrWhiteSpace($text) -and -not ($text -match '\s') -and -not $context7Libs.Contains($text)) {
                            $context7Libs.Add($text)
                        }
                        break
                    }
                }
        }
    }

    $context7Top = @($context7Libs | Select-Object -First $MaxLibraries)
    $contextHubTop = @($contextHubLibs | Select-Object -First $MaxLibraries)

    $retrievalLines = New-Object System.Collections.Generic.List[string]
    if ($context7Used) {
        if ($context7Top.Count -gt 0) {
            $retrievalLines.Add("Context7: đã truy cập thư viện: $($context7Top -join ', ')")
        } else {
            $retrievalLines.Add("Context7: đã truy cập (không có tên thư viện trong log)")
        }
    }
    if ($contextHubUsed) {
        if ($contextHubTop.Count -gt 0) {
            $retrievalLines.Add("ContextHub: đã truy cập thư viện: $($contextHubTop -join ', ')")
        } else {
            $retrievalLines.Add("ContextHub: đã truy cập (không có id thư viện trong log)")
        }
    }
    if ($serenaUsed) {
        $retrievalLines.Add("Serena: đã truy cập local code tools trong phiên")
    }
    if ($gstackLiteUsed) {
        $retrievalLines.Add("gstack-lite: đã kích hoạt gate điều phối trong phiên")
    }

    return [pscustomobject]@{
        Context7Used = $context7Used
        ContextHubUsed = $contextHubUsed
        Context7Calls = $context7Calls
        ContextHubCalls = $contextHubCalls
        SerenaUsed = $serenaUsed
        SerenaCalls = $serenaCalls
        GstackLiteUsed = $gstackLiteUsed
        Context7Libraries = $context7Top
        ContextHubLibraries = $contextHubTop
        RetrievalLines = @($retrievalLines)
    }
}

function Resolve-GuardDecision {
    param(
        [Nullable[int]]$InputTokens,
        [int]$SoftThreshold,
        [int]$EscalateThreshold,
        [int]$HardThreshold
    )

    if ($null -eq $InputTokens) {
        return [pscustomobject]@{
            Trigger = "inactive"
            Mode = "N/A"
            GuardState = "tắt"
            GuardApplied = $false
            SoftState = "chưa kích hoạt"
            Reason = "input_unavailable"
        }
    }

    if ($InputTokens -ge $HardThreshold) {
        return [pscustomobject]@{
            Trigger = "hard_active"
            Mode = "Aggressive"
            GuardState = "bật"
            GuardApplied = $true
            SoftState = "đã kích hoạt"
            Reason = ">= hard threshold"
        }
    }

    if ($InputTokens -ge $EscalateThreshold) {
        return [pscustomobject]@{
            Trigger = "soft_escalated"
            Mode = "Balanced"
            GuardState = "bật"
            GuardApplied = $true
            SoftState = "đã kích hoạt"
            Reason = ">= escalate threshold"
        }
    }

    if ($InputTokens -ge $SoftThreshold) {
        return [pscustomobject]@{
            Trigger = "soft_prepare"
            Mode = "Balanced"
            GuardState = "tắt"
            GuardApplied = $false
            SoftState = "đã kích hoạt"
            Reason = ">= soft threshold (prepare)"
        }
    }

    return [pscustomobject]@{
        Trigger = "inactive"
        Mode = "N/A"
        GuardState = "tắt"
        GuardApplied = $false
        SoftState = "chưa kích hoạt"
        Reason = "< soft threshold"
    }
}

function Merge-StatusLines {
    param(
        [string[]]$UsageLines = @(),
        [string[]]$AddonLines = @(),
        [bool]$SerenaUsed = $false,
        [bool]$GstackLiteUsed = $false
    )

    $merged = New-Object System.Collections.Generic.List[string]
    foreach ($line in @($UsageLines)) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $merged.Add($line)
        }
    }

    foreach ($line in @($AddonLines)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($SerenaUsed -and $line.StartsWith("Serena:")) {
            continue
        }
        if ($GstackLiteUsed -and $line.StartsWith("gstack-lite:")) {
            continue
        }
        $merged.Add($line)
    }

    return @($merged)
}

$recentFiles = @(Get-RecentSessionFiles -Root $CodexRoot -Limit $MaxRecentFiles)
$latestEvent = $null
foreach ($f in $recentFiles) {
    $candidate = Get-LatestTokenEventFromFile -Path $f.FullName -Tail $ScanTail
    if ($null -ne $candidate) {
        $latestEvent = $candidate
        break
    }
}

if ($null -eq $latestEvent) {
    $usage = $null
    $addonStatus = Get-AddonStatusFromRuntime -Root $CodexRoot
    if ($recentFiles.Count -gt 0 -and $null -ne $recentFiles[0]) {
        $usage = Get-RetrievalUsageFromFile -Path $recentFiles[0].FullName -Tail $UsageScanTail -MaxLibraries $MaxLibrariesPerSource
    }

    $status = New-ContextGuardStatusLine `
        -GuardContextState "tắt" `
        -Mode "N/A" `
        -ProxyInputTokens $null `
        -ProxyOutputTokens $null `
        -CachedInputTokens $null `
        -RetrievalLines $(Merge-StatusLines -UsageLines $(if ($null -ne $usage) { $usage.RetrievalLines } else { @() }) -AddonLines $addonStatus.AddonLines -SerenaUsed $(if ($null -ne $usage) { $usage.SerenaUsed } else { $false }) -GstackLiteUsed $(if ($null -ne $usage) { $usage.GstackLiteUsed } else { $false })) `
        -SoftTriggerState "chưa kích hoạt"

    [pscustomobject]@{
        Found = $false
        Reason = "token_count_not_found"
        Source = "codex_session_token_count"
        CodexRoot = $CodexRoot
        ScanTail = $ScanTail
        UsageScanTail = $UsageScanTail
        MaxRecentFiles = $MaxRecentFiles
        MaxLibrariesPerSource = $MaxLibrariesPerSource
        ProxyInputTokensEstimate = $null
        ProxyOutputTokensEstimate = $null
        CachedInputTokensEstimate = $null
        ThreadInputTokensEstimate = $null
        ThreadOutputTokensEstimate = $null
        Trigger = "inactive"
        Mode = "N/A"
        Applied = $false
        SerenaConfigured = $addonStatus.SerenaConfigured
        GstackLiteInstalled = $addonStatus.GstackLiteInstalled
        Context7Used = $(if ($null -ne $usage) { $usage.Context7Used } else { $false })
        ContextHubUsed = $(if ($null -ne $usage) { $usage.ContextHubUsed } else { $false })
        SerenaUsed = $(if ($null -ne $usage) { $usage.SerenaUsed } else { $false })
        GstackLiteUsed = $(if ($null -ne $usage) { $usage.GstackLiteUsed } else { $false })
        Context7Calls = $(if ($null -ne $usage) { $usage.Context7Calls } else { 0 })
        ContextHubCalls = $(if ($null -ne $usage) { $usage.ContextHubCalls } else { 0 })
        SerenaCalls = $(if ($null -ne $usage) { $usage.SerenaCalls } else { 0 })
        Context7Libraries = @($(if ($null -ne $usage) { $usage.Context7Libraries } else { @() }))
        ContextHubLibraries = @($(if ($null -ne $usage) { $usage.ContextHubLibraries } else { @() }))
        StatusFormatVersion = "v4"
        StatusLine = $status.GuardLine
        SkillGateLine = $status.SkillLine
        StatusLineWithSkills = $status.CombinedLine
    }
    exit 0
}

$decision = Resolve-GuardDecision `
    -InputTokens $latestEvent.LastInputTokens `
    -SoftThreshold $SoftThresholdTokens `
    -EscalateThreshold $EscalateThresholdTokens `
    -HardThreshold $HardThresholdTokens

$usage = Get-RetrievalUsageFromFile -Path $latestEvent.SessionFile -Tail $UsageScanTail -MaxLibraries $MaxLibrariesPerSource
$addonStatus = Get-AddonStatusFromRuntime -Root $CodexRoot

$status = New-ContextGuardStatusLine `
    -GuardContextState $decision.GuardState `
    -Mode $decision.Mode `
    -ProxyInputTokens $latestEvent.LastInputTokens `
    -ProxyOutputTokens $latestEvent.LastOutputTokens `
    -CachedInputTokens $latestEvent.LastCachedInputTokens `
    -RetrievalLines $(Merge-StatusLines -UsageLines $usage.RetrievalLines -AddonLines $addonStatus.AddonLines -SerenaUsed $usage.SerenaUsed -GstackLiteUsed $usage.GstackLiteUsed) `
    -SoftTriggerState $decision.SoftState

[pscustomobject]@{
    Found = $true
    Reason = "ok"
    Source = "codex_session_token_count"
    SessionFile = $latestEvent.SessionFile
    TimestampUtc = $latestEvent.Timestamp
    Trigger = $decision.Trigger
    Mode = $decision.Mode
    Applied = $decision.GuardApplied
    DecisionReason = $decision.Reason
    ProxyInputTokensEstimate = $latestEvent.LastInputTokens
    ProxyOutputTokensEstimate = $latestEvent.LastOutputTokens
    CachedInputTokensEstimate = $latestEvent.LastCachedInputTokens
    ThreadInputTokensEstimate = $latestEvent.LastInputTokens
    ThreadOutputTokensEstimate = $latestEvent.LastOutputTokens
    ModelInputTokens = $latestEvent.LastInputTokens
    ModelOutputTokens = $latestEvent.LastOutputTokens
    TotalInputTokens = $latestEvent.TotalInputTokens
    TotalOutputTokens = $latestEvent.TotalOutputTokens
    ModelContextWindow = $latestEvent.ModelContextWindow
    CodexRoot = $CodexRoot
    ScanTail = $ScanTail
    UsageScanTail = $UsageScanTail
    MaxRecentFiles = $MaxRecentFiles
    MaxLibrariesPerSource = $MaxLibrariesPerSource
    SoftThresholdTokens = $SoftThresholdTokens
    EscalateThresholdTokens = $EscalateThresholdTokens
    HardThresholdTokens = $HardThresholdTokens
    IsStale = $false
    ProbeAttempted = $false
    ProbeSucceeded = $false
    ProbeError = $null
    SerenaConfigured = $addonStatus.SerenaConfigured
    GstackLiteInstalled = $addonStatus.GstackLiteInstalled
    Context7Used = $usage.Context7Used
    ContextHubUsed = $usage.ContextHubUsed
    SerenaUsed = $usage.SerenaUsed
    GstackLiteUsed = $usage.GstackLiteUsed
    Context7Calls = $usage.Context7Calls
    ContextHubCalls = $usage.ContextHubCalls
    SerenaCalls = $usage.SerenaCalls
    Context7Libraries = @($usage.Context7Libraries)
    ContextHubLibraries = @($usage.ContextHubLibraries)
    StatusFormatVersion = "v4"
    StatusLine = $status.GuardLine
    SkillGateLine = $status.SkillLine
    StatusLineWithSkills = $status.CombinedLine
}
