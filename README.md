# peon-ping

![macOS](https://img.shields.io/badge/macOS-blue) ![WSL2](https://img.shields.io/badge/WSL2-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Claude Code](https://img.shields.io/badge/Claude_Code-hook-ffab01)

**Your Peon pings you when Claude Code needs attention.**

Claude Code doesn't notify you when it finishes or needs permission. You tab away, lose focus, and waste 15 minutes getting back into flow. peon-ping fixes this with Warcraft III Peon voice lines — so you never miss a beat, and your terminal sounds like Orgrimmar.

**See it in action** &rarr; [peon-ping.vercel.app](https://peon-ping.vercel.app/)

## Install

### Recommended: Clone the repository

```bash
git clone https://github.com/kenyiu/peon-ping.git
cd peon-ping
./install.sh
```

This is the recommended method — you can review the code before running and easily pull updates.

### Alternative: Direct install

```bash
curl -fsSL https://raw.githubusercontent.com/kenyiu/peon-ping/main/install.sh | bash
```

> **Security Note:** Running `curl | bash` pipes remote code directly to your shell. Always review scripts before running. For forks, verify the repository is trustworthy. The git clone method lets you inspect the code first.

### Verifying releases

For releases, you can verify the download checksum:

```bash
# Download the release and checksum file
curl -fSL https://github.com/kenyiu/peon-ping/releases/download/vX.X.X/peon-ping-X.X.X.tar.gz -o peon-ping.tar.gz
curl -fSL https://github.com/kenyiu/peon-ping/releases/download/vX.X.X/checksums.txt -o checksums.txt

# Verify
sha256sum -c checksums.txt --ignore-missing
```

Takes 10 seconds. macOS and WSL2 (Windows). Re-run to update (sounds and config preserved).

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

## Per-Project Configuration

You can have different settings for different projects:

```bash
# Install globally once
./install.sh

# In a specific project, create local config
./install.sh --init-config
```

This creates `./.claude/hooks/peon-ping/config.json` in your project — perfect for:
- Different volume levels per project
- Different sound packs per project
- Project-specific settings that don't affect other work

## Configuration

Edit `~/.claude/hooks/peon-ping/config.json` (global) or `./.claude/hooks/peon-ping/config.json` (project-specific):

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
- **local_only**: When `true` in global config, the hook only runs if a local (project-specific) config exists. Useful for teams who want to enforce per-project configuration. Set in `~/.claude/hooks/peon-ping/config.json` to apply globally.

## Sound packs

| Pack | Character | Sounds | By |
|---|---|---|---|
| `peon` (default) | Orc Peon (Warcraft III) | "Ready to work?", "Work, work.", "Okie dokie." | [@kenyiu](https://github.com/kenyiu) |
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

- macOS (uses `afplay` and AppleScript) or WSL2 (uses PowerShell `MediaPlayer` and WinForms)
- Claude Code with hooks support
- python3

## How it works

`peon.sh` is a Claude Code hook registered for `SessionStart`, `UserPromptSubmit`, `Stop`, and `Notification` events. On each event it maps to a sound category, picks a random voice line (avoiding repeats), plays it via `afplay` (macOS) or PowerShell `MediaPlayer` (WSL2), and updates your Terminal tab title.

Sound files are property of their respective publishers (Blizzard Entertainment, EA) and are included in the repo for convenience.

## Links

- [Landing page](https://peon-ping.vercel.app/)
- [License (MIT)](LICENSE)
