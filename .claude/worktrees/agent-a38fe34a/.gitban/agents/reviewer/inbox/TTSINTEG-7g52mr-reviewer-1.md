---
verdict: APPROVAL
card_id: 7g52mr
review_number: 1
commit: c2ff5ac
date: 2026-03-28
has_backlog_items: true
---

## Review: step-1-tts-config-schema-and-peon-update-backfill

Clean, well-scoped card. The diff adds a `tts` config section to `config.json`, extends the Windows installer to include it, and adds tests for both the backfill path and the preserve-existing-values path. No runtime behavior changes -- `tts.enabled` defaults to `false`.

### Architecture

The implementation correctly leverages the existing shallow-merge backfill in `install.sh` (lines 614-635). Because the merge operates on top-level keys only (`for key, value in defaults.items(): if key not in user_cfg`), adding `tts` as a new top-level key in `config.json` is sufficient -- no changes to `install.sh` are needed. This is the same pattern used for `trainer`, `path_rules`, and every other nested config section. Sound decision to not touch `install.sh`.

The `install.ps1` change correctly mirrors the JSON structure as a PowerShell hashtable, following the established `trainer` pattern at the same nesting level.

### ADR Compliance

ADR-001 specifies backends as independent scripts with a stdin-based calling convention. This card is config-only and does not introduce any backend logic, so there is nothing to violate. The config keys (`backend`, `voice`, `rate`, `volume`, `mode`) align with the parameters described in ADR-001's calling convention.

### TDD Assessment

The tests are well-structured and test behavioral contracts rather than implementation details:

1. **Backfill test**: Creates a config without `tts`, runs the same Python merge logic used by `install.sh`, and asserts all 6 keys are present with correct default values.
2. **Preserve test**: Creates a config with custom `tts` values (`enabled: true`, `backend: "say"`, `voice: "Samantha"`, etc.), runs the merge, and asserts none of the user's values were overwritten.
3. **Pester test**: Verifies `install.ps1` source contains the `tts` hashtable with correct defaults.

Both BATS tests exercise the actual Python merge logic (not a mock), which is the right call -- they are testing the real backfill behavior. The Pester test is a static content match against the installer source, which is appropriate for verifying the Windows fresh-install path.

The design doc's test strategy calls for "same two cases for the Windows config generation path" in Pester, but only one Pester test was added (correct defaults). The preserve-existing-values case for Windows is not tested. This is a minor gap -- the Windows installer only runs the config generation on fresh installs (not updates), so the "preserve" scenario does not apply to `install.ps1`. The card's executor notes confirm Pester ran 24/24 green.

### Observations

The BATS tests inline the Python merge logic rather than calling `peon update` end-to-end. This is a deliberate tradeoff documented in the executor's notes ("keeping them focused and fast"). The merge logic is identical to what `install.sh` runs, so this is acceptable for a config-only card. Integration testing of the full `peon update` flow is better suited to CI.

### No Blockers

The diff is minimal, correctly scoped, and aligns with the design doc's Phase 1 deliverables. All acceptance criteria are met.

## FOLLOW-UP

**L1 -- Pester test missing `volume = 0.5` assertion.** The Pester test asserts on 6 of the 7 items in the `tts` hashtable but omits `volume = 0.5`. This is likely because the regex `0\.5` could match other volume fields in the config, but it should be added for completeness (perhaps with a more specific pattern anchored to the tts block context). Non-blocking.

**L2 -- README.md config docs deferred.** Per CLAUDE.md change enforcement rules, adding a config key requires updating README.md configuration docs. The card explicitly defers this to the tts-docs card. Acceptable as long as the follow-up card tracks it -- TTS is disabled by default with zero user-visible behavior, so premature documentation would be noise. Verify the tts-docs card exists in the sprint or backlog.
