---
verdict: APPROVAL
card_id: r0qoai
review_number: 1
commit: 9939dab
date: 2026-03-26
has_backlog_items: false
---

## Review: step-11a-add-version-and-debug-state-to-windows-status

### Summary

Clean, well-scoped card. Adds two pieces of information to the Windows `peon --status` output: (1) the version number on the always-shown status line, and (2) debug logging state in the verbose-only block. The merge commit (9939dab) integrates this with the concurrent verbose-gating work (card nnj6gt) and the conflict resolution is correct.

### Analysis

**Production code (install.ps1)**

The version line reads `VERSION` from `$InstallDir` with a `Test-Path` guard and an "unknown" fallback -- safe and correct. It is placed on the main status line (always shown), which matches the card spec. The debug logging block reads `$env:PEON_DEBUG`, displays enabled/disabled, and conditionally shows the log directory. It is correctly placed inside the `$isVerbose` gate. Both additions follow the existing code style (same `Write-Host` pattern, same color, same prefix).

The merge conflict in the status handler was resolved correctly: the verbose-gating structure from card nnj6gt is preserved, and the version/debug additions from this card slot into the right positions (version in essential, debug in verbose).

**Tests (adapters-windows.Tests.ps1)**

Four tests added in two tiers:

1. Structural tests (lines 1229-1237): assert that the source file contains the strings `VERSION`, `version`, `debug logging`, and `PEON_DEBUG`. These follow the existing pattern in the "Embedded peon.ps1 Hook Script" describe block, which validates source content rather than runtime behavior. Consistent with the surrounding tests.

2. Functional E2E tests (lines 1702-1715): actually invoke `peon.ps1` and assert on output. The version test checks for the word "version" in default status output. The debug test checks for "debug logging: disabled" in verbose output. These exercise real behavior.

The structural tests are thin (they only confirm the strings exist in the source), but the functional tests compensate by actually running the command and checking output. The test structure matches the existing pattern in this file -- structural tests in the "Embedded" block, functional tests in the "CLI Commands - Functional" block. This is proportional for a chore card adding two display lines.

**TDD proportionality**: This is a display-only change (adding informational output lines to a CLI status command). The tests verify the output appears. No complex logic, no branching behavior beyond the existing verbose gate. The test coverage is adequate.

**Checkbox integrity**: All checked boxes are truthful. The work log accurately describes what was done.

### Close-out

No outstanding actions. Card is approved as-is.
