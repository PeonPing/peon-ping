---
name: peon-ping-toggle
description: Toggle peon-ping sound notifications on/off. Use when user wants to mute, unmute, pause, or resume peon sounds during a Claude Code session. Also handles config changes like volume, pack rotation, categories — any peon-ping setting.
user-invocable: true
---

# peon-ping-toggle

Toggle peon-ping sounds on or off. Also handles any peon-ping configuration changes.

## Toggle sounds

On Unix, run the following command using the Bash tool:

```bash
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/peon.sh toggle
```

On Windows, use the PowerShell tool:
```powershell
$claudeDir = $env:CLAUDE_CONFIG_DIR
if (-not $claudeDir -or $claudeDir -eq "") {
  $claudeDir = Join-Path $HOME ".claude"
}
& (Join-Path $claudeDir "hooks/peon-ping/peon.ps1") toggle
```

Report the output to the user. The command will print either:
- `peon-ping: sounds paused` — sounds are now muted
- `peon-ping: sounds resumed` — sounds are now active

## What This Toggles

This command toggles the **master audio switch** (`enabled` config). When disabled:
- ❌ Sounds stop playing
- ❌ Desktop notifications also stop (they require sounds to be enabled)
- ❌ Mobile notifications also stop

**For notification-only control**, use `/peon-ping-config` to set `desktop_notifications: false`. This keeps sounds playing while suppressing desktop popups.

## Examples

"Mute peon-ping completely" → Sets `enabled: false`
"Just disable the popups but keep sounds" → Sets `desktop_notifications: false` (use `/peon-ping-config` instead)

## Configuration changes

For any other peon-ping setting changes (volume, pack rotation, categories, active pack, etc.), use the `peon-ping-config` skill.
