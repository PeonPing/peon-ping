# peon-ping

![macOS](https://img.shields.io/badge/macOS-blue) ![Linux](https://img.shields.io/badge/Linux-blue) ![WSL2](https://img.shields.io/badge/WSL2-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Claude Code](https://img.shields.io/badge/Claude_Code-hook-ffab01)

**Your Peon pings you when Claude Code needs attention.**

Claude Code doesn't notify you when it finishes or needs permission. You tab away, lose focus, and waste 15 minutes getting back into flow. peon-ping fixes this with Warcraft III Peon voice lines — so you never miss a beat, and your terminal sounds like Orgrimmar.

**See it in action** &rarr; [peon-ping.vercel.app](https://peon-ping.vercel.app/)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tonyyont/peon-ping/main/install.sh | bash
```

One command. Takes 10 seconds. macOS, Linux, and WSL2 (Windows). Re-run to update (sounds and config preserved).

## What you'll hear

| Event | Sound | Examples |
|---|---|---|
| Session starts | Greeting | *"Ready to work?"*, *"Yes?"*, *"What you want?"* |
| Task finishes | Acknowledgment | *"Work, work."*, *"I can do that."*, *"Okie dokie."* |
| Permission needed | Alert | *"Something need doing?"*, *"Hmm?"*, *"What you want?"* |
| Rapid prompts (3+ in 10s) | Easter egg | *"Me busy, leave me alone!"* |

Plus Terminal tab titles (`● project: done`) and desktop notifications when your terminal isn't focused.

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

Tab completion is supported — type `peon --pack <TAB>` to see available pack names.

Pausing mutes sounds and desktop notifications instantly. Persists across sessions until you resume. Tab titles remain active when paused.

## Configuration

Edit `~/.claude/hooks/peon-ping/config.json`:

```json
{
  "volume": 0.5,
  "categories": {
    "greeting": true,
    "acknowledge": true,
    "complete": true,
    "error": true,
    "permission": true,
    "annoyed": true
  }
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

Or edit `~/.claude/hooks/peon-ping/config.json` directly:

```json
{ "active_pack": "ra2_soviet_engineer" }
```

Want to add your own pack? See [CONTRIBUTING.md](CONTRIBUTING.md).

## Uninstall

```bash
bash ~/.claude/hooks/peon-ping/uninstall.sh
```

## Requirements

- **macOS**: uses `afplay` and AppleScript (built-in)
- **Linux**: uses `paplay` (PulseAudio), `aplay` (ALSA), `mpv`, or `ffplay` for audio; `notify-send` for notifications; `xdotool` for focus detection (optional)
- **WSL2**: uses PowerShell `MediaPlayer` and WinForms
- Claude Code with hooks support
- python3

## How it works

`peon.sh` is a Claude Code hook registered for `SessionStart`, `UserPromptSubmit`, `Stop`, and `Notification` events. On each event it maps to a sound category, picks a random voice line (avoiding repeats), plays it via `afplay` (macOS), `paplay`/`aplay`/`mpv`/`ffplay` (Linux), or PowerShell `MediaPlayer` (WSL2), and updates your Terminal tab title.

Sound files are property of their respective publishers (Blizzard Entertainment, EA) and are included in the repo for convenience.

## Links

- [Landing page](https://peon-ping.vercel.app/)
- [License (MIT)](LICENSE)
