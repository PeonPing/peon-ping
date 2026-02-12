# peon-ping

![macOS](https://img.shields.io/badge/macOS-blue) ![Windows](https://img.shields.io/badge/Windows-blue) ![WSL2](https://img.shields.io/badge/WSL2-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Claude Code](https://img.shields.io/badge/Claude_Code-hook-ffab01)

**Your Peon pings you when Claude Code needs attention.**

Claude Code doesn't notify you when it finishes or needs permission. You tab away, lose focus, and waste 15 minutes getting back into flow. peon-ping fixes this with Warcraft III Peon voice lines — so you never miss a beat, and your terminal sounds like Orgrimmar.

**See it in action** → [peon-ping.vercel.app](https://peon-ping.vercel.app/)

## Install

### macOS / Linux / WSL2

```bash
curl -fsSL https://raw.githubusercontent.com/tonyyont/peon-ping/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/tonyyont/peon-ping/main/install.ps1 | iex
```

One command. Takes 10 seconds. Re-run to update (sounds and config preserved).

### Test before installing (Windows)

Check if your system meets all requirements:

```powershell
irm https://raw.githubusercontent.com/tonyyont/peon-ping/main/test-windows.ps1 | iex
```

### Manual installation from local clone

**macOS / Linux / WSL2:**
```bash
cd peon-ping
bash ./install.sh
```

**Windows:**
```powershell
cd peon-ping
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## What you'll hear

| Event | Sound | Examples |
|---|---|---|
| Session starts | Greeting | *"Ready to work?"*, *"Yes?"*, *"What you want?"* |
| Task finishes | Acknowledgment | *"Work, work."*, *"I can do that."*, *"Okie dokie."* |
| Permission needed | Alert | *"Something need doing?"*, *"Hmm?"*, *"What you want?"* |
| Rapid prompts (3+ in 10s) | Easter egg | *"Me busy, leave me alone!"* |

Plus Terminal tab titles (`● project: done`) and desktop notifications when your terminal isn't focused.

**Windows notifications** appear as custom colored popups centered on all screens:
- **Blue**: Task complete
- **Red**: Permission needed
- **Yellow**: Waiting for input

## Quick controls

Need to mute sounds and notifications during a meeting or pairing session? Two options:

| Method | Command | When |
|---|---|---|
| **Slash command** | `/peon-ping-toggle` | While working in Claude Code |
| **CLI** | `peon --toggle` | From any terminal tab |

Other CLI commands:

```bash
peon --pause          # Mute sounds
peon --resume         # Unmute sounds
peon --status         # Check if paused or active
peon --packs          # List available sound packs
peon --pack <name>    # Switch to a specific pack
peon --pack           # Cycle to the next pack
```

**Note:** Tab completion is supported on Unix systems. Windows users: after install, restart your PowerShell terminal to use the `peon` command.

Pausing mutes sounds and desktop notifications instantly. Persists across sessions until you resume. Tab titles remain active when paused.

## Configuration

Edit the config file:
- **Unix**: `~/.claude/hooks/peon-ping/config.json`
- **Windows**: `%USERPROFILE%\.claude\hooks\peon-ping\config.json`

```json
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "greeting": true,
    "acknowledge": true,
    "complete": true,
    "error": true,
    "permission": true,
    "resource_limit": true,
    "annoyed": true
  },
  "annoyed_threshold": 3,
  "annoyed_window_seconds": 10,
  "pack_rotation": []
}
```

- **volume**: 0.0–1.0 (quiet enough for the office)
- **categories**: Toggle individual sound types on/off
- **annoyed_threshold / annoyed_window_seconds**: How many prompts in N seconds triggers the easter egg
- **pack_rotation**: Array of pack names (e.g. `["peon", "sc_kerrigan", "peasant"]`). Each Claude Code session randomly gets one pack from the list and keeps it for the whole session. Leave empty `[]` to use `active_pack` instead.

## Sound packs

| Pack | Character | Sounds | By |
|---|---|---|---|
| `peon` (default) | Orc Peon (Warcraft III) | "Ready to work?", "Work, work.", "Okie dokie." | [@tonyyont](https://github.com/tonyyont) |
| `peon_fr` | Orc Peon (Warcraft III, French) | "Prêt à travailler?", "Travail, travail.", "D'accord." | [@thomasKn](https://github.com/thomasKn) |
| `peon_pl` | Orc Peon (Warcraft III, Polish) | Polish voice lines | [@askowronski](https://github.com/askowronski) |
| `peasant` | Human Peasant (Warcraft III) | "Yes, milord?", "Job's done!", "Ready, sir." | [@thomasKn](https://github.com/thomasKn) |
| `peasant_fr` | Human Peasant (Warcraft III, French) | "Oui, monseigneur?", "C'est fait!", "Prêt, monsieur." | [@thomasKn](https://github.com/thomasKn) |
| `ra2_soviet_engineer` | Soviet Engineer (Red Alert 2) | "Tools ready", "Yes, commander", "Engineering" | [@msukkari](https://github.com/msukkari) |
| `sc_battlecruiser` | Battlecruiser (StarCraft) | "Battlecruiser operational", "Make it happen", "Engage" | [@garysheng](https://github.com/garysheng) |
| `sc_kerrigan` | Sarah Kerrigan (StarCraft) | "I gotcha", "What now?", "Easily amused, huh?" | [@garysheng](https://github.com/garysheng) |

Switch packs from the CLI:

```bash
peon --pack ra2_soviet_engineer   # switch to a specific pack
peon --pack                       # cycle to the next pack
peon --packs                      # list all packs
```

Want to add your own pack? See [CONTRIBUTING.md](CONTRIBUTING.md).

## Requirements

### All platforms
- **Claude Code** with hooks support
- **Python 3.7+** (Python 3 on Unix, Python or Python 3 on Windows)

### Platform-specific

**macOS:**
- `afplay` for audio (built into macOS)
- AppleScript for notifications (built into macOS)

**Windows:**
- Windows 10/11
- PowerShell 5.1+ (built into Windows)
- `System.Windows.Media.MediaPlayer` for audio
- `System.Windows.Forms` for notifications

**WSL2:**
- `powershell.exe` (available in WSL)
- `wslpath` (built into WSL)
- Calls Windows audio and notification APIs from Linux

## Troubleshooting

### Windows: "python is not recognized"

Install Python from:
- [python.org](https://www.python.org/downloads/) (check "Add Python to PATH")
- Microsoft Store: `winget install Python.Python.3.12`

### Windows: "peon command not found"

The `peon` function is added to your PowerShell profile. Either:
1. Restart your PowerShell terminal, or
2. Reload your profile: `. $PROFILE`

### Windows: ExecutionPolicy errors

If you get "cannot be loaded because running scripts is disabled":

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

This allows local scripts to run while protecting against remote unsigned scripts.

### All platforms: Audio not playing

1. Check your system volume is not muted
2. Test with: `peon --toggle` (toggle twice to test)
3. Verify sound files exist:
   - **Unix**: `~/.claude/hooks/peon-ping/packs/peon/sounds/`
   - **Windows**: `%USERPROFILE%\.claude\hooks\peon-ping\packs\peon\sounds\`

### All platforms: Sounds play but no notifications

Check if your terminal is in focus. Notifications only appear when the terminal is NOT focused (to avoid distraction during active work).

## Uninstall

### macOS / Linux / WSL2

```bash
bash ~/.claude/hooks/peon-ping/uninstall.sh
```

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\peon-ping\uninstall.ps1"
```

The uninstaller will:
- Remove all peon-ping files
- Clean up hooks from settings.json
- Remove shell aliases/functions
- Optionally restore any backed-up notify.sh

## How it works

`peon.sh` (Unix) / `peon.ps1` (Windows) is a Claude Code hook registered for `SessionStart`, `UserPromptSubmit`, `Stop`, and `Notification` events.

On each event it:
1. Maps the event to a sound category
2. Picks a random voice line (avoiding recent repeats)
3. Plays audio via platform-native APIs:
   - **macOS**: `afplay`
   - **Windows**: `System.Windows.Media.MediaPlayer`
   - **WSL2**: PowerShell MediaPlayer via `powershell.exe`
4. Updates your terminal tab title
5. Shows desktop notification if terminal is not in focus

Sound files are property of their respective publishers (Blizzard Entertainment, EA) and are included in the repo for convenience.

## Links

- [Landing page](https://peon-ping.vercel.app/)
- [License (MIT)](LICENSE)
- [Contributing guidelines](CONTRIBUTING.md)
