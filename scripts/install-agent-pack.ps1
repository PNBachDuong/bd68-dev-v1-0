param(
    [ValidateSet("", "opencode", "codex")]
    [string]$Target = "",

    [ValidateSet("global")]
    [string]$Scope = "global",

    [string]$CodexRootPath = "",

    [string]$OpenCodeRootPath = "",

    [bool]$InstallMcpBinaries = $true,

    [bool]$FailOnMcpInstallError = $true,

    [switch]$InitProject = $false,

    [string]$ProjectName = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($CodexRootPath)) {
    $CodexRootPath = Join-Path $HOME ".codex"
}
if ([string]::IsNullOrWhiteSpace($OpenCodeRootPath)) {
    $OpenCodeRootPath = Join-Path $HOME ".config\opencode"
}
if ([string]::IsNullOrWhiteSpace($Target) -and -not $InitProject) {
    throw "Target is required unless -InitProject is set."
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
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
    if (Test-Path -LiteralPath $Path) {
        $existing = Get-Content -LiteralPath $Path -Raw
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

    Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8
}

function Copy-PackTree {
    param(
        [string]$Source,
        [string]$Destination
    )

    Ensure-Directory -Path $Destination
    $null = & robocopy $Source $Destination /E /XD .git node_modules .venv scripts\artifacts /XF *.pyc
    $code = $LASTEXITCODE
    if ($code -gt 7) {
        throw "robocopy failed with exit code $code."
    }
    return $code
}

function Find-CommandPath {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
            return $cmd.Source
        }
    }
    return ""
}

function Invoke-ExternalCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$Label
    )

    $output = & $FilePath @Arguments 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        $message = ($output | Out-String).Trim()
        throw "$Label failed with exit code $code. $message"
    }
    return ($output | Out-String).Trim()
}

function Ensure-UserPathContains {
    param([string]$Directory)

    $resolved = [System.IO.Path]::GetFullPath($Directory).TrimEnd('\')
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ([string]::IsNullOrWhiteSpace($userPath)) {
        [Environment]::SetEnvironmentVariable("Path", $resolved, "User")
        $env:Path = "$resolved;$env:Path"
        return $true
    }

    $parts = @(
        $userPath -split ';' |
        ForEach-Object { $_.Trim().TrimEnd('\') } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    if ($parts -contains $resolved) {
        if (-not (($env:Path -split ';') -contains $resolved)) {
            $env:Path = "$resolved;$env:Path"
        }
        return $false
    }

    $newUserPath = ($parts + $resolved) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    $env:Path = "$resolved;$env:Path"
    return $true
}

function Get-McpTableBlocks {
    param([string]$Text)

    $blocks = [ordered]@{}
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $blocks
    }

    $pattern = '(?ms)^\[(mcp_servers(?:\.[^\]]+)*)\]\s*\r?\n.*?(?=^\[|\z)'
    $matches = [regex]::Matches($Text, $pattern)
    foreach ($match in $matches) {
        $tableName = $match.Groups[1].Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($tableName)) {
            $blocks[$tableName] = $match.Value.Trim()
        }
    }

    return $blocks
}

function Merge-McpTableBlocks {
    param(
        $SourceBlocks,
        $RuntimeBlocks
    )

    $merged = [ordered]@{}
    foreach ($entry in $SourceBlocks.GetEnumerator()) {
        $merged[$entry.Key] = $entry.Value
    }
    foreach ($entry in $RuntimeBlocks.GetEnumerator()) {
        $merged[$entry.Key] = $entry.Value
    }

    return $merged
}

function Convert-McpTableBlocksToText {
    param($Blocks)

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $Blocks.GetEnumerator()) {
        $parts.Add(($entry.Value).Trim())
    }

    return ($parts -join "`r`n`r`n").Trim()
}

function Remove-McpSyncContent {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $withoutManaged = [regex]::Replace($Text, '(?ms)^# BD68 MCP SYNC START\r?\n.*?^# BD68 MCP SYNC END\r?\n?', '')
    $withoutTables = [regex]::Replace($withoutManaged, '(?ms)^\[(mcp_servers(?:\.[^\]]+)*)\]\s*\r?\n.*?(?=^\[|\z)', '')
    $normalized = [regex]::Replace($withoutTables.Trim(), '(\r?\n){3,}', "`r`n`r`n")

    return $normalized.Trim()
}

