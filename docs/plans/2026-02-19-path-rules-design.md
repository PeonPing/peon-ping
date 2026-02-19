# Design: path_rules + Override Hierarchy Cleanup

**Date:** 2026-02-19
**Scope:** peon-ping CLI (`peon.sh`, `config.json`, `peon update` migration)

---

## Problem

There is no way to assign a specific sound pack to a project/repo automatically. The workarounds are:
- Drop a `config.json` in `${PWD}/.claude/hooks/peon-ping/` (manual, per-repo file)
- Use `/peon-ping-use <pack>` each session (ephemeral, not persistent)

Also, two existing config keys have misleading names:
- `active_pack` sounds like the currently-playing pack, but it's just the global fallback
- `agentskill` (rotation mode) names the mechanism (a skill) not the behavior (per-session override)

---

## Design

### Override Hierarchy

From most to least authoritative. Each layer is only consulted if all layers above it produce no result.

| Layer | Mechanism | Scope | Persistence |
|---|---|---|---|
| 1. `session_override` | `/peon-ping-use <pack>` | Current session | Expires with session |
| 2. Local config | `${PWD}/.claude/hooks/peon-ping/config.json` | Exact directory | Until file is removed |
| 3. `path_rules` | Glob-matched against `cwd` | Matched paths | Until config changes |
| 4. `pack_rotation` | `random` or `round-robin` | All sessions globally | Until config changes |
| 5. `default_pack` | Global fallback | All sessions globally | Until config changes |

**Philosophy:** more specific and more immediate beats more general. A temporary in-session choice (`session_override`) beats a standing rule (`path_rules`), which beats a global default. `path_rules` is a floor for matched repos, not a ceiling — you can always escape it for a session.

---

### Config Schema Changes

#### New: `path_rules`

Array of objects. First match wins. Evaluated against `cwd` using Python `fnmatch` (glob-style).

```json
"path_rules": [
  { "pattern": "*/peonping-repos/*", "pack": "peon" },
  { "pattern": "*/work/clients/*",   "pack": "glados" }
]
```

- Patterns use glob syntax (`*`, `?`, `[seq]`)
- First matching rule wins; remaining rules are not evaluated
- If matched pack is not installed, falls through to next layer
- `rotation` per rule is not supported (YAGNI)

#### Renamed: `active_pack` → `default_pack`

`active_pack` was misleading — it implied the currently-playing pack, not the fallback. `default_pack` reflects its role as the baseline when nothing more specific matches.

#### Renamed: `agentskill` mode → `session_override` mode

The `pack_rotation_mode` value `"agentskill"` named the mechanism (a Claude Code skill). `"session_override"` names the behavior (pack is overridden per session via explicit assignment).

---

### Migration (via `peon update`)

Both renames are handled automatically during `peon update`:

1. If `active_pack` exists and `default_pack` does not → rename key in-place
2. If `pack_rotation_mode` is `"agentskill"` → rewrite to `"session_override"`
3. Write updated config back to disk

During the transition window, the runtime reads both old and new key names (new preferred, old as fallback). This ensures configs not yet migrated continue to work.

---

### Matching Logic

Inserted in `peon.sh` Python block after config load and `cwd` extraction, before the rotation/default block. Only runs if `session_override` mode has not already assigned a pack.

```python
import fnmatch
for rule in cfg.get('path_rules', []):
    if cwd and fnmatch.fnmatch(cwd, rule.get('pattern', '')):
        candidate = rule.get('pack', '')
        if candidate and os.path.isdir(os.path.join(peon_dir, 'packs', candidate)):
            active_pack = candidate
            break  # first match wins
```

---

### CLI / UX

- `peon status` should show active path rule when one is matched (e.g. `path rule: */peonping-repos/* → peon`)
- `peon config set path_rules ...` is out of scope — JSON arrays are awkward to set via CLI; users edit `config.json` directly
- README and `peon help` should document `path_rules` alongside `pack_rotation`

---

## Out of Scope

- Per-path rotation (`"rotation": [...]` in a rule)
- `path_rules` inside local project config (redundant — local config already scopes to that exact directory)
- A dedicated `peon path-rules` subcommand

---

## Files Affected

| File | Change |
|---|---|
| `peon.sh` | Add path_rules matching logic; rename `agentskill` → `session_override`; read `default_pack` with `active_pack` fallback; `peon update` migration; `peon status` output |
| `config.json` | Rename `active_pack` → `default_pack`; add `"path_rules": []` |
| `README.md` | Document `path_rules`, `default_pack`, `session_override` mode |
| `README_zh.md` | Mirror README changes |
| `docs/public/llms.txt` | Update config key references |
| `tests/peon.bats` | Tests for path_rules matching, migration, fallthrough |
