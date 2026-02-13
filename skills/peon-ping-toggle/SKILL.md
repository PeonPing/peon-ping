---
name: peon-ping-toggle
description: Toggle peon-ping sound notifications on/off. Use when user wants to mute, unmute, pause, or resume peon sounds during a Claude Code session. Also handles config changes like volume, pack rotation, categories — any peon-ping setting.
user_invocable: true
---

# peon-ping-toggle

Toggle peon-ping sounds on or off. Also handles any peon-ping configuration changes.

## Toggle sounds

Run the following command using the Bash tool:

```bash
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/peon.sh toggle
```

Report the output to the user. The command will print either:
- `peon-ping: sounds paused` — sounds are now muted
- `peon-ping: sounds resumed` — sounds are now active

## Configuration changes

For any other peon-ping setting changes (volume, pack rotation, categories, active pack, etc.), use the `peon-ping-config` skill.