function Set-McpSyncBlock {
    param(
        [string]$Path,
        [string]$Block
    )

    $existing = ""
    if (Test-Path -LiteralPath $Path) {
        $existing = Get-Content -LiteralPath $Path -Raw
    }

    $base = Remove-McpSyncContent -Text $existing
    if ([string]::IsNullOrWhiteSpace($Block)) {
        if ([string]::IsNullOrWhiteSpace($base)) {
            Set-Content -LiteralPath $Path -Value "" -Encoding UTF8
        } else {
            Set-Content -LiteralPath $Path -Value ($base.TrimEnd() + "`r`n") -Encoding UTF8
        }
        return
    }

    $wrapped = "# BD68 MCP SYNC START`r`n$Block`r`n# BD68 MCP SYNC END"
    if ([string]::IsNullOrWhiteSpace($base)) {
        $updated = $wrapped + "`r`n"
    } else {
        $updated = $base.TrimEnd() + "`r`n`r`n" + $wrapped + "`r`n"
    }

    Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8
}

function New-ChubMcpBlock {
    param([string]$CommandPath)

    return @"
[mcp_servers.chub]
command = '$CommandPath'
"@.Trim()
}

function Normalize-SerenaMcpBlock {
    param([string]$Block)

    if ([string]::IsNullOrWhiteSpace($Block)) {
        return $Block
    }

    $defaultRef = "git+https://github.com/oraios/serena@6d6f55308f99c6e857ec20f194a8c1766c930f17"
    $gitRef = $defaultRef
    $refMatch = [regex]::Match($Block, 'git\+https://github\.com/oraios/serena[^"]*')
    if ($refMatch.Success) {
        $gitRef = $refMatch.Value
    }

    $hasDashboardFlags = ($Block -match '--enable-web-dashboard') -or ($Block -match '--open-web-dashboard')
    if ($hasDashboardFlags) {
        return @"
[mcp_servers.serena]
command = "uvx"
args = ["--from", "$gitRef", "serena", "start-mcp-server", "--context", "codex", "--enable-web-dashboard", "true", "--open-web-dashboard", "false"]
"@.Trim()
    }

    return @"
[mcp_servers.serena]
command = "uvx"
args = ["--from", "$gitRef", "serena", "start-mcp-server", "--context", "codex"]
"@.Trim()
}

function Normalize-McpTableBlocks {
    param($Blocks)

    if ($Blocks.Keys -contains "mcp_servers.serena") {
        $Blocks["mcp_servers.serena"] = Normalize-SerenaMcpBlock -Block $Blocks["mcp_servers.serena"]
    }

    return $Blocks
}

function Install-McpBinariesForCodex {
    $result = [ordered]@{
        ChubPath = ""
        InstalledPackages = @()
    }

    $npmPath = Find-CommandPath @("npm", "npm.cmd")
    if ([string]::IsNullOrWhiteSpace($npmPath)) {
        throw "npm is required to install chub MCP binaries. Install Node.js first."
    }

    $chubPath = Find-CommandPath @("chub-mcp", "chub-mcp.cmd", "chub")
    if ([string]::IsNullOrWhiteSpace($chubPath)) {
        Invoke-ExternalCommand -FilePath $npmPath -Arguments @("install", "-g", "@aisuite/chub") -Label "Install @aisuite/chub" | Out-Null
        $chubPath = Find-CommandPath @("chub-mcp", "chub-mcp.cmd", "chub")
        if ([string]::IsNullOrWhiteSpace($chubPath)) {
            throw "@aisuite/chub install finished but executable was not found in PATH."
        }
        $result.InstalledPackages += "@aisuite/chub"
    }
    $result.ChubPath = $chubPath

    return [pscustomobject]$result
}

