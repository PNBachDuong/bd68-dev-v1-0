param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$OutputPath = "",

    [ValidateSet("Auto", "Safe", "Balanced", "Aggressive")]
    [string]$Mode = "Auto",

    [switch]$ApplyAtSoftThreshold,

    [int]$SoftThresholdTokens = 200000,

    [int]$EscalateThresholdTokens = 240000,

    [int]$HardThresholdTokens = 250000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($SoftThresholdTokens -gt $EscalateThresholdTokens -or $EscalateThresholdTokens -gt $HardThresholdTokens) {
    throw "Invalid thresholds: require Soft <= Escalate <= Hard."
}

function Get-Profile {
    param([string]$Name)

    switch ($Name) {
        "Safe" {
            return @{
                KeepLastDialogMessages = 200
                ToolMaxChars = 3000
                DropAltRepresentation = $false
            }
        }
        "Balanced" {
            return @{
                KeepLastDialogMessages = 120
                ToolMaxChars = 1200
                DropAltRepresentation = $true
            }
        }
        "Aggressive" {
            return @{
                KeepLastDialogMessages = 80
                ToolMaxChars = 600
                DropAltRepresentation = $true
            }
        }
        default {
            throw "Unsupported mode: $Name"
        }
    }
}

function Resolve-AutoDecision {
    param(
        [int]$EstimatedTokens,
        [int]$SoftThreshold,
        [int]$EscalateThreshold,
        [int]$HardThreshold,
        [bool]$ApplyAtSoft
    )

    if ($EstimatedTokens -ge $HardThreshold) {
        return [pscustomobject]@{
            TriggerState = "hard_active"
            ModeSelected = "Aggressive"
            GuardApplied = $true
            Reason = "Estimated tokens >= hard threshold."
        }
    }

    if ($EstimatedTokens -ge $EscalateThreshold) {
        return [pscustomobject]@{
            TriggerState = "soft_escalated"
            ModeSelected = "Balanced"
            GuardApplied = $true
            Reason = "Estimated tokens >= escalate threshold."
        }
    }

    if ($EstimatedTokens -ge $SoftThreshold) {
        if ($ApplyAtSoft) {
            return [pscustomobject]@{
                TriggerState = "soft_prepare"
                ModeSelected = "Balanced"
                GuardApplied = $true
                Reason = "Estimated tokens >= soft threshold and ApplyAtSoftThreshold is enabled."
            }
        }
        return [pscustomobject]@{
            TriggerState = "soft_prepare"
            ModeSelected = "N/A"
            GuardApplied = $false
            Reason = "Estimated tokens >= soft threshold; prepare balanced guard for next heavy turn."
        }
    }

    return [pscustomobject]@{
        TriggerState = "inactive"
        ModeSelected = "N/A"
        GuardApplied = $false
        Reason = "Estimated tokens below soft threshold."
    }
}

function Get-DefaultOutputPath {
    param(
        [string]$InputFilePath,
        [string]$AppliedMode
    )

    $dir = Split-Path -Parent $InputFilePath
    $base = [System.IO.Path]::GetFileNameWithoutExtension($InputFilePath)
    $safeMode = $AppliedMode.ToLowerInvariant()
    return (Join-Path $dir ($base + ".guarded." + $safeMode + ".json"))
}

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$raw = Get-Content -LiteralPath $resolvedInput -Raw
$preflightChars = $raw.Length
$preflightTokens = [int][math]::Round($preflightChars / 4)

$decision = $null
if ($Mode -eq "Auto") {
    $decision = Resolve-AutoDecision `
        -EstimatedTokens $preflightTokens `
        -SoftThreshold $SoftThresholdTokens `
        -EscalateThreshold $EscalateThresholdTokens `
        -HardThreshold $HardThresholdTokens `
        -ApplyAtSoft $ApplyAtSoftThreshold.IsPresent
} else {
    $decision = [pscustomobject]@{
        TriggerState = "manual_override"
        ModeSelected = $Mode
        GuardApplied = $true
        Reason = "Manual mode override."
    }
}

$guardSummary = $null
$resolvedOutput = ""
$postTokens = $preflightTokens
$reductionPct = 0.0

if ($decision.GuardApplied) {
    $profile = Get-Profile -Name $decision.ModeSelected

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Get-DefaultOutputPath -InputFilePath $resolvedInput -AppliedMode $decision.ModeSelected
    }

    $guardScript = Join-Path $PSScriptRoot "codex_payload_guard.ps1"
    $guardSummary = & $guardScript `
        -InputPath $resolvedInput `
        -OutputPath $OutputPath `
        -KeepLastDialogMessages $profile.KeepLastDialogMessages `
        -ToolMaxChars $profile.ToolMaxChars `
        -DropAltRepresentation $profile.DropAltRepresentation

    $resolvedOutput = (Resolve-Path -LiteralPath $OutputPath).Path
    $postTokens = [int][math]::Round(([int]$guardSummary.PayloadJsonCharsAfter) / 4)
    $reductionPct = [double]$guardSummary.PayloadReductionPct
} elseif (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outDir = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }
    Copy-Item -LiteralPath $resolvedInput -Destination $OutputPath -Force
    $resolvedOutput = (Resolve-Path -LiteralPath $OutputPath).Path
}

$softTriggerStatus = if ($preflightTokens -ge $SoftThresholdTokens) { "đã kích hoạt" } else { "chưa kích hoạt" }
$guardStatus = if ($decision.GuardApplied) { "bật" } else { "tắt" }
$modeLabel = if ($decision.GuardApplied) { $decision.ModeSelected } else { "N/A" }

$statusLine = "Preflight Guard: $guardStatus | mode: $modeLabel | Preflight: ~$preflightTokens tokens | trigger mềm: $softTriggerStatus | đường chạy: manual"

[pscustomobject]@{
    InputPath = $resolvedInput
    OutputPath = $resolvedOutput
    RequestedMode = $Mode
    ModeSelected = $decision.ModeSelected
    GuardApplied = [bool]$decision.GuardApplied
    TriggerState = $decision.TriggerState
    DecisionReason = $decision.Reason
    PreflightPayloadChars = $preflightChars
    PreflightPayloadTokensEstimate = $preflightTokens
    PostPayloadTokensEstimate = $postTokens
    PayloadReductionPct = [math]::Round($reductionPct, 2)
    SoftThresholdTokens = $SoftThresholdTokens
    EscalateThresholdTokens = $EscalateThresholdTokens
    HardThresholdTokens = $HardThresholdTokens
    StatusLine = $statusLine
    GuardSummary = $guardSummary
}
