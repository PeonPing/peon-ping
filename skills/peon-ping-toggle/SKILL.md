---
name: peon-ping-toggle
description: Toggle peon-ping sound notifications on/off. Use when user wants to mute, unmute, pause, or resume peon sounds during a Claude Code session.
user_invocable: true
---

# peon-ping-toggle

Toggle peon-ping sounds on or off.

Run the appropriate command using the Bash tool based on the user's platform:

- **Windows**: `python ~/.claude/hooks/peon-ping/peon.py --toggle`
- **macOS / WSL / Linux**: `bash ~/.claude/hooks/peon-ping/peon.sh --toggle`

Report the output to the user. The command will print either:
- `peon-ping: sounds paused` — sounds are now muted
- `peon-ping: sounds resumed` — sounds are now active
