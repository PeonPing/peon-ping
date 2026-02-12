# peon-ping

![macOS](https://img.shields.io/badge/macOS-blue) ![WSL2](https://img.shields.io/badge/WSL2-blue) ![Linux](https://img.shields.io/badge/Linux-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Claude Code](https://img.shields.io/badge/Claude_Code-hook-ffab01)

**Your Peon pings you when Claude Code needs attention.**

Claude Code doesn't notify you when it finishes or needs permission. You tab away, lose focus, and waste 15 minutes getting back into flow. peon-ping fixes this with Warcraft III Peon voice lines — so you never miss a beat, and your terminal sounds like Orgrimmar.

**See it in action** &rarr; [peonping.com](https://peonping.com/)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tonyyont/peon-ping/main/install.sh | bash
```

One command. Takes 10 seconds. macOS, WSL2 (Windows), and Linux. Re-run to update (sounds and config preserved).

**Project-local install** — installs into `.claude/` in the current project instead of `~/.claude/`:

```bash
curl -fsSL https://raw.githubusercontent.com/tonyyont/peon-ping/main/install.sh | bash -s -- --local
```

Local installs don't add the `peon` CLI alias or shell completions — use `/peon-ping-toggle` inside Claude Code instead.

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
| `peon_ru` | Orc Peon (Warcraft III, Russian) | "Готов вкалывать!", "Работа, работа.", "Оки-доки." | [@maksimfedin](https://github.com/maksimfedin) |
| `peasant_ru` | Human Peasant (Warcraft III, Russian) | "Да, господин?", "Готово.", "Ну, я пошёл!" | [@maksimfedin](https://github.com/maksimfedin) |
| `acolyte_ru` | Undead Acolyte (Warcraft III, Russian) | "Моя жизнь за Нер'зула!", "Да, повелитель.", "Тени служат мне." | [@maksimfedin](https://github.com/maksimfedin) |
| `tf2_engineer` | Engineer (Team Fortress 2) | "Sentry going up.", "Nice work!", "Cowboy up!" | [@Arie](https://github.com/Arie) |
| `sc_battlecruiser` | Battlecruiser (StarCraft) | "Battlecruiser operational", "Make it happen", "Engage" | [@garysheng](https://github.com/garysheng) |
| `sc_kerrigan` | Sarah Kerrigan (StarCraft) | "I gotcha", "What now?", "Easily amused, huh?" | [@garysheng](https://github.com/garysheng) |
| `glados` | GLaDOS (Portal) | "Oh, it's you.", "You monster.", "Your entire team is dead." | [@DoubleGremlin181](https://github.com/DoubleGremlin181) |
| `sc_terran` | Terran Units Mixed (StarCraft) | SCV, Firebat, Medic, Siege Tank, Science Vessel | [@workdd](https://github.com/workdd) |
| `sc_scv` | SCV (StarCraft) | "Good to go, sir", "Affirmative", "I read you" | [@workdd](https://github.com/workdd) |
| `sc_firebat` | Firebat (StarCraft) | "Need a light?", "Ready to roast!", "Fueled up!" | [@workdd](https://github.com/workdd) |
| `sc_medic` | Medic (StarCraft) | "The doctor is in", "Where does it hurt?", "All patched up!" | [@workdd](https://github.com/workdd) |
| `sc_tank` | Siege Tank (StarCraft) | "Ready to roll out", "Absolutely", "Done and done" | [@workdd](https://github.com/workdd) |
| `sc_vessel` | Science Vessel (StarCraft) | "Explorer reporting", "Receiving", "Affirmative" | [@workdd](https://github.com/workdd) |

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
bash ~/.claude/hooks/peon-ping/uninstall.sh        # global
bash .claude/hooks/peon-ping/uninstall.sh           # project-local
```

## Requirements

- macOS (uses `afplay` and AppleScript), WSL2 (uses PowerShell `MediaPlayer` and WinForms), or Linux (uses `pw-play`/`paplay`/`ffplay`/`mpv`/`aplay` and `notify-send`)
- Claude Code with hooks support
- python3

## How it works

`peon.sh` is a Claude Code hook registered for `SessionStart`, `UserPromptSubmit`, `Stop`, and `Notification` events. On each event it maps to a sound category, picks a random voice line (avoiding repeats), plays it via `afplay` (macOS), PowerShell `MediaPlayer` (WSL2), or `paplay`/`ffplay`/`mpv`/`aplay` (Linux), and updates your Terminal tab title.

Sound files are property of their respective publishers (Blizzard Entertainment, EA) and are included in the repo for convenience.

## Links

- [Landing page](https://peonping.com/)
- [License (MIT)](LICENSE)
