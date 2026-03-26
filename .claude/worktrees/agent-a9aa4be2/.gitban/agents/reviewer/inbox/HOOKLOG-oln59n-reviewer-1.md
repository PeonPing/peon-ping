---
verdict: APPROVAL
card_id: oln59n
review_number: 1
commit: a016ec1
date: 2026-03-26
has_backlog_items: false
---

## Review: step-11c-port-logs-prune-to-windows

Clean port of `peon logs --prune` from Unix (`peon.sh`) to Windows (`install.ps1`). The implementation faithfully mirrors the Unix behavior: reads `debug_retention_days` from config, computes a cutoff date string, iterates log files comparing date-stamped filenames, deletes older files, and reports the count.

### What was reviewed

**install.ps1 -- `--prune` case block (lines ~1244-1269)**

The implementation correctly:
- Reads `debug_retention_days` via `Get-PeonConfigRaw` with a default of 7, matching the Unix side.
- Guards against missing log directory before attempting enumeration.
- Guards against zero log files with an early return (correct message).
- Validates the date format with a regex before comparing, preventing accidental deletion of non-date-named files.
- Uses string comparison (`-lt`) on `yyyy-MM-dd` formatted dates, which works correctly because ISO 8601 date strings sort lexicographically.
- Reports results with color-coded output consistent with other log subcommands.

The help text and usage strings are updated in both the `default` error case and the `--help` block.

**tests/debug-logs-windows.Tests.ps1 -- 5 new tests**

Tests cover the key scenarios: pruning old files (boundary check with 2 old + 2 recent), no old files present, missing log directory, custom retention config, and a single-today-file case. All use established test helpers (`New-DebugTestEnv`, `Invoke-PeonCli`, `New-FakeLogFile`). The help assertion test is updated to verify `--prune` appears. Tests demonstrate TDD discipline -- they define the contract (expected messages and file counts) rather than testing internals.

The test file header comment is updated to reflect the new `--prune` coverage.

### Assessment

No issues found. The change is narrow, well-tested, and behaviorally equivalent to the Unix implementation. No new CLI commands or config keys are introduced (just a new subcommand flag on an existing command), so no change enforcement rules are triggered. The card correctly notes that bash/fish completions already include `--prune` from the Unix side.

### BLOCKERS

None.

### FOLLOW-UP

None.
