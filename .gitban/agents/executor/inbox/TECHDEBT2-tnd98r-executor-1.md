Activate your venv first: `.\.venv\Scripts\Activate.ps1`

The code for the gitban card with id tnd98r has been rejected at commit 61abae7 with 3 blockers. Please fix all blockers and re-submit.

===BEGIN REFACTORING INSTRUCTIONS===

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

**Refactor plan:** Fix both assertions to match the actual code. For line 77, match against `\$defaultPack` instead of `Get-ActivePack`. For line 90, match the actual comment text. Then re-run Pester and include the output in the executor log.

### B2: L4 falsely claimed as resolved -- `$defaultPack` still bypasses `default_pack` config key

Install.ps1 line 1022 reads:
```powershell
$defaultPack = if ($config.active_pack) { $config.active_pack } else { "peon" }
```

This variable is used as the ultimate fallback in lines 1045, 1059, and 1062 (the session_override paths). It checks `$config.active_pack` directly, skipping the `default_pack -> active_pack -> "peon"` chain that `Get-ActivePack` implements. A user who sets `default_pack` in config would see it honored at line 999 (`$activePack = Get-ActivePack $config`) but not in the session_override fallback paths, creating inconsistent behavior.

**Refactor plan:** Replace line 1022 with `$defaultPack = Get-ActivePack $config` and add a test case in the fallback chain Describe block that exercises the session_override fallback path to confirm it respects `default_pack`.

### B3: DRY violation -- hook extraction reimplemented instead of using shared harness

The existing test harness at `tests/windows-setup.ps1` provides `Extract-PeonHookScript`, which is used by `peon-engine.Tests.ps1`, `peon-adapters.Tests.ps1`, and other test files. The new `peon-packs.Tests.ps1` reimplements hook extraction from scratch in its `BeforeAll` block (lines 14-24) with a different, more fragile approach (raw `IndexOf` on marker strings vs. the harness's anchored regex with error handling).

**Refactor plan:** Dot-source `windows-setup.ps1` in `BeforeAll` and use `Extract-PeonHookScript` instead of the custom extraction. The `Get-ActivePack` regex extraction and pack selection block extraction can remain as test-local helpers since they are test-specific, but the hook extraction must use the shared harness.
