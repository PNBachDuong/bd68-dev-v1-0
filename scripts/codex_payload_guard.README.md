# Codex Payload Guard (PowerShell)

Script: `scripts/codex_payload_guard.ps1`

Coordinator script: `scripts/codex_guard_send.ps1` (preflight + auto mode selection).

## Purpose
- Reduce prompt bloat in Codex thread payload logs by:
  - removing internal encrypted/action user payloads,
  - stripping inline base64 image data,
  - truncating long tool outputs,
  - keeping only last N dialog messages,
  - optionally dropping alternate message representation.

## Usage
```powershell
.\scripts\codex_payload_guard.ps1 `
  -InputPath "C:\Users\ngath\Desktop\bug output.txt" `
  -OutputPath ".\scripts\artifacts\bug_output_balanced.json" `
  -KeepLastDialogMessages 120 `
  -ToolMaxChars 1200 `
  -DropAltRepresentation $true
```

## Suggested profiles
- `Safe`: `KeepLastDialogMessages=200`, `ToolMaxChars=3000`, `DropAltRepresentation=$false`
- `Balanced` (recommended): `KeepLastDialogMessages=120`, `ToolMaxChars=1200`, `DropAltRepresentation=$true`
- `Aggressive`: `KeepLastDialogMessages=80`, `ToolMaxChars=600`, `DropAltRepresentation=$true`

## Output
The script returns a summary object including:
- message count before/after,
- text chars and estimated token reduction,
- payload JSON size reduction,
- written output path.