if ($Target -eq "opencode") {
    if ($Scope -ne "global") {
        throw "Only global scope is currently supported for opencode."
    }

    $configRoot = $OpenCodeRootPath
    $installRoot = Join-Path $configRoot "bd_dev_kit"
    $refRoot = Join-Path $installRoot "references"
    $agentsPath = Join-Path $configRoot "AGENTS.md"

    Ensure-Directory -Path $configRoot
    Ensure-Directory -Path $installRoot
    Ensure-Directory -Path $refRoot

    Copy-Item (Join-Path $repoRoot "core\BD68_PROFILE.md") (Join-Path $installRoot "BD68_PROFILE.md") -Force
    Copy-Item (Join-Path $repoRoot "references\SOURCE_INDEX.md") (Join-Path $refRoot "SOURCE_INDEX.md") -Force
    Copy-Item (Join-Path $repoRoot "references\impeccable.md") (Join-Path $refRoot "impeccable.md") -Force
    Copy-Item (Join-Path $repoRoot "references\concise-planning.md") (Join-Path $refRoot "concise-planning.md") -Force
    Copy-Item (Join-Path $repoRoot "references\antigravity.md") (Join-Path $refRoot "antigravity.md") -Force
    Copy-Item (Join-Path $repoRoot "adapters\opencode\MCP_SETUP.md") (Join-Path $installRoot "MCP_SETUP.md") -Force

    $singleFile = Get-Content (Join-Path $repoRoot "adapters\opencode\AGENTS.singlefile.template") -Raw
    Update-MarkedBlock -Path $agentsPath -StartMarker "<!-- BD68 DEV V1.1 START -->" -EndMarker "<!-- BD68 DEV V1.1 END -->" -Block $singleFile.TrimEnd()

    Write-Host "BD68 Dev v1.1 installed for OpenCode (single-file mode)."
    Write-Host "AGENTS: $agentsPath"
    Write-Host "Profile archive: $(Join-Path $installRoot 'BD68_PROFILE.md')"
    Write-Host "References archive: $refRoot"
    Write-Host "Pack source: core/ + adapters/opencode/"
    Write-Host "Open a new OpenCode session to load the updated profile."
}

