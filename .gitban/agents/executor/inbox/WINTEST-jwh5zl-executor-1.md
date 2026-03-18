Activate your venv first: `.\.venv\Scripts\Activate.ps1`

The code for the gitban card with id jwh5zl has been REJECTED with one blocker. Fix the blocker and resubmit for review.

===BEGIN REFACTORING INSTRUCTIONS===

**B1: Scenarios 1 and 7 assert `"agentskill"` but the source sets `"session_override"`.**

`hook-handle-use.ps1` line 137 sets `pack_rotation_mode` to `"session_override"`:

```powershell
$config | Add-Member -NotePropertyName "pack_rotation_mode" -NotePropertyValue "session_override" -Force
```

But the tests assert a different value:

- Scenario 1 (line 152): `$config.pack_rotation_mode | Should -Be "agentskill"`
- Scenario 7 (line 222): `$config.pack_rotation_mode | Should -Be "agentskill"`

**Fix:** Replace `"agentskill"` with `"session_override"` on lines 152 and 222 of `tests/peon-security.Tests.ps1`.

After fixing, re-run the tests to confirm all 16 pass:
```powershell
Invoke-Pester -Path tests/peon-security.Tests.ps1
```
