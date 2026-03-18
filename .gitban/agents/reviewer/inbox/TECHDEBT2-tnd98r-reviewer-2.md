---
verdict: REJECTION
card_id: tnd98r
review_number: 2
commit: d433e70
date: 2026-03-18
has_backlog_items: false
---

## BLOCKERS

### B1: Tests were bent to match the bug instead of fixing the bug (B2 from review 1 remains open)

Review 1's B2 identified that `install.ps1` line 1022 bypasses `Get-ActivePack` and reads `$config.active_pack` directly:

```powershell
$defaultPack = if ($config.active_pack) { $config.active_pack } else { "peon" }
```

This variable is then used as the ultimate fallback at lines 1045, 1059, and 1062. A user who sets `default_pack` in their config will see it honored at line 999 (`$activePack = Get-ActivePack $config`) but **not** in any session_override fallback path, because those paths fall through to `$defaultPack` which skips `default_pack` entirely.

The executor's cycle 2 commit (`6f27c48`) claimed B2 was "already resolved" and wrote regression-guard tests asserting that `Get-ActivePack $config` is called in the session_override fallback paths. Those tests contradicted the actual source code (which uses `$defaultPack`, not `Get-ActivePack`).

Commit `d433e70` -- the commit under review -- resolves this contradiction by **changing the tests to match the buggy code**:

- Renamed the Describe block from "session_override fallback uses Get-ActivePack" to "session_override fallback uses defaultPack"
- Removed the assertion that no `$config.active_pack` usage exists in the session_override block
- Removed the assertion that `Get-ActivePack $config` is called in fallback paths
- Replaced both with a single assertion that `$defaultPack` is used -- enshrining the config parity gap as the expected behavior

This is the opposite of what review 1 requested. The refactor plan for B2 was: "Replace line 1022 with `$defaultPack = Get-ActivePack $config`". Instead, the tests were weakened to accept the current broken behavior. This is a lazy solve -- the tests were adapted to paper over the problem rather than fixing the root cause.

The card's own motivation section states: "The Python reference in `peon.sh` checks `cfg.get('default_pack', cfg.get('active_pack', 'peon'))`, supporting a `default_pack` key distinct from `active_pack`. The PS1 engine only checks `active_pack`, creating a config parity gap." Line 1022 is exactly that gap, and it remains unfixed.

**Refactor plan:**

1. Fix `install.ps1` line 1022 to use `Get-ActivePack`:
   ```powershell
   $defaultPack = Get-ActivePack $config
   ```
   This is a one-line change. `Get-ActivePack` already implements the `default_pack -> active_pack -> "peon"` chain correctly (lines 38-42 and 356-360). The variable name `$defaultPack` can stay since it serves as the pre-computed fallback for the session_override branches.

2. Restore the regression-guard test from `6f27c48` that asserts no raw `$config.active_pack` usage exists in the session_override block. Alternatively, add a behavioral test: create a config with `default_pack = "glados"` and no `active_pack`, invoke `Get-ActivePack`, and assert the session_override fallback resolves to "glados".

3. Re-run Pester and include actual output in the executor log.

### B2: No evidence of test execution for commit d433e70

The executor log (`TECHDEBT2-tnd98r-executor-2.jsonl`) records a test-run event claiming 13/13 passed, but that entry corresponds to commit `6f27c48`, not `d433e70`. Commit `d433e70` materially changes 4 test assertions and removes 2 entire test cases. There is no executor log entry, no Pester output, and no test-run evidence for this commit.

Given that `6f27c48`'s assertions (which asserted `Get-ActivePack $config`) could not have passed against the actual source code (which uses `$defaultPack`), and `d433e70` exists specifically to fix that mismatch, the 13/13 claim in the executor log is not credible for the state of the code at `d433e70`.

**Refactor plan:** After fixing B1, run `Invoke-Pester -Path tests/peon-packs.Tests.ps1` and include the full output in the executor log. The log entry must reference the final commit hash.
