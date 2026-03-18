---
verdict: APPROVAL
card_id: aodz7v
review_number: 1
commit: 3f5a1f0
date: 2026-03-13
has_backlog_items: true
---

The commit correctly extends the `active_pack` to `default_pack` and `agentskill` to `session_override` rename across all remaining components: adapter config templates, TypeScript plugins, install.ps1 CLI and hook runtime, hook-handle-use scripts, skill docs, and tests. The approach is consistent -- every read site uses the `default_pack`-first-with-`active_pack`-fallback pattern, and every write site produces only the new key name. The regex replacements in install.ps1 accept both old and new keys on input (`(default_pack|active_pack)`) and normalize to `default_pack` on output, which is correct migration-in-place behavior.

The TypeScript changes properly add `active_pack` as an optional legacy field on the `PeonConfig` interface and resolve it at a single call site (`resolveActivePack`), which is clean. The new test case for the legacy fallback path in `opencode-peon-ping-internals.test.ts` covers the gap.

The core migration logic (in `peon.sh` / `peon update`) and BATS migration tests were already landed in prior commits and are not part of this diff, which is appropriate -- this commit focuses on propagation to peripheral components.

**Close-out actions:**
- Full CI (BATS + Pester) must pass before merge.
- The "Full Regression Suite" checkbox on the card should be checked once CI is green.

## BACKLOG

**L1: DRY violation -- PowerShell pack resolution fallback repeated 10 times in install.ps1**

The expression `if ($cfg.default_pack) { $cfg.default_pack } elseif ($cfg.active_pack) { $cfg.active_pack } else { "peon" }` (and its `$config.` variant) appears 10 times across install.ps1. This is a maintenance risk -- if the fallback chain changes (e.g., removing the legacy key in a future version), all 10 sites must be found and updated. Extract a helper function:

```powershell
function Get-ActivePack {
    param($Config)
    if ($Config.default_pack) { $Config.default_pack }
    elseif ($Config.active_pack) { $Config.active_pack }
    else { "peon" }
}
```

Then replace all 10 call sites with `$activePack = Get-ActivePack $cfg`. This also aligns with how the Python side handles it (single `cfg.get('default_pack', cfg.get('active_pack', 'peon'))` pattern, though Python's nesting makes duplication less verbose).