if ($Target -eq "codex") {
    if ($Scope -ne "global") {
        throw "Only global scope is currently supported for codex."
    }

    $codexRoot = $CodexRootPath
    $skillsRoot = Join-Path $codexRoot "skills"
    $installRoot = Join-Path $skillsRoot "bd_dev_kit"
    $agentsPath = Join-Path $codexRoot "AGENTS.md"
    $runtimeConfigPath = Join-Path $codexRoot "config.toml"
    $mcpSnapshotPath = Join-Path $repoRoot "templates\codex.mcp_servers.toml"

    $snapshotDir = Split-Path -Parent $mcpSnapshotPath
    Ensure-Directory -Path $snapshotDir

    $snapshotText = ""
    if (Test-Path -LiteralPath $mcpSnapshotPath) {
        $snapshotText = Get-Content -LiteralPath $mcpSnapshotPath -Raw
    }
    $runtimeConfigText = ""
    if (Test-Path -LiteralPath $runtimeConfigPath) {
        $runtimeConfigText = Get-Content -LiteralPath $runtimeConfigPath -Raw
    }

    $snapshotBlocks = Get-McpTableBlocks -Text $snapshotText
    $runtimeBlocks = Get-McpTableBlocks -Text $runtimeConfigText
    $mergedMcpBlocks = Merge-McpTableBlocks -SourceBlocks $snapshotBlocks -RuntimeBlocks $runtimeBlocks
    $mergedMcpBlocks = Normalize-McpTableBlocks -Blocks $mergedMcpBlocks

    Ensure-Directory -Path $codexRoot
    Ensure-Directory -Path $skillsRoot
    $mergedMcpText = Convert-McpTableBlocksToText -Blocks $mergedMcpBlocks
    Set-Content -LiteralPath $mcpSnapshotPath -Value ($mergedMcpText + "`r`n") -Encoding UTF8
    Set-McpSyncBlock -Path $runtimeConfigPath -Block $mergedMcpText

    $copyCode = Copy-PackTree -Source $repoRoot -Destination $installRoot
    $gstackLiteSource = Join-Path $repoRoot "skills\gstack-lite"
    $gstackLiteInstallRoot = Join-Path $skillsRoot "gstack-lite"
    $gstackLiteCopyCode = -1
    if (Test-Path -LiteralPath $gstackLiteSource) {
        $gstackLiteCopyCode = Copy-PackTree -Source $gstackLiteSource -Destination $gstackLiteInstallRoot
    } else {
        Write-Warning "gstack-lite skill source not found at $gstackLiteSource"
    }

    $bootstrapTemplatePath = Join-Path $repoRoot "adapters\codex\AGENTS.bootstrap.template"
    if (Test-Path -LiteralPath $bootstrapTemplatePath) {
        $bootstrapBlock = Get-Content -LiteralPath $bootstrapTemplatePath -Raw
        Update-MarkedBlock -Path $agentsPath -StartMarker "<!-- BD68 DEV V1.1 CODEX START -->" -EndMarker "<!-- BD68 DEV V1.1 CODEX END -->" -Block $bootstrapBlock.TrimEnd()
    }

    # ── Sync Skills: bd_dev_kit/skills/ → ~/.codex/skills/ ────────
    $skillsSrc = Join-Path $PSScriptRoot "..\skills"
    $skillsDst = $skillsRoot

    if (Test-Path $skillsSrc) {
        $skillFolders = Get-ChildItem $skillsSrc -Directory
        foreach ($skill in $skillFolders) {
            $dst = Join-Path $skillsDst $skill.Name
            if (-not (Test-Path $dst)) {
                New-Item -ItemType Directory -Path $dst | Out-Null
            }
            # Sync toàn bộ folder (SKILL.md + subdirs)
            Copy-Item -Path (Join-Path $skill.FullName "*") -Destination $dst -Recurse -Force
            Write-Host "[BD68] Synced skill: $($skill.Name)" -ForegroundColor Green
        }
        Write-Host "[BD68] Skills sync complete ($($skillFolders.Count) skills)" -ForegroundColor Green
    } else {
        Write-Host "[BD68] WARNING: bd_dev_kit/skills/ not found — skills not synced" -ForegroundColor Yellow
    }

    # ── memoryai MCP — DISABLED (replaced by local memory layer in v2.0) ──
    # Kept for reference. Remove entirely in v3.0.
    # NOTE: v1.4 no longer contains an active memoryai install/config block in this script.
    # ── end disabled block ────────────────────────────────────────────────

    # ── Memory Layer Setup ────────────────────────────────────────
    $memoriesDir = Join-Path $codexRoot "memories"
    if (-not (Test-Path $memoriesDir)) {
        New-Item -ItemType Directory -Path $memoriesDir | Out-Null
        Write-Host "[BD68] Created .codex/memories/ directory" -ForegroundColor Green
    }

    $memFile = Join-Path $memoriesDir "MEMORY.md"
    if (-not (Test-Path $memFile)) {
        $memContent = "# Agent Memory`n<!-- Budget: 2200 chars max (~800 tokens). When full, consolidate or replace oldest entries. -->`n<!-- Format: [YYYY-MM-DD] category: note -->`n<!-- Agent manages this file directly -->`n"
        Set-Content -Path $memFile -Value $memContent -Encoding UTF8
        Write-Host "[BD68] MEMORY.md created" -ForegroundColor Green
    }

    $userFile = Join-Path $memoriesDir "USER.md"
    if (-not (Test-Path $userFile)) {
        $userContent = "# User Profile`n<!-- Budget: 1375 chars max (~500 tokens). Keep focused on stable preferences. -->`n<!-- Categories: workflow | preferences | communication | projects | constraints -->`n"
        Set-Content -Path $userFile -Value $userContent -Encoding UTF8
        Write-Host "[BD68] USER.md created (fill in your profile)" -ForegroundColor Cyan
    }
    Write-Host "[BD68] Memory layer ready at $memoriesDir" -ForegroundColor Green

    $mcpInstallResult = $null
    if ($InstallMcpBinaries) {
        try {
            $mcpInstallResult = Install-McpBinariesForCodex
            if (-not [string]::IsNullOrWhiteSpace($mcpInstallResult.ChubPath)) {
                $mergedMcpBlocks["mcp_servers.chub"] = New-ChubMcpBlock -CommandPath $mcpInstallResult.ChubPath
            }
        } catch {
            if ($FailOnMcpInstallError) {
                throw
            }
            Write-Warning "MCP binary installation warning: $($_.Exception.Message)"
        }
    }

    $mergedMcpBlocks = Normalize-McpTableBlocks -Blocks $mergedMcpBlocks
    $mergedMcpText = Convert-McpTableBlocksToText -Blocks $mergedMcpBlocks
    Set-Content -LiteralPath $mcpSnapshotPath -Value ($mergedMcpText + "`r`n") -Encoding UTF8
    Set-McpSyncBlock -Path $runtimeConfigPath -Block $mergedMcpText
    $installedSnapshotPath = Join-Path $installRoot "templates\codex.mcp_servers.toml"
    Ensure-Directory -Path (Split-Path -Parent $installedSnapshotPath)
    Set-Content -LiteralPath $installedSnapshotPath -Value ($mergedMcpText + "`r`n") -Encoding UTF8

    Write-Host "BD68 Dev v1.1 installed for Codex."
    Write-Host "Skill path (bd_dev_kit): $installRoot"
    if ($gstackLiteCopyCode -ge 0) {
        Write-Host "Skill path (gstack-lite): $gstackLiteInstallRoot"
    } else {
        Write-Host "Skill path (gstack-lite): skipped (source missing)"
    }
    Write-Host "AGENTS bootstrap path: $agentsPath"
    Write-Host "Codex config path: $runtimeConfigPath"
    Write-Host "MCP snapshot path: $mcpSnapshotPath"
    Write-Host "MCP snapshot tables: $($mergedMcpBlocks.Count)"
    Write-Host "Pack sync robocopy exit: $copyCode"
    if ($gstackLiteCopyCode -ge 0) {
        Write-Host "gstack-lite sync robocopy exit: $gstackLiteCopyCode"
    }
    if ($InstallMcpBinaries) {
        if ($null -ne $mcpInstallResult) {
            Write-Host "MCP binary install: completed"
            Write-Host "MCP chub path: $($mcpInstallResult.ChubPath)"
            if ($mcpInstallResult.InstalledPackages.Count -gt 0) {
                Write-Host "MCP npm packages installed: $($mcpInstallResult.InstalledPackages -join ', ')"
            } else {
                Write-Host "MCP npm packages installed: none (already present)"
            }
        } else {
            Write-Host "MCP binary install: warning (continued due FailOnMcpInstallError=false)"
        }
    } else {
        Write-Host "MCP binary install: skipped by flag"
    }
    Write-Host "Open a new Codex thread (or restart app) to ensure runtime picks up the updated profile."
}

