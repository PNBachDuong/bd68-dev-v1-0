param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("opencode", "codex")]
    [string]$Target,

    [ValidateSet("global")]
    [string]$Scope = "global",

    [string]$CodexRootPath = "",

    [string]$OpenCodeRootPath = "",

    [bool]$EnableProxy = $true,

    [bool]$StartProxyNow = $true,

    [bool]$RegisterProxyStartup = $true,

    [bool]$InstallMcpBinaries = $true,

    [bool]$FailOnMcpInstallError = $true,

    [string]$ProxyBaseUrl = "http://127.0.0.1:8787"
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

function Set-LlmgateBaseUrl {
    param(
        [string]$ConfigPath,
        [string]$BaseUrl
    )

    $configExisted = Test-Path -LiteralPath $ConfigPath
    $backupPath = ""
    $text = ""
    if ($configExisted) {
        $backupPath = "$ConfigPath.bd68-v1.1.bak"
        Copy-Item -LiteralPath $ConfigPath -Destination $backupPath -Force
        $text = Get-Content -LiteralPath $ConfigPath -Raw
    }

    if ([string]::IsNullOrWhiteSpace($text)) {
        $newText = "[model_providers.llmgate]`r`nbase_url = `"$BaseUrl`"`r`n"
        Set-Content -LiteralPath $ConfigPath -Value $newText -Encoding UTF8
        return [pscustomobject]@{
            ConfigPath = $ConfigPath
            BackupPath = $backupPath
            OldBaseUrl = "(new file)"
            NewBaseUrl = $BaseUrl
            ConfigCreated = (-not $configExisted)
            AddedLlmgateSection = $true
        }
    }

    $pattern = '(\[model_providers\.llmgate\][^\[]*?base_url\s*=\s*")([^"]*)(")'
    $m = [regex]::Match($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $oldBase = ""
    $addedSection = $false
    $newText = $text

    if ($m.Success) {
        $oldBase = $m.Groups[2].Value
        $start = $m.Groups[2].Index
        $length = $m.Groups[2].Length
        $newText = $text.Remove($start, $length).Insert($start, $BaseUrl)
    } else {
        $sectionPattern = '(?m)^\[model_providers\.llmgate\]\s*$'
        $sectionMatch = [regex]::Match($text, $sectionPattern)
        if ($sectionMatch.Success) {
            $oldBase = "(missing)"
            $insertAt = $sectionMatch.Index + $sectionMatch.Length
            $insertText = "`r`nbase_url = `"$BaseUrl`"`r`n"
            $newText = $text.Insert($insertAt, $insertText)
        } else {
            $oldBase = "(section missing)"
            $addedSection = $true
            $newText = $text.TrimEnd() + "`r`n`r`n[model_providers.llmgate]`r`nbase_url = `"$BaseUrl`"`r`n"
        }
    }

    Set-Content -LiteralPath $ConfigPath -Value $newText -Encoding UTF8

    return [pscustomobject]@{
        ConfigPath = $ConfigPath
        BackupPath = $backupPath
        OldBaseUrl = $oldBase
        NewBaseUrl = $BaseUrl
        ConfigCreated = $false
        AddedLlmgateSection = $addedSection
    }
}

function Get-PreferredPowerShell {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($null -ne $pwsh) { return $pwsh.Source }
    $ps = Get-Command powershell -ErrorAction SilentlyContinue
    if ($null -ne $ps) { return $ps.Source }
    throw "Cannot find PowerShell executable."
}

function Register-ProxyStartupLauncher {
    param(
        [string]$InstallRoot
    )

    $startupDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
    Ensure-Directory -Path $startupDir
    $launcherPath = Join-Path $startupDir "bd68-context-guard-thread.cmd"

    $pwsh = Get-PreferredPowerShell
    $safeRoot = $InstallRoot.Replace("'", "''")
    $line = '"' + $pwsh + '" -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Set-Location ''' + $safeRoot + '''; .\scripts\start_context_guard_thread.ps1 -Background"'
    Set-Content -LiteralPath $launcherPath -Value "@echo off`r`n$line`r`n" -Encoding ASCII
    return $launcherPath
}

function Start-ProxyDetachedNow {
    param(
        [string]$InstallRoot
    )

    $pwsh = Get-PreferredPowerShell
    $safeRoot = $InstallRoot.Replace("'", "''")
    $cmd = "Set-Location '$safeRoot'; .\scripts\start_context_guard_thread.ps1 -Background"
    Start-Process -FilePath $pwsh -ArgumentList @("-NoLogo", "-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-Command", $cmd) | Out-Null
}

function Wait-ProxyHealth {
    param(
        [string]$HealthUrl = "http://127.0.0.1:8787/__guard/health",
        [int]$Retries = 12,
        [int]$DelayMs = 500
    )

    for ($i = 0; $i -lt $Retries; $i++) {
        try {
            $resp = Invoke-RestMethod -Method Get -Uri $HealthUrl -TimeoutSec 3
            if ($null -ne $resp -and $resp.ok -eq $true) {
                return $true
            }
        } catch {
            # retry
        }
        Start-Sleep -Milliseconds $DelayMs
    }
    return $false
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
    exit 0
}

if ($Target -eq "codex") {
    if ($Scope -ne "global") {
        throw "Only global scope is currently supported for codex."
    }

    $codexRoot = $CodexRootPath
    $skillsRoot = Join-Path $codexRoot "skills"
    $installRoot = Join-Path $skillsRoot "bd_dev_kit"
    $agentsPath = Join-Path $codexRoot "AGENTS.md"
    $configPath = Join-Path $codexRoot "config.toml"

    Ensure-Directory -Path $codexRoot
    Ensure-Directory -Path $skillsRoot
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

    $mcpInstallResult = $null
    if ($InstallMcpBinaries) {
        try {
            $mcpInstallResult = Install-McpBinariesForCodex
        } catch {
            if ($FailOnMcpInstallError) {
                throw
            }
            Write-Warning "MCP binary installation warning: $($_.Exception.Message)"
        }
    }

    $proxyResult = $null
    if ($EnableProxy) {
        $proxyResult = Set-LlmgateBaseUrl -ConfigPath $configPath -BaseUrl $ProxyBaseUrl
    }

    $startupLauncher = ""
    if ($EnableProxy -and $RegisterProxyStartup) {
        $startupLauncher = Register-ProxyStartupLauncher -InstallRoot $installRoot
    }

    $healthOk = $false
    if ($EnableProxy -and $StartProxyNow) {
        Start-ProxyDetachedNow -InstallRoot $installRoot
        $healthOk = Wait-ProxyHealth
    }

    Write-Host "BD68 Dev v1.1 installed for Codex."
    Write-Host "Skill path (bd_dev_kit): $installRoot"
    if ($gstackLiteCopyCode -ge 0) {
        Write-Host "Skill path (gstack-lite): $gstackLiteInstallRoot"
    } else {
        Write-Host "Skill path (gstack-lite): skipped (source missing)"
    }
    Write-Host "AGENTS bootstrap path: $agentsPath"
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
    if ($EnableProxy -and $null -ne $proxyResult) {
        Write-Host "Thread base_url updated: $($proxyResult.OldBaseUrl) -> $($proxyResult.NewBaseUrl)"
        if (-not [string]::IsNullOrWhiteSpace($proxyResult.BackupPath)) {
            Write-Host "Config backup: $($proxyResult.BackupPath)"
        } else {
            Write-Host "Config backup: skipped (new config created)"
        }
        Write-Host "Thread config created: $($proxyResult.ConfigCreated)"
        Write-Host "Thread llmgate section added: $($proxyResult.AddedLlmgateSection)"
    } else {
        Write-Host "Thread config update: skipped"
    }
    if (-not [string]::IsNullOrWhiteSpace($startupLauncher)) {
        Write-Host "Thread startup launcher: $startupLauncher"
    } else {
        Write-Host "Thread startup launcher: skipped"
    }
    if ($EnableProxy -and $StartProxyNow) {
        Write-Host "Thread health check: $(if ($healthOk) { 'OK' } else { 'FAILED' })"
        Write-Host "Health URL: http://127.0.0.1:8787/__guard/health"
    } else {
        Write-Host "Thread health check: skipped"
    }
    Write-Host "Open a new Codex thread (or restart app) to ensure runtime picks up the updated base_url/profile."
    exit 0
}
