# Context Guard Runtime Thread

Files:
- `scripts/context_guard_thread.js`
- `scripts/start_context_guard_thread.ps1`
- `scripts/stop_context_guard_thread.ps1`
- `scripts/context_guard_failover_watchdog.ps1`
- `scripts/enable_context_guard_thread.ps1`
- `scripts/disable_context_guard_thread.ps1`
- `scripts/context_guard_thread_trace.ps1`

## What it does
- Adds a local HTTP thread route in front of `llmgate`.
- Computes preflight payload estimate from real request body.
- Auto applies guard by thresholds:
  - `< 200,000`: monitor only
  - `>= 200,000`: apply `Balanced` by default (can disable)
  - `>= 240,000`: apply `Balanced`
  - `>= 250,000`: apply `Aggressive`
- Forwards request to upstream and returns upstream response.

## Start thread route
Recommended (foreground in a dedicated terminal):
```powershell
.\scripts\start_context_guard_thread.ps1
```

Optional background mode:
```powershell
.\scripts\start_context_guard_thread.ps1 -Background
```

Watchdog failover (default: enabled when start script runs):
- Polls thread health every few seconds.
- Auto switches `config.toml` `base_url`:
  - thread down -> `https://llmgate.app/v1`
  - thread up -> `http://127.0.0.1:8787` (when switchback enabled)

Tune watchdog interval:
```powershell
.\scripts\start_context_guard_thread.ps1 -Background -WatchdogPollSeconds 2
```

Disable apply-at-soft behavior:
```powershell
.\scripts\start_context_guard_thread.ps1 -DisableApplyAtSoftThreshold
```

Health check:
```powershell
curl.exe -s http://127.0.0.1:8787/__guard/health
```

Trace latest pipeline metrics:
```powershell
.\scripts\context_guard_thread_trace.ps1 | Format-List *
```

Auto failover status (default: enabled):
```powershell
.\scripts\context_guard_thread_status.ps1 | Format-List *
```
- If thread is down and config currently points to `http://127.0.0.1:8787`, it auto-switches to `https://llmgate.app/v1`.
- If thread is up and config currently points to direct llmgate, it auto-switches back to thread route.

Common StatusLine format (`StatusFormatVersion = v3`):
- `Guard: bật/tắt | Mode: ... | Input: ... | Output: ... | trigger mềm: chưa kích hoạt/đã kích hoạt`
- `SkillGate: context-optimization=...; context-window-management=...; context-compression=...; prompt-caching=...; hierarchical-agent-memory=...`

## Enable in Codex global config
```powershell
.\scripts\enable_context_guard_thread.ps1
```

This updates:
- `C:\Users\ngath\.codex\config.toml`
- backup at `C:\Users\ngath\.codex\config.toml.context-guard.bak`

Note:
- Default thread base URL is `http://127.0.0.1:8787` (without `/v1`) to avoid path duplication.

## Disable / rollback
```powershell
.\scripts\disable_context_guard_thread.ps1
.\scripts\stop_context_guard_thread.ps1
```

## Notes
- Keep thread route running while Codex desktop is active.
- If Codex is already open, restart app or open a new thread/session to pick up changed `base_url`.
