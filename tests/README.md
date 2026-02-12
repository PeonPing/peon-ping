# peon-ping Tests

This directory contains test suites for all platforms.

## Test Frameworks

- **Unix/Linux/macOS**: [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System)
- **Windows**: PowerShell test script

## Running Tests

### Unix/Linux/macOS (BATS)

**Prerequisites:**
```bash
# Install BATS
# macOS:
brew install bats-core

# Linux (Ubuntu/Debian):
sudo apt-get install bats

# Or install from source:
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

**Run tests:**
```bash
# All tests
bats tests/

# Specific test file
bats tests/install.bats
bats tests/peon.bats

# Verbose output
bats -t tests/
```

### Windows (PowerShell)

**Prerequisites:**
- PowerShell 5.1+ (built into Windows 10/11)
- Python 3.7+

**Run tests:**
```powershell
# From project root
powershell -ExecutionPolicy Bypass -File tests\test-windows.ps1

# Or from tests directory
cd tests
powershell -ExecutionPolicy Bypass -File .\test-windows.ps1

# Remote (test before installing)
irm https://raw.githubusercontent.com/tonyyont/peon-ping/main/tests/test-windows.ps1 | iex
```

## Test Files

### Unix Tests (BATS)

- **`install.bats`** (8 tests) - Tests for install.sh
  - Fresh install creates all expected files
  - Sound files are copied
  - Hooks registered in settings.json
  - VERSION file created
  - Config preserved on update
  - Executable permissions
  - Completions installed

- **`peon.bats`** (60+ tests) - Tests for peon.sh
  - Event routing (SessionStart, Stop, Notification, etc.)
  - Sound playback
  - Category filtering
  - Pause/resume functionality
  - Pack switching
  - Agent detection
  - State management

- **`setup.bash`** - Shared test utilities and mocks

### Windows Tests (PowerShell)

- **`test-windows.ps1`** (15 tests) - Complete Windows test suite
  - Python installation
  - Claude Code directory
  - PowerShell version
  - .NET assemblies (MediaPlayer, WinForms)
  - Installation files
  - Config validity
  - Sound packs
  - Hooks registration
  - PowerShell profile
  - peon command functionality

## Test Coverage

### Installation Tests
- ✅ Fresh install
- ✅ Update (preserves config)
- ✅ File permissions
- ✅ Settings.json hooks
- ✅ Sound files
- ✅ Shell integration

### Functionality Tests
- ✅ Event handling (SessionStart, Stop, Notification, PermissionRequest)
- ✅ Sound playback
- ✅ Pack switching
- ✅ Pause/resume
- ✅ Category filtering
- ✅ Agent detection
- ✅ State persistence

### Platform-specific
- ✅ Unix: afplay integration, osascript notifications
- ✅ Windows: MediaPlayer, WinForms notifications
- ✅ WSL: PowerShell.exe calls

## CI/CD

The BATS tests can be run in GitHub Actions:

```yaml
- name: Run tests
  run: |
    # Install BATS
    git clone https://github.com/bats-core/bats-core.git
    cd bats-core
    ./install.sh $HOME/.local
    export PATH="$HOME/.local/bin:$PATH"

    # Run tests
    cd ../tests
    bats .
```

## Adding New Tests

### Unix (BATS)
```bash
@test "description of test" {
  run_peon '{"hook_event_name":"SessionStart",...}'
  [ "$PEON_EXIT" -eq 0 ]
  # assertions...
}
```

### Windows (PowerShell)
```powershell
Test-Item "description of test" {
    try {
        # test code
        $result -eq $expected
    } catch {
        $false
    }
}
```

## Debugging

### BATS
```bash
# Show command output
bats -t tests/

# Run single test
bats -f "test name pattern" tests/peon.bats
```

### PowerShell
```powershell
# Run with verbose output already enabled in the script
# Check individual test failures in the summary
```
