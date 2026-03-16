# Chore: CI Workflow Update and Test Suite Integration

## Cleanup Scope & Context

* **Task Description:** Update `.github/workflows/test.yml` to discover and run all new Pester test files (not just `tests/adapters-windows.Tests.ps1`), verify the full suite passes on windows-latest, and ensure total execution time stays under 60 seconds.
* **Motivation:** The WINTEST sprint splits tests across 5 files. The current CI workflow hardcodes a single test file path. Without this update, new tests will not run in CI.
* **Sprint Context:** This is the final card in the WINTEST sprint. All step 2 cards (2A/2B/2C/2D) must complete first so this card can verify the full suite.

**Dependencies:** All step 2 cards (1dnbzv, lxhqpf, jwh5zl, frjune) must complete first.

---

## Deferred Work Review

| Item | Source | Action |
|------|--------|--------|
| Single-file Pester path in CI | `.github/workflows/test.yml` line 56 | Change to discover all `*.Tests.ps1` files in `tests/` |
| Syntax validation step | `.github/workflows/test.yml` lines 34-49 | Verify deepagents.ps1 is now covered (added to adapters-windows.Tests.ps1 in step 2B) |
| Existing card gtb6dm | backlog | Archive or mark superseded -- its scope is covered by WINTEST sprint |

---

## Cleanup Checklist

### CI Workflow Changes

- [ ] Update `$config.Run.Path` from `"tests/adapters-windows.Tests.ps1"` to `"tests/"` (or explicit list of all .Tests.ps1 files) so Pester discovers all test files
- [ ] Verify the syntax validation step in CI still passes (adapters list may need deepagents.ps1 added)
- [ ] Run full suite locally on PS 5.1 and confirm all tests pass
- [ ] Run full suite locally on PS 7+ (pwsh) and confirm all tests pass
- [ ] Verify total Pester execution time is under 60 seconds on windows-latest
- [ ] If execution time exceeds 60s, add parallel test execution or split CI into multiple jobs

### Test File Organization Verification

- [ ] `tests/windows-setup.ps1` exists and is NOT a .Tests.ps1 file (Pester will not try to run it as a test file)
- [ ] `tests/adapters-windows.Tests.ps1` retained with existing structural/lint tests
- [ ] `tests/peon-engine.Tests.ps1` exists with core engine functional tests
- [ ] `tests/peon-adapters.Tests.ps1` exists with adapter translation tests
- [ ] `tests/peon-security.Tests.ps1` exists with security/edge case tests
- [ ] `tests/peon-packs.Tests.ps1` exists with pack selection tests
- [ ] All test files dot-source `windows-setup.ps1` successfully

### Cleanup of Superseded Work

- [ ] Card gtb6dm (add functional pester tests for state I/O helpers) marked as superseded by WINTEST sprint or archived
- [ ] No duplicate test coverage between old structural tests and new functional tests (structural tests kept as lint layer)

---

## Validation & Closeout

| Check | Status |
|-------|--------|
| CI workflow updated | - [ ] |
| Full suite green on windows-latest | - [ ] |
| Execution time under 60s | - [ ] |
| All 5 test files discovered by Pester | - [ ] |
| No regressions in existing BATS tests (macOS job) | - [ ] |

---

## Required Reading

| What | Where | Why |
|------|-------|-----|
| Current CI workflow | `.github/workflows/test.yml` | The file to modify -- understand current Pester invocation |
| Pester configuration | Pester docs: `New-PesterConfiguration` | Understand Run.Path accepts directories for auto-discovery |
| All new test files | `tests/*.Tests.ps1` | Verify each file runs independently |

---

## Notes

- The key CI change is minimal: `$config.Run.Path = "tests/adapters-windows.Tests.ps1"` becomes `$config.Run.Path = "tests/"` (Pester auto-discovers all `*.Tests.ps1` files in the directory). The shared `windows-setup.ps1` is intentionally NOT named with a `.Tests.ps1` suffix so Pester ignores it.
- If execution time is a concern, Pester 5 supports `-Parallel` but only on PS 7+. Since CI uses pwsh (PS 7+), this is an option. However, PS 5.1 local testing would still run sequentially.
- The BATS tests (macOS job) are unaffected by these changes -- they run in a separate CI job on macos-latest.
