# Bug Overview & Context

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

## Steps to Reproduce

1. Create a test environment with `New-PeonTestEnvironment`
2. Send 3 sequential `UserPromptSubmit` events with same session_id
3. Observe that `.state.json` only ever contains 1 timestamp per session (not 3)
4. The `user.spam` category never triggers

## Environment Details

- PowerShell 5.1 (Windows native)
- ConvertFrom-Json returns PSCustomObject with Object[] arrays
- Issue does NOT affect PowerShell 7+ where array handling differs

## Impact Assessment

- **Severity:** Medium -- spam detection (annoyed easter egg) never fires on Windows
- **Scope:** Only affects the `user.spam` CESP category; all other event routing works correctly
- **Workaround:** None currently

## Documentation & Code Review

- [ ] Reviewed ConvertTo-Hashtable function in install.ps1 lines 556-570
- [ ] Reviewed Read-StateWithRetry in install.ps1 lines 589-610

## Root Cause Investigation

- [ ] Confirmed: PS 5.1 pipeline unwrapping of single-element arrays in function returns
- [ ] Root cause identified in ConvertTo-Hashtable IEnumerable branch

## Solution Design

Fix options:
1. Wrap array returns with `,@(...)` to prevent PowerShell pipeline unwrapping
2. Add explicit array type preservation in the PSCustomObject branch
3. Use `[array]` cast on the property value assignment

Recommended: Option 1 -- change `return @($obj | ...)` to `return ,@($obj | ...)` (the unary comma prevents unwrapping)

## TDD Implementation Workflow

- [ ] Un-skip Scenario 14 test in `tests/peon-engine.Tests.ps1`
- [ ] Apply fix to ConvertTo-Hashtable in install.ps1
- [ ] Verify Scenario 14 passes (spam detection triggers after 3 rapid prompts)
- [ ] Verify all other peon-engine tests still pass

## Testing & Verification

- [ ] Scenario 14 test passes with fix applied
- [ ] Full peon-engine.Tests.ps1 suite passes (46 tests + un-skipped Scenario 14)
- [ ] Manual verification: 3 rapid prompts triggers user.spam sound

## Regression Prevention

- [ ] No regression in other state-dependent tests (debounce, no-repeat, TTL)

## Validation & Finalization

- [ ] Fix committed with test
- [ ] Card completed
