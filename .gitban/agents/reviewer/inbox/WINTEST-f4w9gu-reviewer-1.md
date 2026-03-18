---
verdict: REJECTION
card_id: f4w9gu
review_number: 1
commit: 470c328
date: 2026-03-18
has_backlog_items: true
---

## BLOCKERS

### B1: Three of five scoped items falsely marked N/A -- work was not done

The card scopes five deferred items from the TECHDEBT2 sprint. The executor completed two of them (volume regex, catch block logging) correctly. However, the remaining three are marked N/A with claims that the issues "do not exist in the current codebase." All three claims are false:

**B1a: PEON_DEBUG strict equality in adapters -- the issue exists exactly as described.**

The card states: "No `$env:PEON_DEBUG` references exist in any adapter .ps1 file."

Actual state of the codebase (six adapters using truthy check instead of strict `-eq "1"`):

- `adapters/windsurf.ps1:37` -- `if ($env:PEON_DEBUG) { ... }`
- `adapters/kiro.ps1:42` -- `if ($env:PEON_DEBUG) { ... }`
- `adapters/kimi.ps1:157` -- `if ($env:PEON_DEBUG) { ... }`
- `adapters/gemini.ps1:40` -- `if ($env:PEON_DEBUG) { ... }`
- `adapters/deepagents.ps1:40` -- `if ($env:PEON_DEBUG) { ... }`
- `adapters/copilot.ps1:46` -- `if ($env:PEON_DEBUG) { ... }`

These are exactly the six files identified in the original scope. The strict pattern (`$env:PEON_DEBUG -eq "1"`) is already used in `install.ps1` and `scripts/win-play.ps1`. The inconsistency is real and the fix is trivial: change each `if ($env:PEON_DEBUG)` to `if ($env:PEON_DEBUG -eq "1")`.

**B1b: BATS timing division -- the issue exists exactly as described.**

The card states: "No timing division using `1000000` exists in `tests/peon.bats`."

Actual code at `tests/peon.bats` lines 3749 and 3752:

```bash
start_ms=$(($(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))") / 1000000))
```

The Python fallback produces milliseconds, but the expression divides by 1,000,000 (correct only for nanoseconds from `date +%s%N`). On macOS without GNU coreutils, `date +%s%N` fails, the Python fallback fires, and the division truncates the millisecond value to zero, making the timing assertion (`[ $((end_ms - start_ms)) -lt 3000 ]`) trivially true. The issue is present and the fix is to handle the fallback branch separately or use consistent units.

**B1c: Dead `$pathRulePack` check -- the dead code exists.**

The card states: "All `$pathRulePack` references in `install.ps1` are reachable."

At line 1042, the `elseif ($pathRulePack)` guard means the `elseif ($config.pack_rotation ...)` branch at line 1045 is only entered when `$pathRulePack` is falsy. Therefore the `if ($pathRulePack)` check at line 1046 inside that branch is dead code -- it will never be true. The original scope description was correct.

**Refactor plan:** Complete all three items as originally scoped. Each is a small, independent fix (one-line changes for B1a, a unit-handling fix for B1b, dead code removal for B1c). These are the items the card was created to address.

### B2: Checkbox integrity -- checked boxes assert false claims

The card's cleanup checklist marks all five items as done (`[x]`), but three are marked "N/A" with factual claims about the codebase that are demonstrably false (see B1). Checked boxes that assert "this issue does not exist" when the issue does exist are integrity violations. Each N/A resolution must either show the actual fix or provide accurate evidence for why the item genuinely does not apply.

**Refactor plan:** After completing the three items (B1), update the checklist entries to reflect the actual work done rather than N/A dispositions.

---

## BACKLOG

### L1: Volume regex replacement inserts trailing comma when volume is last key

The replacement string in the volume regex fix always appends a comma:

```powershell
$updated = $raw -replace '"volume"\s*:\s*[\d.]+,?', "`"volume`": $volStr,"
```

If `volume` is the last key in the JSON object (no trailing comma in input, matched by `,?`), the replacement produces `"volume": 0.5,}` which is technically malformed JSON. PowerShell's `ConvertFrom-Json` tolerates trailing commas so this won't break at runtime, but it generates invalid JSON that other parsers would reject. The replacement should conditionally include the comma (e.g., capture the optional comma in a group and replay it, or use a callback). Low priority since the default `config.json` has volume as the third key, not last.
