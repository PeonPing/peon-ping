---
verdict: APPROVAL
card_id: yq8iba
review_number: 1
commit: c42ba95
date: 2026-03-22
has_backlog_items: true
---

## Summary

This commit ports all 6 trainer CLI subcommands (on, off, status, log, goal, help) from the Unix `peon.sh` Python blocks to pure PowerShell inline in `install.ps1`'s embedded `peon.ps1`. The implementation is clean, follows ADR-002's accepted decision (inline in the switch block, no module extraction), and correctly uses existing state/config helpers.

The code handles edge cases well: auto-resetting state on date change, validating numeric input, checking for unknown exercises, defaulting exercises when the trainer config section is missing, and both `trainer` and `--trainer` prefix forms. Help text is properly added to `peon help` output.

## BLOCKERS

None.

## BACKLOG

**L1: Config reads bypass Get-PeonConfigRaw helper**

The trainer subcommands use `Get-Content $ConfigPath -Raw | ConvertFrom-Json` directly (lines 918, 943, 957, 1026, 1082) instead of the existing `Get-PeonConfigRaw $ConfigPath | ConvertFrom-Json` pattern used by every other CLI command (lines 426, 452, 480, 829). Today `Get-PeonConfigRaw` is a trivial wrapper, but if config reading ever gains preprocessing (BOM stripping, comment handling, encoding normalization), the trainer commands would miss it.

Suggested fix: replace `Get-Content $ConfigPath -Raw | ConvertFrom-Json` with `Get-PeonConfigRaw $ConfigPath | ConvertFrom-Json` in the 5 occurrences within the trainer block.

**L2: Progress bar rendering logic is duplicated**

The `status` and `log` subcommands each independently define `$barWidth`, `$fullBlock`, `$lightShade`, compute `$filled`/`$empty`, and build the bar string. This is a minor DRY violation. If the bar format changes (width, characters, color), both locations must be updated in lockstep.

Suggested fix: extract a `Format-TrainerBar` helper function (or even just a scriptblock) above the trainer switch block that takes `$done` and `$goal` and returns the formatted bar string.

**L3: Trainer tests deferred to a separate card**

The card explicitly defers Pester tests to "step 3." The TDD principle says new behavior needs tests in the same commit. However, this is a cross-platform CLI port of existing tested Unix behavior (BATS tests exist in `tests/trainer.bats`), the card documents this deferral explicitly, and the card confirms existing Pester regression tests (360/360) pass. The deferral is acknowledged and scoped, not forgotten. The step 3 card should be tracked.
