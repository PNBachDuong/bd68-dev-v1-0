param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("opencode")]
    [string]$Target,

    [ValidateSet("global")]
    [string]$Scope = "global"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Update-MarkedBlock {
    param(
        [string]$Path,
        [string]$StartMarker,
        [string]$EndMarker,
        [string]$Block
    )

    $existing = ""
    if (Test-Path $Path) {
        $existing = Get-Content $Path -Raw
    }

    $wrapped = "$StartMarker`r`n$Block`r`n$EndMarker"
    $pattern = "(?ms)" + [regex]::Escape($StartMarker) + ".*?" + [regex]::Escape($EndMarker)

    if ($existing -match $pattern) {
        $updated = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $wrapped }, 1)
    } elseif ([string]::IsNullOrWhiteSpace($existing)) {
        $updated = $wrapped + "`r`n"
    } else {
        $updated = $existing.TrimEnd() + "`r`n`r`n" + $wrapped + "`r`n"
    }

    Set-Content $Path $updated -Encoding UTF8
}

if ($Target -eq "opencode") {
    if ($Scope -ne "global") {
        throw "Only global scope is currently supported for opencode."
    }

    $configRoot = Join-Path $HOME '.config\opencode'
    $installRoot = Join-Path $configRoot 'bd68-dev-v1-0'
    $refRoot = Join-Path $installRoot 'references'
    $agentsPath = Join-Path $configRoot 'AGENTS.md'

    Ensure-Directory $configRoot
    Ensure-Directory $installRoot
    Ensure-Directory $refRoot

    Copy-Item (Join-Path $repoRoot 'core\BD68_PROFILE.md') (Join-Path $installRoot 'BD68_PROFILE.md') -Force
    Copy-Item (Join-Path $repoRoot 'references\SOURCE_INDEX.md') (Join-Path $refRoot 'SOURCE_INDEX.md') -Force
    Copy-Item (Join-Path $repoRoot 'references\impeccable.md') (Join-Path $refRoot 'impeccable.md') -Force
    Copy-Item (Join-Path $repoRoot 'references\concise-planning.md') (Join-Path $refRoot 'concise-planning.md') -Force
    Copy-Item (Join-Path $repoRoot 'references\antigravity.md') (Join-Path $refRoot 'antigravity.md') -Force
    Copy-Item (Join-Path $repoRoot 'adapters\opencode\MCP_SETUP.md') (Join-Path $installRoot 'MCP_SETUP.md') -Force

    $singleFile = Get-Content (Join-Path $repoRoot 'adapters\opencode\AGENTS.singlefile.template') -Raw
    Update-MarkedBlock -Path $agentsPath -StartMarker '<!-- BD68 DEV V1.0 START -->' -EndMarker '<!-- BD68 DEV V1.0 END -->' -Block $singleFile.TrimEnd()

    Write-Host "BD68 Dev v1.0 installed for OpenCode (single-file mode)."
    Write-Host "AGENTS: $agentsPath"
    Write-Host "Profile archive: $(Join-Path $installRoot 'BD68_PROFILE.md')"
    Write-Host "References archive: $refRoot"
    Write-Host "Pack source: core/ + adapters/opencode/"
    Write-Host "Open a new OpenCode session to load the updated profile."
}



