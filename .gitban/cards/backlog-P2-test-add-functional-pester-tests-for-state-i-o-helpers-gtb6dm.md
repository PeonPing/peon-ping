# Test Implementation Card

**When to use this template:** Use this when you need to add, improve, or verify test coverage for any part of the system.

---

## Test Overview

**Test Type:** Integration

**Target Component:** `Write-StateAtomic` and `Read-StateWithRetry` functions in the embedded `peon.ps1` hook script (inside `install.ps1`)

**Related Cards:** exg19y (harden Windows atomic state I/O), lyq5ta (state helper DRY-up), 26yooi (upgrade Write-StateAtomic to true atomic overwrite)

**Coverage Goal:** Functional runtime coverage of state I/O helpers — verify `.tmp` file cleanup, retry logic, and atomic write behavior rather than relying solely on structural regex tests.

---

## Test Strategy

### Test Pyramid Placement

| Layer | Tests Planned | Rationale |
|-------|---------------|-----------|
| Unit | N/A | State helpers are tightly coupled to file I/O |
| Integration | 3-5 | Functional tests that exercise real file operations |
| E2E | N/A | Not needed for isolated helper functions |
| Performance | N/A | Not a performance concern |

### Testing Approach
- **Framework:** Pester (PowerShell testing framework)
- **Mocking Strategy:** Use real temp directories for file I/O; mock only external dependencies if needed. Tests should create actual `.tmp` and `.state.json` files.
- **Isolation Level:** Full isolation — each test gets its own temp directory, cleaned up in AfterEach.

---

## Test Scenarios

### Scenario 1: Write-StateAtomic creates state file and cleans up tmp
- **Given:** An empty temp directory with no `.state.json`
- **When:** `Write-StateAtomic` is called with valid JSON content
- **Then:** `.state.json` exists with correct content; no `.tmp` files remain in the directory
- **Priority:** Critical

### Scenario 2: Read-StateWithRetry removes stale .tmp files
- **Given:** A temp directory containing a stale `.tmp` file alongside a valid `.state.json`
- **When:** `Read-StateWithRetry` is called
- **Then:** The `.tmp` file is removed and valid state JSON is returned
- **Priority:** High

### Scenario 3: Read-StateWithRetry handles missing state file gracefully
- **Given:** A temp directory with no `.state.json` file
- **When:** `Read-StateWithRetry` is called
- **Then:** Returns default/empty state without error
- **Priority:** High

### Scenario 4: Write-StateAtomic handles concurrent write safely
- **Given:** A temp directory with an existing `.state.json`
- **When:** `Write-StateAtomic` is called to overwrite with new content
- **Then:** Final `.state.json` contains the new content; no `.tmp` files remain
- **Priority:** Medium

---

## Test Data & Fixtures

### Required Test Data
| Data Type | Description | Source |
|-----------|-------------|--------|
| State JSON | Valid `.state.json` with session and pack data | Inline fixture |
| Stale tmp | A `.state.json.tmp` file left from interrupted write | Created in test setup |
| Empty dir | Clean temp directory | `New-Item -ItemType Directory` in BeforeEach |

### Edge Case Data
- **Empty/Null:** Empty `.state.json` file (0 bytes)
- **Maximum Values:** Large JSON state (unlikely to matter, skip)
- **Invalid Formats:** Corrupted JSON in `.state.json`
- **Unicode/Special Chars:** N/A for state files

### Fixture Setup
```powershell
BeforeEach {
    $testDir = Join-Path $TestDrive "state-io-test"
    New-Item -Path $testDir -ItemType Directory -Force
}
AfterEach {
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
}
```

---

## Implementation Checklist

### Setup Phase
- [ ] Test file[s] created in correct location (`tests/adapters-windows.Tests.ps1` or new dedicated file)
- [ ] Test fixtures/factories defined
- [ ] Mocks and stubs configured
- [ ] Test database/state initialized [if needed]

### Test Implementation
- [ ] Happy path tests written and passing (Scenario 1: write + cleanup)
- [ ] Edge case tests written and passing (Scenario 4: overwrite)
- [ ] Error handling tests written and passing (Scenario 3: missing file)
- [ ] Negative/security tests written and passing (Scenario 2: stale tmp cleanup)
- [ ] Performance assertions added [if applicable]

### Quality Gates
- [ ] All tests pass locally
- [ ] All tests pass in CI (Windows runner)
- [ ] No flaky tests introduced
- [ ] Test execution time acceptable
- [ ] Code coverage meets target [if applicable]

### Documentation
- [ ] Test file has clear docstrings/comments
- [ ] Complex test logic explained
- [ ] Setup/teardown documented

---

## Acceptance Criteria

- [ ] All planned scenarios have corresponding tests
- [ ] Tests are deterministic [no flakiness]
- [ ] Tests run in isolation [no order dependency]
- [ ] Tests are fast enough for CI [<10 seconds total]
- [ ] Coverage target met: Write-StateAtomic and Read-StateWithRetry both have functional (not just regex) test coverage
- [ ] Tests follow project conventions (Pester v5 style, consistent with existing `adapters-windows.Tests.ps1`)

---

## Troubleshooting Log (optional)

| Issue | Investigation | Resolution |
|-------|---------------|------------|
| | | |

---

## Notes

- The current Pester tests for state I/O are structural only (regex matching against embedded hook script). This card adds functional tests that actually exercise the file operations at runtime.
- Coordinate with card lyq5ta (state helper DRY-up) which may introduce a shared module, changing where these helpers live. If lyq5ta lands first, tests should target the extracted module instead.
- Coordinate with card exg19y (harden Windows atomic state I/O) which may change the implementation of these helpers.
