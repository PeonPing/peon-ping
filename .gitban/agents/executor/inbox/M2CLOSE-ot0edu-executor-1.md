Use `.venv/Scripts/python.exe` to run Python commands.

===BEGIN REFACTORING INSTRUCTIONS===

### B1: Two Pester tests fail on CI due to `Start-Process` race condition

**Tests:** "uses project name when no template configured" and "renders all 5 template variables correctly" both produce an empty `$notifyLog`, meaning the `Start-Process powershell.exe ... win-notify.ps1` child process did not finish writing `.notify-log.txt` before the test read it.

**Root cause:** The hook dispatches notifications via `Start-Process -WindowStyle Hidden`, which spawns an asynchronous child `powershell.exe`. The tests call `Start-Sleep -Milliseconds 500` before reading the log file. On CI (GitHub Actions Windows runner), 500ms is insufficient for PowerShell process startup + script execution + file I/O. The other hook-mode tests pass because they happen to complete within the window -- this is not deterministic and any of them could flake on a loaded runner.

**Why it's non-deterministic:** All 8 hook-mode tests share the exact same sleep/assert pattern. The 2 failures are a sampling artifact of CI load, not a code logic error. This makes the entire hook-mode test suite unreliable, not just these 2 tests.

**Refactor plan:**

Replace the fixed `Start-Sleep -Milliseconds 500` with a polling loop that waits for the log file to appear, with a reasonable timeout (e.g., 5 seconds):

```powershell
# Replace: Start-Sleep -Milliseconds 500
# With:
$deadline = [DateTime]::UtcNow.AddSeconds(5)
$logPath = Join-Path $testDir ".notify-log.txt"
while (-not (Test-Path $logPath) -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 100
}
```

Apply this to all 8 hook-mode tests (tests #6-#10, #12-#14 in the file). This eliminates the race condition entirely: fast machines exit in ~200ms, slow CI runners get up to 5 seconds.

### B2: Design doc specifies `Resolve-NotificationTemplate` as a named function; implementation inlines the logic

The design doc at `docs/designs/win-notification-templates.md` lines 170-218 specifies a `Resolve-NotificationTemplate` function with a clean `-replace '\{(\w+)\}'` scriptblock for variable substitution. The implementation inlines the entire resolution block directly into the hook flow (lines 1898-1937 of `install.ps1`) and replaces the single-line regex substitution with:

1. A `.Replace()` loop over known keys (fine, equivalent)
2. A 20-line character-by-character loop to strip unknown `{word}` placeholders

The executor's summary says this was to "avoid PS 5.1 regex tokenizer issues in here-strings." However, the `-replace` operator with a scriptblock **does** work on PS 5.1 -- it is the standard PS 5.1 pattern for regex replacement with computed values. The design doc was already written with PS 5.1 in mind.

**Impact:** The character-by-character approach is ~20 lines of manual string parsing that replaces a 4-line regex. It is harder to read, harder to maintain, and harder to verify correctness. Additionally, not extracting it into a named function makes unit testing the resolution logic impossible in isolation -- you can only test it through the full hook invocation.

**Refactor plan:**

Extract a `Resolve-NotificationTemplate` function as the design doc specifies. Use the `-replace` scriptblock approach. If the executor has concrete evidence that `-replace` with a scriptblock fails inside the `install.ps1` here-string (a legitimate concern since the here-string uses `@'...'@` single-quoted syntax which doesn't expand variables but does preserve scriptblock syntax), then document that in a code comment explaining the deviation -- but still extract it to a named function for testability.

If `-replace` with scriptblock truly fails in the here-string context, `.Replace()` + a simple regex cleanup is acceptable:

```powershell
# After .Replace() loop for known vars:
$rendered = [regex]::Replace($rendered, '\{(\w+)\}', '')
```

This single line replaces the 20-line character loop.
