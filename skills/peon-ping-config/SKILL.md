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
- **pack_rotation_mode** (string): `"random"` (default) picks a random pack each session. `"round-robin"` cycles through in order.
- **categories** (object): Toggle individual CESP sound categories:
  - `session.start`, `task.acknowledge`, `task.complete`, `task.error`, `input.required`, `resource.limit`, `user.spam` — each a boolean
- **annoyed_threshold** (number): How many rapid prompts trigger user.spam sounds
- **annoyed_window_seconds** (number): Time window for the annoyed threshold
- **silent_window_seconds** (number): Suppress task.complete sounds for tasks shorter than this many seconds

## How to update

1. Read the config file using the Read tool
2. Edit the relevant field(s) using the Edit tool
3. Confirm the change to the user

## List available packs

To show available packs, run:

```bash
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/peon.sh packs list
```
