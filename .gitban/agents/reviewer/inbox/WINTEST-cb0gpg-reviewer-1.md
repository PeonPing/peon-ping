---
verdict: REJECTION
card_id: cb0gpg
review_number: 1
commit: 7b5c5ae
date: 2026-03-20
has_backlog_items: false
---

## Review: Harden install.ps1 volume regex trailing comma

### Summary

The fix itself is correct. The regex change from `[\d.]+,?` (which always appended a comma in the replacement) to `[\d.]+(,?)` with `$1` replay is the right approach. It preserves the trailing comma when present and omits it when absent, producing valid JSON in both cases.

However, the commit lacks a test for the specific edge case it fixes.

### BLOCKERS

**B1: No test for the volume-as-last-key edge case (TDD violation)**

The entire purpose of this card is to fix a bug where volume-as-last-key produces invalid JSON (`"volume": 0.5,}`). The existing Pester tests in `cli-config-write.Tests.ps1` all use a config where `volume` is the second key (after `default_pack`), so the trailing comma is always present in the serialized JSON. None of the existing tests would have caught this bug, and none would catch a regression.

A proper TDD approach would have started with a failing test: a config where `volume` is the last key, then run `--volume`, then assert that `ConvertFrom-Json` on the result succeeds (or that the raw JSON does not contain a trailing comma before `}`).

**Refactor plan:** Add a Pester test in `cli-config-write.Tests.ps1` under the "CLI --volume command" describe block:

```powershell
It "produces valid JSON when volume is the last key" {
    # Create env with a config where volume is the last key
    $script:env = New-TestHookEnv -ConfigOverrides @{ volume = 0.5 }
    # Rewrite the config file so volume is last (no trailing comma)
    $minimalJson = '{ "default_pack": "peon", "enabled": true, "volume": 0.5 }'
    Set-Content $script:env.ConfigPath -Value $minimalJson -Encoding UTF8

    Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--volume" -Arg1 "0.3"
    $script:LastPeonExitCode | Should -Be 0

    # Must parse as valid JSON
    $raw = Get-Content $script:env.ConfigPath -Raw
    $raw | Should -Not -Match ',\s*}'
    $parsed = $raw | ConvertFrom-Json
    $parsed.volume | Should -Be 0.3
}
```

The test should be committed before or alongside the production fix.
