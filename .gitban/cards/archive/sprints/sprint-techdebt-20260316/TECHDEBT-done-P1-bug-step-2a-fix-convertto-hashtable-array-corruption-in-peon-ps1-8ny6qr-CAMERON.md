**Step 2A** — Phase 2 (install.ps1 cards). P1 bug fix goes first. Touches ConvertTo-Hashtable + peon-engine.Tests.ps1.

## Bug Overview & Context

* **Ticket/Issue ID:** WINTEST tech debt — discovered during step 2A testing
* **Affected Component/Service:** peon.ps1 (Windows hook engine) — ConvertTo-Hashtable function
* **Severity Level:** P1 — Medium (spam detection broken on Windows)
* **Discovered By:** WINTEST sprint executor during functional testing
* **Discovery Date:** 2026-03-15

**Required Checks:**
- [x] Ticket/Issue ID is linked above
- [x] Component/Service is clearly identified
- [x] Severity level is assigned based on impact

ConvertTo-Hashtable in the embedded peon.ps1 hook script corrupts JSON arrays when reading state back from `.state.json`. This breaks the spam detection (user.spam) feature because `prompt_timestamps` arrays never accumulate past a single entry.

## Bug Description

The `ConvertTo-Hashtable` function in peon.ps1 (install.ps1 lines 556-570) has a PowerShell 5.1 compatibility issue with its IEnumerable branch:

```powershell
if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
    return @($obj | ForEach-Object { ConvertTo-Hashtable $_ })
}
```

When a single-element JSON array like `[1773614856]` is deserialized by `ConvertFrom-Json` and then processed by `ConvertTo-Hashtable`, the return value gets unwrapped by PowerShell's pipeline semantics. The parent PSCustomObject branch then assigns a scalar (or in some cases a hashtable) instead of preserving the array type. This means:

1. First UserPromptSubmit: writes `prompt_timestamps: { "session": [ts1] }` to state
2. Second UserPromptSubmit: reads state, `ConvertTo-Hashtable` corrupts `[ts1]` into a hashtable
3. `Where-Object { ($now - $_) -lt $window }` fails with `op_Subtraction` error on hashtable
4. Result: `$recentPrompts` is always empty, timestamp never accumulates, spam never fires

## Bug Description

### What's Broken

ConvertTo-Hashtable corrupts single-element JSON arrays on PS 5.1, breaking spam detection.

### Expected Behavior

After 3 rapid `UserPromptSubmit` events, `prompt_timestamps` accumulates 3 entries and `user.spam` fires.

### Actual Behavior

`prompt_timestamps` is corrupted to a scalar/hashtable on read-back; timestamps never accumulate; spam never triggers.

### Reproduction Rate

* [x] 100% - Always reproduces

## Steps to Reproduce

1. Create a test environment with `New-PeonTestEnvironment`
2. Send 3 sequential `UserPromptSubmit` events with same session_id
3. Observe that `.state.json` only ever contains 1 timestamp per session (not 3)
4. The `user.spam` category never triggers

## Environment Details

| Environment Aspect | Required | Value | Notes |
| :--- | :---: | :--- | :--- |
| PowerShell Version | Yes | 5.1 (Windows native) | Issue does NOT affect PS 7+ |
| ConvertFrom-Json | Yes | Returns PSCustomObject with Object[] arrays | PS 5.1 behavior |
| OS | Yes | Windows 10/11 | Native Windows only |

## Impact Assessment

| Impact Category | Severity | Details |
| :--- | :---: | :--- |
| Spam detection | Medium | `user.spam` CESP category never fires on Windows |
| Other event routing | None | All other categories work correctly |
| Workaround | N/A | None currently |

## Documentation & Code Review

| Item | Applicable | File / Location | Notes / Evidence | Key Findings / Action Required |
| :--- | :---: | :--- | :--- | :--- |
| ConvertTo-Hashtable | Yes | install.ps1:556-570 | IEnumerable branch corrupts arrays | Fix pipeline unwrapping |
| Read-StateWithRetry | Yes | install.ps1:589-610 | Reads corrupted state | No change needed |

- [x] Reviewed ConvertTo-Hashtable function in install.ps1 lines 556-570
- [x] Reviewed Read-StateWithRetry in install.ps1 lines 589-610

## Root Cause Investigation

