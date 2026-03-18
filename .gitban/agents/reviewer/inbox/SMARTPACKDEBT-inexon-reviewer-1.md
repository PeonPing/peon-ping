---
verdict: REJECTION
card_id: inexon
review_number: 1
commit: 4126d41152221fd6db1a3fadb6fbf2e4b2c99024
date: 2026-03-15
has_backlog_items: true
---

## BLOCKERS

### B1: Runtime path_rules matching engine deleted -- bind/unbind commands write dead config

The entire runtime `path_rules` matching engine (the block that evaluates `$event.cwd` against `$config.path_rules` during event processing to select a pack) has been removed from the hook script. Previously this code lived between "Pick a sound" and the `pack_rotation` logic:

```powershell
# --- Path rules: first glob match wins (layer 3 in override hierarchy) ---
$pathRulePack = $null
$eventCwd = $event.cwd
if ($eventCwd -and $config.path_rules) {
    foreach ($rule in $config.path_rules) { ... }
}
```

And the `$pathRulePack` variable was checked in the fallback chain (`elseif ($pathRulePack)`).

All of this is gone. The bind/unbind/bindings CLI commands still write `path_rules` entries to `config.json`, but those entries are never read at runtime. This means the feature is visually present (users can bind packs to directories) but functionally broken (the bindings have zero effect on which pack plays). `peon.sh` still has the full runtime matching engine with 15 references to `path_rules`.

**Refactor plan:** Restore the runtime `path_rules` matching block in the event-handling section of the hook script. It should sit after `$activePack = $config.active_pack` and before the `pack_rotation` elseif, consistent with `peon.sh`. The `elseif ($pathRulePack)` branch in the fallback chain must also be restored.

### B2: `--status` no longer shows path_rules info

The `--status` command previously displayed active path rule or path rule count. This was removed entirely rather than refactored to use `Update-PeonConfig`. The old behavior:

```
peon-ping: ENABLED | pack: peon | volume: 0.5
peon-ping: active path rule: */myproject/* -> sc_kerrigan
```

Now it only shows the first line. The test that validated this (`"status shows path rules count"`) was also removed from the test file. Since the card scope is "bind/unbind/bindings quality improvements", removing status output for path_rules is a regression.

**Refactor plan:** Restore path_rules display in `--status`. It can optionally use `Update-PeonConfig` for the read, or simply read `$cfg.path_rules` directly as it did before (read-only, no mutation needed).

### B3: Out-of-scope removal of `Get-ActivePack` and `default_pack` breaks cross-platform parity

The card scope is: "bind/unbind CLI quality improvements (extract Update-PeonConfig helper, add progress feedback)." The commit removes `Get-ActivePack` entirely and renames all `default_pack` references to `active_pack` throughout `install.ps1`. This is a breaking behavioral change:

1. `peon.sh` still uses `default_pack` as the primary config key (25 references). The two platforms now expect different config keys, breaking users who share config across WSL2 and native Windows.
2. The `Get-ActivePack` fallback chain (`default_pack` -> `active_pack` -> `"peon"`) provided backward compatibility for configs created under older versions. The replacement (`$config.active_pack` with inline `if (-not $activePack) { $activePack = "peon" }`) loses `default_pack` fallback entirely.
3. Fresh installs now write `active_pack` instead of `default_pack` to config.json, diverging from the config schema used by `peon.sh`.

**Refactor plan:** Revert the `Get-ActivePack` removal and `default_pack` -> `active_pack` rename. If a config key migration is desired, it should be a separate card that updates both `peon.sh` and `install.ps1` simultaneously with a migration path for existing configs.

### B4: Out-of-scope removal of Write-StateAtomic PS 7+ branch and Read-StateWithRetry orphan cleanup

Two state I/O hardening features from a parallel card (exg19y) were removed:

1. `Write-StateAtomic` lost its PS 7+ branch that used `Move-Item -Force` for true atomic overwrite. The code was simplified to always use the PS 5.1 delete-then-move path.
2. `Read-StateWithRetry` lost its orphaned `.tmp` file cleanup logic that guards against partial writes left behind by the safety timer's `[Environment]::Exit(1)`.

These were unrelated to bind/unbind quality and appear to be merge conflict resolution errors where the wrong side was kept.

**Refactor plan:** Restore the PS 7+ branch in `Write-StateAtomic` and the orphaned `.tmp` cleanup in `Read-StateWithRetry`. These came from card exg19y and should not have been reverted.

### B5: Out-of-scope removal of ffmpeg/ffplay install guidance

The commit reduces ffmpeg install guidance from 5 lines (recommending choco as preferred, warning about winget PATH issue) to a single `winget install ffmpeg` line. The tests that validated this (`"recommends choco as preferred ffmpeg install method"` and `"warns about winget ffplay PATH issue"`) were also removed. This came from card ji2847 and should not have been reverted.

**Refactor plan:** Restore the choco recommendation and winget PATH warning. These came from card ji2847 and should not have been removed in this merge.

### B6: Functional E2E tests replaced with unit-level isolation tests

The previous test suite had true end-to-end tests that extracted the embedded hook script, wrote it to disk, and invoked it via `powershell.exe -NoProfile -Command` to exercise the real bind/unbind/bindings codepaths. The new "E2E" tests in `Describe "Embedded peon.ps1 Bind --install E2E"` redefine `Update-PeonConfig` locally in the test scope and call it directly -- they never exercise the actual embedded hook script.

This means the tests verify that the helper pattern works in isolation, but do not verify that the hook script's bind/unbind commands actually call `Update-PeonConfig` correctly, parse flags properly, or produce the right user-facing output. The old tests caught all of those.

**Refactor plan:** Restore the functional tests that invoke the extracted hook script via `powershell.exe`. The new structural tests (checking for regex matches in source) and the isolated helper tests can remain as supplements, but the functional tests are the ones that catch real integration issues.

## BACKLOG

### L1: Repeated `if (-not $activePack) { $activePack = "peon" }` pattern

After the removal of `Get-ActivePack`, the inline fallback `if (-not $activePack) { $activePack = "peon" }` appears 5 times in the hook script. If `Get-ActivePack` is restored (per B3), this is moot. If not, a small helper or single-assignment pattern should replace the duplication.

### L2: `Update-PeonConfig` unconditionally writes even when mutator makes no changes

The helper always writes back to disk after calling the mutator, even if nothing changed (e.g., unbind when no matching rule exists). For a CLI command this is harmless, but if ever used in the hot path it would cause unnecessary disk I/O. Consider having the mutator return a changed flag or comparing before/after.
