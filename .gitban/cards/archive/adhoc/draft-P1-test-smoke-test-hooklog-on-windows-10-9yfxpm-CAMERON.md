# Smoke Test: HOOKLOG on Windows 10

## User Testing Overview

* **Feature Under Test:** Structured debug logging (v2.17.0 / HOOKLOG sprint)
* **Platform:** Windows 10 Home 10.0.19045 (native, not WSL)
* **Goal:** Verify the full debug logging flow works end-to-end on a real Windows 10 machine before merging PR #405
* **Prerequisites:** Run `install.ps1` to deploy the updated `peon.ps1` with logging infrastructure

**Required Checks:**
* [ ] Feature or system under test is identified above
* [ ] Target user profile or environment is defined
* [ ] Success criteria are clear before testing begins

---

## Test Planning & Preparation

### Environment Setup

| Step | Action | Expected |
|:-----|:-------|:---------|
| 1 | Run `powershell -File install.ps1` from sprint/HOOKLOG branch | Installs updated peon.ps1 with debug logging |
| 2 | Verify `peon status` shows version 2.17.0 | Version matches |
| 3 | Verify `peon debug status` reports "disabled" | Debug off by default |

---

## Test Scenarios & Tasks

### Scenario 1: Debug toggle

| Step | Action | Expected Result | Pass? |
|:-----|:-------|:----------------|:-----:|
| 1 | `peon debug on` | Reports debug enabled | [ ] |
| 2 | `peon debug status` | Shows enabled, log dir path, 0 files | [ ] |
| 3 | `peon debug off` | Reports debug disabled | [ ] |
| 4 | `peon debug status` | Shows disabled | [ ] |

### Scenario 2: Log generation

| Step | Action | Expected Result | Pass? |
|:-----|:-------|:----------------|:-----:|
| 1 | `peon debug on` | Enabled | [ ] |
| 2 | Start a Claude Code session and trigger a few events (chat, tool use, stop) | Hooks fire normally, sounds play | [ ] |
| 3 | `peon logs` | Shows structured log entries with phases: [hook], [config], [state], [route], [sound], [play], [exit] | [ ] |
| 4 | Verify `inv=` IDs are present and consistent within each invocation | Each invocation's lines share the same 4-char hex ID | [ ] |
| 5 | Verify `duration_ms` in [exit] lines | Non-zero, plausible values | [ ] |

### Scenario 3: Log filtering

| Step | Action | Expected Result | Pass? |
|:-----|:-------|:----------------|:-----:|
| 1 | `peon logs --last 10` | Shows exactly 10 most recent lines | [ ] |
| 2 | Copy a session ID from the log output | Have a real session ID | [ ] |
| 3 | `peon logs --session <ID>` | Shows only entries for that session | [ ] |

### Scenario 4: Suppression logging

| Step | Action | Expected Result | Pass? |
|:-----|:-------|:----------------|:-----:|
| 1 | Mute peon: `peon mute` | Muted | [ ] |
| 2 | Trigger a hook event | Hook fires but sound suppressed | [ ] |
| 3 | `peon logs` | Log shows `[route]` with `suppressed=True` and reason | [ ] |
| 4 | `peon unmute` | Unmuted | [ ] |

### Scenario 5: Log rotation

| Step | Action | Expected Result | Pass? |
|:-----|:-------|:----------------|:-----:|
| 1 | Check log dir for daily file naming | File named `peon-ping-YYYY-MM-DD.log` | [ ] |
| 2 | `peon logs --prune` | Reports pruning (even if nothing to prune) | [ ] |
| 3 | `peon logs --clear` | Deletes all log files, confirms | [ ] |
| 4 | `peon debug status` | Shows 0 files | [ ] |

### Scenario 6: PEON_DEBUG env var override

| Step | Action | Expected Result | Pass? |
|:-----|:-------|:----------------|:-----:|
| 1 | `peon debug off` | Disabled | [ ] |
| 2 | Set `$env:PEON_DEBUG = "1"` and trigger a hook | Log file created despite debug=false in config | [ ] |
| 3 | Unset env var, trigger another hook | No new log entries (debug still off in config) | [ ] |

### Scenario 7: Verbose status output

| Step | Action | Expected Result | Pass? |
|:-----|:-------|:----------------|:-----:|
| 1 | `peon status` | Concise output — no debug/headphones/path rules lines | [ ] |
| 2 | `peon status --verbose` | Full output including debug state, all mode lines | [ ] |

---

## Findings & Recommendations

_Fill in after testing._

| Finding | Severity | Action |
|:--------|:---------|:-------|
| | | |

### Overall Verdict

- [ ] **PASS** — merge PR #405
- [ ] **FAIL** — issues found, document above and fix before merge
