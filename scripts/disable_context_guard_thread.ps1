param(
    [string]$ConfigPath = "C:\Users\ngath\.codex\config.toml"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$backupPath = "$ConfigPath.context-guard.bak"
if (-not (Test-Path -LiteralPath $backupPath)) {
    throw "Backup config not found: $backupPath"
}

Copy-Item -LiteralPath $backupPath -Destination $ConfigPath -Force

[pscustomobject]@{
    Restored = $true
    ConfigPath = $ConfigPath
    BackupPath = $backupPath
}
