# Codex Guard Send (Preflight + Auto Mode)

Script: `scripts/codex_guard_send.ps1`

## Purpose
- Run a preflight payload budget check from the real payload file.
- Auto-select guard mode by thresholds:
  - `< 200,000`: monitor only.
  - `>= 200,000`: soft prepare.
  - `>= 240,000`: apply `Balanced`.
  - `>= 250,000`: apply `Aggressive`.
- Optionally force apply at soft threshold with `-ApplyAtSoftThreshold`.

## Usage
```powershell
.\scripts\codex_guard_send.ps1 `
  -InputPath "C:\Users\ngath\Desktop\bug output.txt" `
  -Mode Auto `
  -OutputPath ".\scripts\artifacts\bug_output.autoguard.json"
```

## Optional flags
- `-ApplyAtSoftThreshold`: apply `Balanced` starting at `>= 200,000`.
- `-Mode Safe|Balanced|Aggressive`: manual override, always applies guard.
- Custom thresholds:
  - `-SoftThresholdTokens`
  - `-EscalateThresholdTokens`
  - `-HardThresholdTokens`

## Output
Returns an object with:
- preflight chars/tokens estimate,
- selected mode and trigger state,
- whether guard was applied,
- post-guard estimate and reduction percent,
- ready-to-print status line:
  - `Preflight Guard: bật/tắt | mode: ... | Preflight: ~... tokens | trigger mềm: ... | đường chạy: manual`
