---
name: peon-ping-config
description: Update peon-ping configuration — volume, pack rotation, categories, active pack, and other settings. Use when user wants to change peon-ping settings like volume, enable round-robin, add packs to rotation, toggle sound categories, or adjust any config.
user_invocable: false
---

# peon-ping-config

Update peon-ping configuration settings.

## Config location

The config file is at `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping/config.json`.

## Available settings

- **volume** (number, 0.0–1.0): Sound volume
- **active_pack** (string): Current sound pack name (e.g. `"peon"`, `"sc_kerrigan"`, `"glados"`)
- **enabled** (boolean): Master on/off switch
- **pack_rotation** (array of strings): List of packs to rotate through per session. Empty `[]` uses `active_pack` only.
- **pack_rotation_mode** (string): `"random"` (default) picks a random pack each session. `"round-robin"` cycles through in order. `"agentskill"` uses explicit per-session assignments from `/peon-ping-use`; invalid or missing packs fall back to `active_pack` and the stale assignment is removed.
- **categories** (object): Toggle individual CESP sound categories:
  - `session.start`, `task.acknowledge`, `task.complete`, `task.error`, `input.required`, `resource.limit`, `user.spam` — each a boolean
- **annoyed_threshold** (number): How many rapid prompts trigger user.spam sounds
- **annoyed_window_seconds** (number): Time window for the annoyed threshold
- **silent_window_seconds** (number): Suppress task.complete sounds for tasks shorter than this many seconds
- **session_ttl_days** (number, default: 7): Expire stale per-session pack assignments older than N days (when using agentskill mode)
- **desktop_notifications** (boolean): Toggle notification popups independently from sounds (default: `true`)
- **use_sound_effects_device** (boolean): Route audio through macOS Sound Effects device (`true`) or default output via afplay (`false`). Only affects macOS. Default: `true`

## How to update

1. Read the config file using the Read tool
2. Edit the relevant field(s) using the Edit tool
3. Confirm the change to the user

## Common Configuration Examples

### Disable desktop notification popups but keep sounds

**User request:** "Disable desktop notifications"

**Action:**
Set `desktop_notifications: false` in config

**Result:**
- ✅ Sounds continue playing (voice reminders)
- ❌ Desktop notification popups suppressed
- ✅ Mobile notifications unaffected (separate toggle)

**Alternative CLI command:**
```bash
peon notifications off
# or
peon popups off
```

### Adjust volume

**User request:** "Set volume to 30%"

**Action:**
Set `volume: 0.3` in config

### Enable round-robin pack rotation

**User request:** "Enable round-robin pack rotation with peon and glados"

**Action:**
Set:
```json
{
  "pack_rotation": ["peon", "glados"],
  "pack_rotation_mode": "round-robin"
}
```

## Directory pack bindings

Permanently associate a sound pack with a working directory so every session in that directory uses the right pack automatically. Uses the `path_rules` config key (array of `{ "pattern": "<glob>", "pack": "<name>" }` objects).

### CLI commands

```bash
# Bind a pack to the current directory
peon packs bind <pack>
# e.g. peon packs bind glados
# → bound glados to /Users/dan/Frontend

# Bind with a custom glob pattern (matches any dir with that name)
peon packs bind <pack> --pattern "*/Frontend/*"

# Auto-download a missing pack and bind it
peon packs bind <pack> --install

# Remove binding for the current directory
peon packs unbind

# Remove a specific pattern binding
peon packs unbind --pattern "*/Frontend/*"

# List all bindings (* marks rules matching current directory)
peon packs bindings
```

### Manual config

The `path_rules` array in `config.json` can also be edited directly:

```json
{
  "path_rules": [
    { "pattern": "/Users/dan/Frontend/*", "pack": "glados" },
    { "pattern": "*/backend/*", "pack": "sc_kerrigan" }
  ]
}
```

Patterns use Python `fnmatch` glob syntax. First matching rule wins. Path rules override `default_pack` and `pack_rotation` but are overridden by `session_override` (agentskill) assignments.

## List available packs

To show available packs, run:

```bash
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/peon.sh packs list
```
