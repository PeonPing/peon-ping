# peon-ping

![macOS](https://img.shields.io/badge/macOS-blue) ![WSL2](https://img.shields.io/badge/WSL2-blue) ![Linux](https://img.shields.io/badge/Linux-blue) ![SSH](https://img.shields.io/badge/SSH-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Claude Code](https://img.shields.io/badge/Claude_Code-hook-ffab01) ![Codex](https://img.shields.io/badge/Codex-adapter-ffab01) ![Cursor](https://img.shields.io/badge/Cursor-adapter-ffab01) ![OpenCode](https://img.shields.io/badge/OpenCode-adapter-ffab01) ![Antigravity](https://img.shields.io/badge/Antigravity-adapter-ffab01)

**Game character voice lines when your AI coding agent needs attention.**

AI coding agents don't notify you when they finish or need permission. You tab away, lose focus, and waste 15 minutes getting back into flow. peon-ping fixes this with voice lines from Warcraft, StarCraft, Portal, Zelda, and more — works with **Claude Code**, **Codex**, **Cursor**, **OpenCode**, and **Google Antigravity**.

**See it in action** &rarr; [peonping.com](https://peonping.com/)

## Install

### Option 1: Homebrew (recommended)

```bash
brew install PeonPing/tap/peon-ping
```

Then run `peon-ping-setup` to register hooks and download sound packs. macOS and Linux.

### Option 2: Installer script (macOS, Linux, WSL2)

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash
```

### Option 3: Installer for windows

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.ps1" -UseBasicParsing | Invoke-Expression
```


Installs 10 curated English packs by default. Re-run to update while preserving config/state. Or **[pick your packs interactively at peonping.com](https://peonping.com/#picker)** and get a custom install command.

Useful installer flags:

- `--all` — install all available packs
- `--packs=peon,glados,...` — install specific packs only
- `--local` — install into `./.claude/` for current project
- `--global` — explicit global install (same as default)
- `--init-local-config` — create `./.claude/hooks/peon-ping/config.json` only

`--local` does not modify your shell rc files (no global `peon` alias/completion injection).

Examples:

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --all
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --packs=peon,glados
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --local
```

If a global install exists and you install local (or vice versa), the installer prompts you to remove the existing one to avoid conflicts.

### Option 3: Clone and inspect first

```bash
git clone https://github.com/PeonPing/peon-ping.git
cd peon-ping
./install.sh
```

## What you'll hear

| Event | CESP Category | Examples |
|---|---|---|
| Session starts | `session.start` | *"Ready to work?"*, *"Yes?"*, *"What you want?"* |
| Task finishes | `task.complete` | *"Work, work."*, *"I can do that."*, *"Okie dokie."* |
| Permission needed | `input.required` | *"Something need doing?"*, *"Hmm?"*, *"What you want?"* |
| Rapid prompts (3+ in 10s) | `user.spam` | *"Me busy, leave me alone!"* |

Plus Terminal tab titles (`● project: done`) and desktop notifications when your terminal isn't focused.

peon-ping implements the [Coding Event Sound Pack Specification (CESP)](https://github.com/PeonPing/openpeon) — an open standard for coding event sounds that any agentic IDE can adopt.

## Quick controls

Need to mute sounds and notifications during a meeting or pairing session? Two options:

| Method | Command | When |
|---|---|---|
| **Slash command** | `/peon-ping-toggle` | While working in Claude Code |
| **CLI** | `peon toggle` | From any terminal tab |

Other CLI commands:

```bash
peon pause                # Mute sounds
peon resume               # Unmute sounds
peon status               # Check if paused or active
peon packs list           # List installed sound packs
peon packs use <name>     # Switch to a specific pack
peon packs next           # Cycle to the next pack
peon packs remove <p1,p2> # Remove specific packs
peon notifications on     # Enable desktop notifications
peon notifications off    # Disable desktop notifications
peon mobile ntfy <topic>  # Set up phone notifications (free)
peon mobile off           # Disable phone notifications
peon mobile test          # Send a test notification
peon relay --daemon       # Start audio relay (for SSH/devcontainer)
peon relay --stop         # Stop background relay
```

Tab completion is supported — type `peon packs use <TAB>` to see available pack names.

Pausing mutes sounds and desktop notifications instantly. Persists across sessions until you resume. Tab titles remain active when paused.

## Configuration

peon-ping installs a `/peon-ping-toggle` slash command in Claude Code. You can also just ask Claude to change settings for you — e.g. "enable round-robin pack rotation", "set volume to 0.3", or "add glados to my pack rotation". No need to edit config files manually.

Config location depends on install mode:

- Global install: `$CLAUDE_CONFIG_DIR/hooks/peon-ping/config.json` (default `~/.claude/hooks/peon-ping/config.json`)
- Local install: `./.claude/hooks/peon-ping/config.json`

```json
{
  "volume": 0.5,
  "categories": {
    "session.start": true,
    "task.acknowledge": true,
    "task.complete": true,
    "task.error": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  }
}
```

- **volume**: 0.0–1.0 (quiet enough for the office)
- **desktop_notifications**: `true`/`false` — toggle desktop notification popups independently from sounds (default: `true`)
- **categories**: Toggle individual CESP sound categories on/off (e.g. `"session.start": false` to disable greeting sounds)
- **annoyed_threshold / annoyed_window_seconds**: How many prompts in N seconds triggers the `user.spam` easter egg
- **silent_window_seconds**: Suppress `task.complete` sounds and notifications for tasks shorter than N seconds. (e.g. `10` to only hear sounds for tasks that take longer than 10 seconds)
- **pack_rotation**: Array of pack names (e.g. `["peon", "sc_kerrigan", "peasant"]`). Each session randomly gets one pack from the list and keeps it for the whole session. Leave empty `[]` to use `active_pack` instead.

## Multi-IDE Support

peon-ping works with any agentic IDE that supports hooks. Adapters translate IDE-specific events to the [CESP standard](https://github.com/PeonPing/openpeon).

| IDE | Status | Setup |
|---|---|---|
| **Claude Code** | Built-in | `curl \| bash` install handles everything |
| **OpenAI Codex** | Adapter | Add `notify = ["bash", "/absolute/path/to/.claude/hooks/peon-ping/adapters/codex.sh"]` to `~/.codex/config.toml` |
| **Cursor** | Adapter | Add hook entries to `~/.cursor/hooks.json` pointing to `adapters/cursor.sh` |
| **OpenCode** | Adapter | `curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode.sh \| bash` |
| **Google Antigravity** | Adapter | `bash ~/.claude/hooks/peon-ping/adapters/antigravity.sh` (requires `fswatch`: `brew install fswatch`) |

## Remote development (SSH / Devcontainers / Codespaces)

Coding on a remote server or inside a container? peon-ping auto-detects SSH sessions, devcontainers, and Codespaces, then routes audio and notifications through a lightweight relay running on your local machine.

### SSH setup

1. **On your local machine**, start the relay:
   ```bash
   peon relay --daemon
   ```

2. **SSH with port forwarding**:
   ```bash
   ssh -R 19998:localhost:19998 your-server
   ```

3. **Install peon-ping on the remote** — it auto-detects the SSH session and sends audio requests back through the forwarded port to your local relay.

That's it. Sounds play on your laptop, not the remote server.

### Devcontainers / Codespaces

No port forwarding needed — peon-ping auto-detects `REMOTE_CONTAINERS` and `CODESPACES` environment variables and routes audio to `host.docker.internal:19998`. Just run `peon relay --daemon` on your host machine.

### Relay commands

```bash
peon relay                # Start relay in foreground
peon relay --daemon       # Start in background
peon relay --stop         # Stop background relay
peon relay --status       # Check if relay is running
peon relay --port=12345   # Custom port (default: 19998)
peon relay --bind=0.0.0.0 # Listen on all interfaces (less secure)
```

Environment variables: `PEON_RELAY_PORT`, `PEON_RELAY_HOST`, `PEON_RELAY_BIND`.

If peon-ping detects an SSH or container session but can't reach the relay, it prints setup instructions on `SessionStart`.

## Mobile notifications

Get push notifications on your phone when tasks finish or need attention — useful when you're away from your desk.

### Quick start (ntfy.sh — free, no account needed)

1. Install the [ntfy app](https://ntfy.sh) on your phone
2. Subscribe to a unique topic in the app (e.g. `my-peon-notifications`)
3. Run:
   ```bash
   peon mobile ntfy my-peon-notifications
   ```

Also supports [Pushover](https://pushover.net) and [Telegram](https://core.telegram.org/bots):

```bash
peon mobile pushover <user_key> <app_token>
peon mobile telegram <bot_token> <chat_id>
```

### Mobile commands

```bash
peon mobile on            # Enable mobile notifications
peon mobile off           # Disable mobile notifications
peon mobile status        # Show current config
peon mobile test          # Send a test notification
```

Mobile notifications fire on every event regardless of window focus — they're independent from desktop notifications and sounds.

## Sound packs

43+ packs across Warcraft, StarCraft, Red Alert, Portal, Zelda, Dota 2, Helldivers 2, Elder Scrolls, and more. The default install includes 10 curated English packs:

| Pack | Character | Sounds |
|---|---|---|
| `peon` (default) | Orc Peon (Warcraft III) | "Ready to work?", "Work, work.", "Okie dokie." |
| `peasant` | Human Peasant (Warcraft III) | "Yes, milord?", "Job's done!", "Ready, sir." |
| `glados` | GLaDOS (Portal) | "Oh, it's you.", "You monster.", "Your entire team is dead." |
| `sc_kerrigan` | Sarah Kerrigan (StarCraft) | "I gotcha", "What now?", "Easily amused, huh?" |
| `sc_battlecruiser` | Battlecruiser (StarCraft) | "Battlecruiser operational", "Make it happen", "Engage" |
| `ra2_kirov` | Kirov Airship (Red Alert 2) | "Kirov reporting", "Bombardiers to your stations" |
| `dota2_axe` | Axe (Dota 2) | "Axe is ready!", "Axe-actly!", "Come and get it!" |
| `duke_nukem` | Duke Nukem | "Hail to the king!", "Groovy.", "Balls of steel." |
| `tf2_engineer` | Engineer (Team Fortress 2) | "Sentry going up.", "Nice work!", "Cowboy up!" |
| `hd2_helldiver` | Helldiver (Helldivers 2) | "For democracy!", "How 'bout a nice cup of Liber-tea?" |

**[Browse all packs with audio previews &rarr; openpeon.com/packs](https://openpeon.com/packs)**

Install all with `--all`, or switch packs anytime:

```bash
peon packs use glados             # switch to a specific pack
peon packs next                   # cycle to the next pack
peon packs list                   # list all installed packs
```

Want to add your own pack? See the [full guide at openpeon.com/create](https://openpeon.com/create) or [CONTRIBUTING.md](CONTRIBUTING.md).

## Uninstall

**macOS/Linux:**

```bash
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/uninstall.sh        # global
bash .claude/hooks/peon-ping/uninstall.sh           # project-local
```

**Windows (PowerShell):**

```powershell
# Standard uninstall (prompts before deleting sounds)
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\peon-ping\uninstall.ps1"

# Keep sound packs (removes everything else)
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\peon-ping\uninstall.ps1" -KeepSounds
```

## Requirements

- macOS (uses `afplay` and AppleScript), WSL2 (uses PowerShell `MediaPlayer` and WinForms), or Linux (uses `pw-play`/`paplay`/`ffplay`/`mpv`/`aplay` and `notify-send`)
- Claude Code with hooks support
- python3
- For SSH/remote: `curl` on the remote host

## How it works

`peon.sh` is a Claude Code hook registered for `SessionStart`, `UserPromptSubmit`, `Stop`, `Notification`, and `PermissionRequest` events. On each event it maps to a CESP sound category, picks a random voice line (avoiding repeats), plays it via `afplay` (macOS), PowerShell `MediaPlayer` (WSL2), or `paplay`/`ffplay`/`mpv`/`aplay` (Linux), and updates your Terminal tab title. In SSH sessions, devcontainers, and Codespaces, audio and notification requests are forwarded over HTTP to a relay server (`relay.sh`) running on your local machine.

Sound packs are downloaded from the [OpenPeon registry](https://github.com/PeonPing/registry) at install time. The official packs are hosted in [PeonPing/og-packs](https://github.com/PeonPing/og-packs). Sound files are property of their respective publishers (Blizzard, Valve, EA, etc.) and are distributed under fair use for personal notification purposes.

## Links

- [peonping.com](https://peonping.com/) — landing page
- [openpeon.com](https://openpeon.com/) — CESP spec, pack browser, creation guide
- [OpenPeon registry](https://github.com/PeonPing/registry) — pack registry (GitHub Pages)
- [og-packs](https://github.com/PeonPing/og-packs) — official sound packs
- [License (MIT)](LICENSE)
