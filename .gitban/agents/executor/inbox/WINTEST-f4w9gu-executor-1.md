Activate your venv first: `.\.venv\Scripts\Activate.ps1`

===BEGIN REFACTORING INSTRUCTIONS===

The reviewer rejected the current implementation because 3 of 5 scoped items were falsely marked N/A. The issues exist in the codebase exactly as originally described. Complete all three items below, then update the card checkboxes to reflect the actual work done.

### B1a: PEON_DEBUG strict equality in 6 adapter .ps1 files

Change each `if ($env:PEON_DEBUG) { ... }` to `if ($env:PEON_DEBUG -eq "1") { ... }` in:

- `adapters/windsurf.ps1` (line 37)
- `adapters/kiro.ps1` (line 42)
- `adapters/kimi.ps1` (line 157)
- `adapters/gemini.ps1` (line 40)
- `adapters/deepagents.ps1` (line 40)
- `adapters/copilot.ps1` (line 46)

This aligns with the strict pattern already used in `install.ps1` and `scripts/win-play.ps1`.

### B1b: BATS timing division fix in tests/peon.bats

At lines 3749 and 3752:

```bash
start_ms=$(($(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))") / 1000000))
```

The Python fallback produces milliseconds, but the expression divides by 1,000,000 (correct only for nanoseconds from `date +%s%N`). On macOS without GNU coreutils, `date +%s%N` fails, the Python fallback fires, and the division truncates the millisecond value to zero. Fix: handle the fallback branch separately so the Python path does not divide by 1,000,000, or use consistent units throughout.

### B1c: Dead `$pathRulePack` check in install.ps1

At line 1042, the `elseif ($pathRulePack)` guard means the `elseif ($config.pack_rotation ...)` branch at line 1045 is only entered when `$pathRulePack` is falsy. Therefore the `if ($pathRulePack)` check at line 1046 inside that branch is dead code. Remove it.

### B2: Update card checkboxes

After completing the three items above, update the card's cleanup checklist entries to reflect the actual work done. Replace the N/A dispositions with descriptions of the fixes applied. Use gitban tools for card updates.