| Iteration # | Hypothesis | Test/Action Taken | Outcome / Findings |
| :---: | :--- | :--- | :--- |
| 1 | PS 5.1 pipeline unwraps single-element arrays in function returns | Traced ConvertTo-Hashtable with `[1773614856]` input | Confirmed: `return @($obj \| ForEach-Object {...})` unwraps to scalar |

- [x] Confirmed: PS 5.1 pipeline unwrapping of single-element arrays in function returns
- [x] Root cause identified in ConvertTo-Hashtable IEnumerable branch

## Solution Design

Fix options:
1. Wrap array returns with `,@(...)` to prevent PowerShell pipeline unwrapping
2. Add explicit array type preservation in the PSCustomObject branch
3. Use `[array]` cast on the property value assignment

Recommended: Option 1 -- change `return @($obj | ...)` to `return ,@($obj | ...)` (the unary comma prevents unwrapping)

## TDD Implementation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| 1. Write failing test | Un-skip Scenario 14 in peon-engine.Tests.ps1 | - [x] Test written and fails |
| 2. Apply fix | Change `return @(...)` to `return ,@(...)` in ConvertTo-Hashtable | - [x] Fix applied |
| 3. Verify test passes | Scenario 14: spam detection after 3 rapid prompts | - [x] Test passes |
| 4. Run full suite | All peon-engine.Tests.ps1 tests | - [x] No regressions |

## Testing & Verification

| Test Type | Test Case | Expected Result | Status |
| :--- | :--- | :--- | :---: |
| Unit | Scenario 14 — spam detection | user.spam triggers after 3 rapid prompts | - [x] Pass |
| Regression | Full peon-engine suite | All 46+ tests pass | - [x] Pass |
| Regression | State-dependent tests | Debounce, no-repeat, TTL unaffected | - [x] Pass |

## Regression Prevention

- [x] No regression in other state-dependent tests (debounce, no-repeat, TTL)

## Validation & Finalization

| Task | Detail/Link |
| :--- | :--- |
| Fix committed | With test |
| Card completed | All checkboxes green |

| Topic | Action Required | Tracker | Gitban Cards |
| :--- | :--- | :--- | :--- |
| PS 5.1 array handling | Monitor for similar issues in other ConvertFrom-Json consumers | Backlog | N/A |

- [x] Fix committed with test
- [x] Card completed


## Execution Summary

**Root Cause (expanded):** Two related PS 5.1 issues in ConvertTo-Hashtable:

1. **Pipeline unwrapping**: `return @($obj | ForEach-Object {...})` unwraps single-element arrays to scalars (the originally identified bug).
2. **PSObject wrapping**: When ForEach-Object passes values through the pipeline into a function with `[Parameter(ValueFromPipeline)]`, PS 5.1 wraps primitives (Int32, Int64, etc.) in PSObject. These wrapped values then match `$obj -is [PSCustomObject]`, causing integers to be converted to empty hashtables.

**Fix applied** (install.ps1 lines 556-570):
- Added `$null` guard at top
- Added early return for `[System.ValueType]` and `[string]` before the PSCustomObject branch
- Removed redundant `-isnot [string]` from IEnumerable check (now handled earlier)
- Added unary comma `return ,@(...)` to prevent single-element array unwrapping

**TDD execution:**
- Un-skipped Scenario 14 test in peon-engine.Tests.ps1
- Confirmed test failed before fix (AudioLog.Count was 0, expected 1)
- Confirmed test passed after fix (user.spam fires correctly)
- Full suite: 47/47 passed, 0 failed, 0 skipped

**Commit:** `ff71628` fix: prevent ConvertTo-Hashtable from corrupting arrays on PS 5.1

**Files changed:**
- `install.ps1` — ConvertTo-Hashtable fix in embedded peon.ps1 here-string
- `tests/peon-engine.Tests.ps1` — Scenario 14 un-skipped (copied from sprint/WINTEST)
- `tests/windows-setup.ps1` — shared test harness (copied from sprint/WINTEST)

## Review Log

| Review | Verdict | Date | Report |
| :--- | :--- | :--- | :--- |
| 1 | APPROVAL | 2026-03-16 | `.gitban/agents/reviewer/inbox/TECHDEBT-8ny6qr-reviewer-1.md` |

Routed: executor close-out instructions to `.gitban/agents/executor/inbox/TECHDEBT-8ny6qr-executor-1.md`. Two non-blocking items (L1 locale guard, L2 test race) grouped into 1 FASTFOLLOW card and routed to planner at `.gitban/agents/planner/inbox/TECHDEBT-8ny6qr-planner-1.md`.