# Hook Logging Test Fixtures

Shared test fixtures for validating structured hook logging output across platforms
(BATS on Unix, Pester on Windows).

## Format

Each scenario has two files:

- `<name>.input.json` -- JSON event piped to stdin of peon.sh / peon.ps1
- `<name>.expected.txt` -- Expected log phases and key fields

### Expected File Convention

Each line in `.expected.txt` represents a phase tag and the key=value fields that
MUST appear in the corresponding log line. Values set to empty (`key=`) are treated
as wildcards -- the key must be present but its value is not checked. Non-empty values
must match exactly.

Tests parse expected files line-by-line, extracting the `[phase]` tag and required
fields, then grep the actual log output for matching lines.

## Scenarios

| Fixture | Scenario |
|---------|----------|
| `stop-normal` | Normal Stop event -- all 9 phases emitted |
| `delegate-mode` | PermissionRequest with dangerouslySkipPermissions -- suppressed |
| `debounce` | Second Stop within 5s -- debounce suppression |
| `paused` | Stop while paused -- paused suppression |
| `missing-pack` | Stop with non-existent pack -- sound error path |
| `cwd-with-spaces` | Stop with spaces in cwd -- value quoting |

## Adding Fixtures

When adding a new scenario:

1. Create `<name>.input.json` with the hook event JSON
2. Create `<name>.expected.txt` with expected phase lines
3. Add a BATS test in `tests/peon.bats` that uses `validate_log_fixture`
4. Add equivalent Pester test when Windows logging is implemented (Phase 2)
