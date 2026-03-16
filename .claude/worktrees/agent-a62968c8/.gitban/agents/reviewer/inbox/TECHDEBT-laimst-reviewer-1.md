---
verdict: APPROVAL
card_id: laimst
review_number: 1
commit: a01f738
date: 2026-03-16
has_backlog_items: true
---

## Summary

This card addresses three non-blocking items from the `inexon` review: (L1) E2E-style Pester tests for the pack download flow, (L2) per-field defensive defaults in the registry fallback path, and (L3) help text alignment and a new Pack management section. The changes are confined to `install.ps1` and `tests/adapters-windows.Tests.ps1`, totaling 240 lines added and 20 removed.

All three items are implemented correctly and the card is honest about scope and limitations.

## Review

**L2 -- Per-field defensive defaults (install.ps1:139-143)**
The old logic blanked all three fields then checked if any were empty, resetting all to fallback. This meant a single bad `source_ref` would also discard a perfectly valid `source_repo`. The new per-field approach is the correct fix. Each field validates and falls back independently. Clean.

**L1 -- E2E tests (adapters-windows.Tests.ps1:1050-1249)**
Eight tests in a new "Pack Download Flow" describe block cover: full metadata passthrough, per-field defaults when each individual field is null, all-invalid fallback, directory structure creation with manifest parsing, unsafe filename rejection, and invalid pack name rejection. Three additional structural tests in the existing "Default Config" block verify that the source file contains the expected patterns.

The tests re-implement the validation functions and fallback logic locally rather than calling `install.ps1` as a unit. This means they test a copy of the logic, not the production code itself. The card is transparent about this: "A true E2E requires mocking the registry HTTP endpoint." The structural tests partially compensate by asserting that the production source contains the expected patterns (`sourceRepo = $FallbackRepo`, etc.), which would catch drift. This is an acceptable tradeoff for a chore card hardening an installer that cannot be trivially invoked in isolation.

**L3 -- Help text (install.ps1:486-502)**
Consistent 18-character padding, commands grouped logically, and the new Pack management section with `--packs use <n>` and `--packs next` subcommands. Straightforward and correct.

**Checkbox audit:** All checked boxes are truthful. "Testing Performed" says 215/215 and the executor trace shows `Invoke-Pester` was run. Documentation boxes are marked N/A, which is correct -- these are internal installer and test changes with no external doc surface.

No blockers.

## BACKLOG

- **L1**: The E2E tests duplicate validation functions from `install.ps1` into the test `BeforeAll`. If `install.ps1` were refactored to expose its validation functions as a dot-sourceable module (or a separate `.ps1` utilities file), the tests could exercise the real functions instead of copies. Low priority since the structural regex tests provide a safety net against drift.
