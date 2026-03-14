param(
    [string]$CodexRoot = "C:\Users\ngath\.codex",
    [int]$ScanTail = 600,
    [int]$MaxRecentFiles = 60,
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

$recentFiles = Get-RecentSessionFiles -Root $CodexRoot -Limit $MaxRecentFiles
$latestEvent = $null
foreach ($f in $recentFiles) {
    $candidate = Get-LatestTokenEventFromFile -Path $f.FullName -Tail $ScanTail
    if ($null -ne $candidate) {
        $latestEvent = $candidate
        break
    }
}

if ($null -eq $latestEvent) {
    $status = New-ContextGuardStatusLine `
        -GuardContextState "tắt" `
        -Mode "N/A" `
        -ProxyInputTokens $null `
        -ProxyOutputTokens $null `
        -SoftTriggerState "chưa kích hoạt"

    [pscustomobject]@{
        Found = $false
        Reason = "token_count_not_found"
        Source = "codex_session_token_count"
        CodexRoot = $CodexRoot
        ScanTail = $ScanTail
        MaxRecentFiles = $MaxRecentFiles
        ProxyInputTokensEstimate = $null
        ProxyOutputTokensEstimate = $null
        ThreadInputTokensEstimate = $null
        ThreadOutputTokensEstimate = $null
        Trigger = "inactive"
        Mode = "N/A"
        Applied = $false
        StatusFormatVersion = "v3"
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

$status = New-ContextGuardStatusLine `
    -GuardContextState $decision.GuardState `
    -Mode $decision.Mode `
    -ProxyInputTokens $latestEvent.LastInputTokens `
    -ProxyOutputTokens $latestEvent.LastOutputTokens `
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
    ThreadInputTokensEstimate = $latestEvent.LastInputTokens
    ThreadOutputTokensEstimate = $latestEvent.LastOutputTokens
    ModelInputTokens = $latestEvent.LastInputTokens
    ModelOutputTokens = $latestEvent.LastOutputTokens
    TotalInputTokens = $latestEvent.TotalInputTokens
    TotalOutputTokens = $latestEvent.TotalOutputTokens
    ModelContextWindow = $latestEvent.ModelContextWindow
    CodexRoot = $CodexRoot
    ScanTail = $ScanTail
    MaxRecentFiles = $MaxRecentFiles
    SoftThresholdTokens = $SoftThresholdTokens
    EscalateThresholdTokens = $EscalateThresholdTokens
    HardThresholdTokens = $HardThresholdTokens
    IsStale = $false
    ProbeAttempted = $false
    ProbeSucceeded = $false
    ProbeError = $null
    StatusFormatVersion = "v3"
    StatusLine = $status.GuardLine
    SkillGateLine = $status.SkillLine
    StatusLineWithSkills = $status.CombinedLine
}
