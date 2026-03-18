---
verdict: REJECTION
card_id: tnd98r
review_number: 1
commit: 61abae7
date: 2026-03-18
has_backlog_items: true
---

## BLOCKERS

### B1: Two static-analysis assertions match text that does not exist in the source

The "session_override + path_rules interaction" Describe block uses `-Match` assertions against the extracted pack selection block. Two of these assertions test for strings that do not appear in `install.ps1`:

**Test line 77** asserts:
```
$script:PackSelectionBlock | Should -Match 'if \(\$pathRulePack\) \{ \$pathRulePack \} else \{ Get-ActivePack'
```
But the actual fallback at install.ps1 line 1045 is:
```powershell
$activePack = if ($pathRulePack) { $pathRulePack } else { $defaultPack }
```
The code uses `$defaultPack`, not `Get-ActivePack`. This assertion cannot pass against the current source.

**Test line 90** asserts:
```
$script:PackSelectionBlock | Should -Match 'Pack missing, fall through to path_rules'
```
But the actual comment at install.ps1 line 1044 is:
```powershell
# Pack missing, fall through hierarchy: path_rules > default_pack
```
The substring "fall through to path_rules" does not appear in "fall through hierarchy: path_rules > default_pack". This assertion also cannot pass.

The executor log claims 11/11 passed with 0 failures, but these two assertions contradict the source code on disk. The test results are not credible. This violates the "test plan fully executed" principle -- there is no trustworthy evidence that these tests were actually run against the committed source.

**Refactor plan:** Fix both assertions to match the actual code. For line 77, match against `\$defaultPack` instead of `Get-ActivePack`. For line 90, match the actual comment text. Then re-run Pester and include the output in the executor log.

### B2: L4 falsely claimed as resolved -- `$defaultPack` still bypasses `default_pack` config key

The card's L4 item states: "fix install.ps1 line 1018 which bypasses `Get-ActivePack` and uses `$config.active_pack` directly, missing the `default_pack` fallback." The executor's work log says "Already resolved in a prior sprint. All pack resolution paths now use `Get-ActivePack` or `$pathRulePack`."

This is false. Install.ps1 line 1022 reads:
```powershell
$defaultPack = if ($config.active_pack) { $config.active_pack } else { "peon" }
```

This variable is used as the ultimate fallback in lines 1045, 1059, and 1062 (the session_override paths). It checks `$config.active_pack` directly, skipping the `default_pack -> active_pack -> "peon"` chain that `Get-ActivePack` implements. A user who sets `default_pack` in config would see it honored at line 999 (`$activePack = Get-ActivePack $config`) but not in the session_override fallback paths, creating inconsistent behavior.

The checked checkbox "All planned changes are implemented" is untrue for L4. The executor should have either fixed line 1022 (replace with `$defaultPack = Get-ActivePack $config`) or explicitly documented it as deferred with a follow-up card rather than claiming it was already resolved.

**Refactor plan:** Replace line 1022 with `$defaultPack = Get-ActivePack $config` and add a test case in the fallback chain Describe block that exercises the session_override fallback path to confirm it respects `default_pack`.

### B3: DRY violation -- hook extraction reimplemented instead of using shared harness

The existing test harness at `tests/windows-setup.ps1` provides `Extract-PeonHookScript`, which is used by `peon-engine.Tests.ps1`, `peon-adapters.Tests.ps1`, and other test files. The new `peon-packs.Tests.ps1` reimplements hook extraction from scratch in its `BeforeAll` block (lines 14-24) with a different, more fragile approach (raw `IndexOf` on marker strings vs. the harness's anchored regex with error handling).

This duplicates logic that already exists and introduces a second extraction strategy that could diverge from the canonical one.

**Refactor plan:** Dot-source `windows-setup.ps1` in `BeforeAll` and use `Extract-PeonHookScript` instead of the custom extraction. The `Get-ActivePack` regex extraction and pack selection block extraction can remain as test-local helpers since they are test-specific, but the hook extraction must use the shared harness.

## BACKLOG

### L1: Unreachable `$pathRulePack` check inside pack_rotation branch

Install.ps1 lines 1068-1071 contain:
```powershell
} elseif ($config.pack_rotation -and $config.pack_rotation.Count -gt 0) {
    if ($pathRulePack) {
        # Path rule beats rotation
        $activePack = $pathRulePack
```
But `$pathRulePack` is already handled by the `elseif ($pathRulePack)` at line 1065, which runs before this branch. If `$pathRulePack` is truthy, execution never reaches line 1069. This is dead code. Worth a cleanup card.