# -- Init Project Overlay --------------------------------------
if ($InitProject) {
    $overlayDir = Join-Path (Get-Location) ".bd68"
    $templateSrc = Join-Path $PSScriptRoot "..\templates\PROJECT.md"

    if (-not (Test-Path $overlayDir)) {
        New-Item -ItemType Directory -Path $overlayDir | Out-Null
        Write-Host "[BD68] Created .bd68/ overlay directory" -ForegroundColor Green
    } else {
        Write-Host "[BD68] .bd68/ already exists - skipping mkdir" -ForegroundColor Yellow
    }

    $destFile = Join-Path $overlayDir "PROJECT.md"
    if (-not (Test-Path $destFile)) {
        Copy-Item $templateSrc $destFile
        # Inject project name if provided
        if ($ProjectName -ne "") {
            (Get-Content $destFile) -replace 'project: ""', "project: `"$ProjectName`"" |
                Set-Content $destFile
        }
        # Inject today's date
        $today = Get-Date -Format "yyyy-MM-dd"
        (Get-Content $destFile) -replace 'last_updated: ""', "last_updated: `"$today`"" |
            Set-Content $destFile
        Write-Host "[BD68] PROJECT.md created at $destFile" -ForegroundColor Green
        Write-Host "[BD68] Open .bd68/PROJECT.md and fill in your stack + decisions" -ForegroundColor Cyan
    } else {
        Write-Host "[BD68] PROJECT.md already exists - skipping (use -Force to overwrite)" -ForegroundColor Yellow
    }

    # Copy gitignore template as advisory
    $gitignoreSrc = Join-Path $PSScriptRoot "..\templates\.gitignore.project"
    $gitignoreDest = Join-Path $overlayDir ".gitignore.template"
    if (-not (Test-Path $gitignoreDest)) {
        Copy-Item $gitignoreSrc $gitignoreDest
        Write-Host "[BD68] .gitignore.template copied - see file for git tracking options" -ForegroundColor Cyan
    }
}



