Activate your venv first: `.\.venv\Scripts\Activate.ps1`

The code for the gitban card with id lxhqpf has been REJECTED at commit fa135b7 due to one blocker. Please implement the mandatory fix below, then request re-review.

===BEGIN REFACTORING INSTRUCTIONS===

**B1: Add peon-adapters.Tests.ps1 to CI workflow.**

The new test file `tests/peon-adapters.Tests.ps1` (48 tests) is not listed in `.github/workflows/test.yml`. Line 55 currently has:

```
$config.Run.Path = @("tests/adapters-windows.Tests.ps1", "tests/peon-engine.Tests.ps1")
```

Add `"tests/peon-adapters.Tests.ps1"` to the `$config.Run.Path` array so it becomes:

```
$config.Run.Path = @("tests/adapters-windows.Tests.ps1", "tests/peon-engine.Tests.ps1", "tests/peon-adapters.Tests.ps1")
```

This is a one-line change. Without it, the 48 new tests provide zero regression protection in CI.

===END REFACTORING INSTRUCTIONS===
