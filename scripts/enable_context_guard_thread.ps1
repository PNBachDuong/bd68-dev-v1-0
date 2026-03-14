param(
    [string]$ConfigPath = "C:\Users\ngath\.codex\config.toml",
    [string]$ProxyBaseUrl = "http://127.0.0.1:8787"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config not found: $ConfigPath"
}

$backupPath = "$ConfigPath.context-guard.bak"
Copy-Item -LiteralPath $ConfigPath -Destination $backupPath -Force

$text = Get-Content -LiteralPath $ConfigPath -Raw
$pattern = '(\[model_providers\.llmgate\][^\[]*?base_url\s*=\s*")([^"]*)(")'
$m = [regex]::Match($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $m.Success) {
    throw "Could not locate [model_providers.llmgate] base_url in config."
}

$oldBase = $m.Groups[2].Value
$start = $m.Groups[2].Index
$length = $m.Groups[2].Length
$newText = $text.Remove($start, $length).Insert($start, $ProxyBaseUrl)

Set-Content -LiteralPath $ConfigPath -Value $newText -Encoding UTF8

[pscustomobject]@{
    Updated = $true
    ConfigPath = $ConfigPath
    BackupPath = $backupPath
    OldBaseUrl = $oldBase
    NewBaseUrl = $ProxyBaseUrl
}
