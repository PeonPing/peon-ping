---
name: peon-ping-toggle
description: Toggle peon-ping sound notifications on/off. Use when user wants to mute, unmute, pause, or resume peon sounds during a Claude Code session.
user_invocable: true
---

# peon-ping-toggle

Toggle peon-ping sounds on or off.

## Instructions

Detect the platform and run the appropriate command using the Bash tool:

**On Windows (detect by checking if `$OSTYPE` contains "msys" or "win", or if `$USERPROFILE` is set):**

```bash
powershell.exe -ExecutionPolicy Bypass -Command "$USERPROFILE\\.claude\\hooks\\peon-ping\\peon.ps1 --toggle"
```

**On Unix (macOS/Linux/WSL):**

```bash
bash ~/.claude/hooks/peon-ping/peon.sh --toggle
```

### Platform Detection

To detect the platform:
1. Check if `$USERPROFILE` environment variable is set (Windows)
2. Or check if `$OSTYPE` contains "msys", "win", or "cygwin" (Windows)
3. Otherwise assume Unix (macOS/Linux/WSL)

### Output

Report the output to the user. The command will print either:
- `peon-ping: sounds paused` - sounds are now muted
- `peon-ping: sounds resumed` - sounds are now active

If the command fails, inform the user that peon-ping may not be installed correctly.
