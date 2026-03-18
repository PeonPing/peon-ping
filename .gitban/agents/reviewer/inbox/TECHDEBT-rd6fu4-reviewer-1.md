---
verdict: APPROVAL
card_id: rd6fu4
review_number: 1
commit: 30ab6aa
date: 2026-03-16
has_backlog_items: true
---

## Review: Port path_rules to peon.ps1 and add pack selection test scenarios 4-7

### Summary

This commit ports the `path_rules` directory-based pack selection feature from `peon.sh` (Python/fnmatch) to the Windows native `peon.ps1` engine (PowerShell `-like` operator), and adds 4 new Pester test scenarios covering glob matching, first-match-wins ordering, and two fallthrough cases. It also introduces the shared test harness (`windows-setup.ps1`) and the engine test suite (`peon-engine.Tests.ps1`) into this branch.

### Assessment

**Production code (install.ps1 -- embedded peon.ps1)**

The path_rules implementation is a faithful port of the Python reference:

1. `$cwd` extraction from event JSON mirrors `event_data.get('cwd', '')` in peon.sh.
2. The glob matching loop uses PowerShell `-like`, which has equivalent semantics to Python `fnmatch.fnmatch()` -- both treat `*` as matching all characters including path separators. Correct parity.
3. Pack directory existence check (`Test-Path $candidateDir -PathType Container`) before accepting a match mirrors `os.path.isdir()` in the reference.
4. `$pathRulePack` is computed once upfront and woven into all fallback paths -- session_override missing pack, default key fallthrough, rotation, and the terminal `else` branch. This matches the Python `_path_rule_pack or _default_pack` pattern across all equivalent branches.
5. The `$defaultPack` variable consolidates the previously repeated `$activePack = $config.active_pack; if (-not $activePack) { $activePack = "peon" }` pattern into a single assignment. DRY improvement.
6. The override hierarchy comment (`session_override > path_rules > pack_rotation > default_pack`) is clear and accurate.

One minor semantic note: peon.sh computes `_default_pack = cfg.get('default_pack', cfg.get('active_pack', 'peon'))`, checking for a `default_pack` key first. The PS1 version only checks `active_pack`. This is consistent with the pre-existing PS1 behavior (no `default_pack` key was ever referenced in the Windows engine) and is not a regression. Tracked below as backlog.

**Test code (peon-packs.Tests.ps1 -- scenarios 4-7)**

All four scenarios match the card specification precisely:

- **Scenario 4** (glob match): Configures a single path_rule `*/myproject/*` -> `sc_kerrigan`, sends a cwd that matches, asserts the kerrigan pack is selected. Tests the core feature.
- **Scenario 5** (first-match-wins): Two overlapping rules where cwd matches both, asserts the first rule wins. Tests ordering contract.
- **Scenario 6** (no match fallthrough): Same rule but cwd doesn't match, asserts fallthrough to `default_pack`. Tests the negative path.
- **Scenario 7** (missing pack directory): Rule matches but pack directory `ghost_pack` doesn't exist, asserts fallthrough. Tests the safety check.

Tests drive behavior, not implementation -- they configure the system through the public interface (config + event JSON), invoke the full hook, and assert on the observable output (audio log paths). This is proper TDD structure. The scenarios cover the happy path, ordering semantics, and two distinct failure modes.

**Test harness (windows-setup.ps1)**

Well-structured shared infrastructure. Key design decisions are sound:
- `Extract-PeonHookScript` uses a marker-anchored regex extraction rather than line-number-based slicing, making it resilient to install.ps1 structural changes.
- `New-PeonTestEnvironment` creates fully isolated temp directories with GUID-based naming, eliminating test cross-contamination.
- `Invoke-PeonHook` uses `System.Diagnostics.Process` with async stdout/stderr reads to avoid deadlocks -- this is the correct pattern for PowerShell subprocess testing.
- The mock `win-play.ps1` logs to `.audio-log.txt` in `path|volume` format, enabling deterministic assertions on audio playback without actual audio.
- Culture-aware JSON serialization (InvariantCulture) prevents locale-dependent decimal separator issues.

**Engine tests (peon-engine.Tests.ps1)**

781 lines of comprehensive functional tests covering: harness smoke tests, event routing (7 scenarios), config behavior (4 scenarios), and state management (6 scenarios). The skipped test (Scenario 14 -- spam detection) is properly documented with a known bug explanation referencing the ConvertTo-Hashtable array corruption issue. This is honest documentation of a pre-existing limitation, not a lazy skip.

### BLOCKERS

None.

### BACKLOG

**L1: `default_pack` config key not supported in peon.ps1**
The Python reference checks `cfg.get('default_pack', cfg.get('active_pack', 'peon'))`, supporting a `default_pack` key distinct from `active_pack`. The PS1 engine only checks `active_pack`. This is pre-existing and not a regression from this commit, but worth aligning in a future pass for full config parity. Low priority since no user-facing documentation references `default_pack` as a PS1 config key.

**L2: No test for path_rules + session_override interaction**
The production code correctly integrates `$pathRulePack` into the session_override fallback paths (when session pack is missing or invalid), but there is no test scenario that exercises the combined `session_override + path_rules` fallback. A test where a session pack is missing and a path_rule matches would confirm the integration point directly.
