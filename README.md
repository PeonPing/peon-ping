# peon-ping
<div align="center">

**English** | [한국어](README_ko.md) | [中文](README_zh.md)

![macOS](https://img.shields.io/badge/macOS-blue) ![WSL2](https://img.shields.io/badge/WSL2-blue) ![Linux](https://img.shields.io/badge/Linux-blue) ![Windows](https://img.shields.io/badge/Windows-blue) ![SSH](https://img.shields.io/badge/SSH-blue)
![License](https://img.shields.io/badge/license-MIT-green)

![Claude Code](https://img.shields.io/badge/Claude_Code-hook-ffab01) ![Gemini CLI](https://img.shields.io/badge/Gemini_CLI-adapter-ffab01) ![GitHub Copilot](https://img.shields.io/badge/GitHub_Copilot-adapter-ffab01) ![Codex](https://img.shields.io/badge/Codex-adapter-ffab01) ![Cursor](https://img.shields.io/badge/Cursor-adapter-ffab01) ![OpenCode](https://img.shields.io/badge/OpenCode-adapter-ffab01) ![Kilo CLI](https://img.shields.io/badge/Kilo_CLI-adapter-ffab01) ![Kiro](https://img.shields.io/badge/Kiro-adapter-ffab01) ![Windsurf](https://img.shields.io/badge/Windsurf-adapter-ffab01) ![Antigravity](https://img.shields.io/badge/Antigravity-adapter-ffab01) ![OpenClaw](https://img.shields.io/badge/OpenClaw-adapter-ffab01)

**Game character voice lines + visual overlay notifications when your AI coding agent needs attention — or let the agent pick its own sound via MCP.**

AI coding agents don't notify you when they finish or need permission. You tab away, lose focus, and waste 15 minutes getting back into flow. peon-ping fixes this with voice lines and bold on-screen banners from Warcraft, StarCraft, Portal, Zelda, and more — works with **Claude Code**, **GitHub Copilot**, **Codex**, **Cursor**, **OpenCode**, **Kilo CLI**, **Kiro**, **Windsurf**, **Google Antigravity**, and any MCP client.

**See it in action** &rarr; [peonping.com](https://peonping.com/)

<video src="docs/public/demo-avatar.mp4" autoplay loop muted playsinline width="400"></video>

</div>

---

- [Install](#install)
- [What you'll hear](#what-youll-hear)
- [Quick controls](#quick-controls)
- [Configuration](#configuration)
- [Peon Trainer](#peon-trainer)
- [MCP server](#mcp-server)
- [Multi-IDE support](#multi-ide-support)
- [Remote development](#remote-development-ssh--devcontainers--codespaces)
- [Mobile notifications](#mobile-notifications)
- [Sound packs](#sound-packs)
- [Uninstall](#uninstall)
- [Requirements](#requirements)
- [How it works](#how-it-works)
- [Links](#links)

---

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

### Option 3: Installer for Windows

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.ps1" -UseBasicParsing | Invoke-Expression
```

Installs 5 curated packs by default (Warcraft, StarCraft, Portal). Re-run to update while preserving config/state. Or **[pick your packs interactively at peonping.com](https://peonping.com/#picker)** and get a custom install command.

Useful installer flags:

- `--all` — install all available packs
- `--packs=peon,sc_kerrigan,...` — install specific packs only
- `--local` — install packs and config into `./.claude/` for the current project (hooks are always registered globally in `~/.claude/settings.json`)
- `--global` — explicit global install (same as default)
- `--init-local-config` — create `./.claude/hooks/peon-ping/config.json` only

`--local` does not modify your shell rc files (no global `peon` alias/completion injection). Hooks are always written to the global `~/.claude/settings.json` with absolute paths so they work from any project directory.

Examples:

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --all
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --packs=peon,sc_kerrigan
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --local
```

If a global install exists and you install local (or vice versa), the installer prompts you to remove the existing one to avoid conflicts.

### Option 4: Clone and inspect first

```bash
git clone https://github.com/PeonPing/peon-ping.git
cd peon-ping
./install.sh
```

### Option 5: Nix (macOS, Linux)

Run directly from source without installing:

```bash
nix run github:PeonPing/peon-ping -- status
nix run github:PeonPing/peon-ping -- packs install peon
```

Or install to your profile:

```bash
nix profile install github:PeonPing/peon-ping
```

Development shell (bats, shellcheck, nodejs):

```bash
nix develop  # or use direnv
```

#### Home Manager module (declarative configuration)

For reproducible setups, use the Home Manager module:

```nix
# In your home.nix or flake.nix
{ inputs, pkgs, ... }: {
  imports = [ inputs.peon-ping.homeManagerModules.default ];

  programs.peon-ping = {
    enable = true;
    package = inputs.peon-ping.packages.${pkgs.system}.default;
    
    settings = {
      default_pack = "glados";
      volume = 0.7;
      enabled = true;
      desktop_notifications = true;
      categories = {
        "session.start" = true;
        "task.complete" = true;
        "task.error" = true;
        "input.required" = true;
        "resource.limit" = true;
        "user.spam" = true;
      };
    };
    
    installPacks = [ "peon" "glados" "sc_kerrigan" ];
    enableZshIntegration = true;
  };
}
```

This creates `~/.openpeon/config.json` and installs specified packs automatically.

## What you'll hear

| Event | CESP Category | Examples |
|---|---|---|
| Session starts | `session.start` | *"Ready to work?"*, *"Yes?"*, *"What you want?"* |
| Task finishes | `task.complete` | *"Work, work."*, *"I can do that."*, *"Okie dokie."* |
| Permission needed | `input.required` | *"Something need doing?"*, *"Hmm?"*, *"What you want?"* |
| Tool or command error | `task.error` | *"I can't do that."*, *"Son of a bitch!"* |
| Agent acknowledged task | `task.acknowledge` | *"I read you."*, *"On it."* *(disabled by default)* |
| Rate or token limit hit | `resource.limit` | *"Zug zug."* *(pack dependent)* |
| Rapid prompts (3+ in 10s) | `user.spam` | *"Me busy, leave me alone!"* |

Plus **large overlay banners** on every screen (macOS/WSL) and terminal tab titles (`● project: done`) — you'll know something happened even if you're in another app.

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
peon volume               # Show current volume
peon volume 0.7           # Set volume (0.0–1.0)
peon rotation             # Show current rotation mode
peon rotation random      # Set rotation mode (random|round-robin|session_override)
peon packs list           # List installed sound packs
peon packs list --registry # Browse all available packs in the registry
peon packs install <p1,p2> # Install packs from the registry
peon packs install --all  # Install all packs from the registry
peon packs install-local <path> # Install a pack from a local directory
peon packs use <name>     # Switch to a specific pack
peon packs use --install <name>  # Switch to pack, installing from registry if needed
peon packs next           # Cycle to the next pack
peon packs remove <p1,p2> # Remove specific packs
peon notifications on     # Enable desktop notifications
peon notifications off    # Disable desktop notifications
peon notifications overlay   # Use large overlay banners (default)
peon notifications standard  # Use standard system notifications
peon notifications test      # Send a test notification
peon preview              # Play all sounds from session.start
peon preview <category>   # Play all sounds from a specific category
peon preview --list       # List all categories in the active pack
peon mobile ntfy <topic>  # Set up phone notifications (free)
peon mobile off           # Disable phone notifications
peon mobile test          # Send a test notification
peon relay --daemon       # Start audio relay (for SSH/devcontainer)
peon relay --stop         # Stop background relay
```

Available CESP categories for `peon preview`: `session.start`, `task.acknowledge`, `task.complete`, `task.error`, `input.required`, `resource.limit`, `user.spam`. (Extended categories `session.end` and `task.progress` are defined in the CESP spec and supported by pack manifests, but not currently triggered by built-in hook events.)

Tab completion is supported — type `peon packs use <TAB>` to see available pack names.

Pausing mutes sounds and desktop notifications instantly. Persists across sessions until you resume. Tab titles remain active when paused.

## Configuration

peon-ping installs two slash commands in Claude Code:

- `/peon-ping-toggle` — mute/unmute sounds
- `/peon-ping-config` — change any setting (volume, packs, categories, etc.)

You can also just ask Claude to change settings for you — e.g. "enable round-robin pack rotation", "set volume to 0.3", or "add glados to my pack rotation". No need to edit config files manually.

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
- **notification_style**: `"overlay"` or `"standard"` — controls how desktop notifications appear (default: `"overlay"`)
  - **overlay**: large, visible banners — JXA Cocoa overlay on macOS, Windows Forms popup on WSL. Clicking the overlay focuses your terminal (supports Ghostty, Warp, iTerm2, Zed, Terminal.app)
  - **standard**: system notifications — [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) / `osascript` on macOS, Windows toast on WSL. When `terminal-notifier` is installed (`brew install terminal-notifier`), clicking a standard notification focuses your terminal automatically (supports Ghostty, Warp, iTerm2, Zed, Terminal.app)
- **categories**: Toggle individual CESP sound categories on/off (e.g. `"session.start": false` to disable greeting sounds)
- **annoyed_threshold / annoyed_window_seconds**: How many prompts in N seconds triggers the `user.spam` easter egg
- **silent_window_seconds**: Suppress `task.complete` sounds and notifications for tasks shorter than N seconds. (e.g. `10` to only hear sounds for tasks that take longer than 10 seconds)
- **suppress_subagent_complete** (boolean, default: `false`): Suppress `task.complete` sounds and notifications when a sub-agent session finishes. When Claude Code's Task tool dispatches parallel sub-agents, each one fires a completion sound — set this to `true` to hear only the parent session's completion sound.
- **default_pack**: The fallback pack used when no more specific rule applies (default: `"peon"`). Replaces the old `active_pack` key — existing configs are migrated automatically on `peon update`.
- **path_rules**: Array of `{ "pattern": "...", "pack": "..." }` objects. Assigns a pack to sessions based on the working directory using glob matching (`*`, `?`). First matching rule wins. Beats `pack_rotation` and `default_pack`; overridden by `session_override` assignments.
  ```json
  "path_rules": [
    { "pattern": "*/work/client-a/*", "pack": "glados" },
    { "pattern": "*/personal/*",      "pack": "peon" }
  ]
  ```
- **pack_rotation**: Array of pack names (e.g. `["peon", "sc_kerrigan", "peasant"]`). Used when `pack_rotation_mode` is `random` or `round-robin`. Leave empty `[]` to use `default_pack` (or `path_rules`) only.
- **pack_rotation_mode**: `"random"` (default), `"round-robin"`, or `"session_override"`. With `random`/`round-robin`, each session picks one pack from `pack_rotation`. With `session_override`, the `/peon-ping-use <pack>` command assigns a pack per session. Invalid or missing packs fall back through the hierarchy. (`"agentskill"` is accepted as a legacy alias for `"session_override"`.)
- **session_ttl_days** (number, default: 7): Expire stale per-session pack assignments older than N days. Keeps `.state.json` from growing unbounded when using `session_override` mode.

## Peon Trainer

Your peon is also your personal trainer. Built-in Pavel-style daily exercise mode — the same orc who tells you "work work" now tells you to drop and give him twenty.

### Quick start

```bash
peon trainer on              # enable trainer
peon trainer goal 200        # set daily goal (default: 300/300)
# ... code for a while, peon nags you every ~20 min ...
peon trainer log 25 pushups  # log what you did
peon trainer log 30 squats
peon trainer status          # check progress
```

### How it works

Trainer reminders piggyback on your coding session. When you start a new session, the peon immediately encourages you to start strong with pushups before you write any code. Then every ~20 minutes of active coding, you'll hear the peon yelling at you to do more reps. No background daemon needed. Log your reps with `peon trainer log`, and progress resets automatically at midnight.

### Commands

| Command | Description |
|---------|-------------|
| `peon trainer on` | Enable trainer mode |
| `peon trainer off` | Disable trainer mode |
| `peon trainer status` | Show today's progress |
| `peon trainer log <n> <exercise>` | Log reps (e.g. `log 25 pushups`) |
| `peon trainer goal <n>` | Set goal for all exercises |
| `peon trainer goal <exercise> <n>` | Set goal for one exercise |

### Claude Code skill

In Claude Code, you can log reps without leaving your conversation:

```
/peon-ping-log 25 pushups
/peon-ping-log 30 squats
```

### Custom voice lines

Drop your own audio files into `~/.claude/hooks/peon-ping/trainer/sounds/`:

```
trainer/sounds/session_start/  # session greeting ("Pushups first, code second! Zug zug!")
trainer/sounds/remind/         # reminder lines ("Something need doing? YES. PUSHUPS.")
trainer/sounds/log/            # acknowledgment ("Work work! Muscles getting bigger maybe!")
trainer/sounds/complete/       # celebration ("Zug zug! Human finish all reps!")
trainer/sounds/slacking/       # disappointment ("Peon very disappointed.")
```

Update `trainer/manifest.json` to register your sound files.

## MCP server

peon-ping includes an [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) server so any MCP-compatible AI agent can play sounds directly via tool calls — no hooks required.

The key difference: **the agent chooses the sound**. Instead of automatically playing a fixed sound on every event, the agent calls `play_sound` with exactly what it wants — `duke_nukem/SonOfABitch` when a build fails, `sc_kerrigan/IReadYou` when reading files.

### Setup

Add to your MCP client config (Claude Desktop, Cursor, etc.):

```json
{
  "mcpServers": {
    "peon-ping": {
      "command": "node",
      "args": ["/path/to/peon-ping/mcp/peon-mcp.js"]
    }
  }
}
```

If installed via Homebrew: `$(brew --prefix peon-ping)/libexec/mcp/peon-mcp.js`. See [`mcp/README.md`](mcp/README.md) for full setup instructions.

### What the agent can do

| Feature | Description |
|---|---|
| **`play_sound`** | Play one or more sounds by key (e.g. `duke_nukem/SonOfABitch`, `peon/PeonReady1`) |
| **`peon-ping://catalog`** | Full pack catalog as an MCP Resource — client prefetches once, no repeated tool calls |
| **`peon-ping://pack/{name}`** | Individual pack details and available sound keys |

Requires Node.js 18+. Contributed by [@tag-assistant](https://github.com/tag-assistant).

## Multi-IDE Support

peon-ping works with any agentic IDE that supports hooks. Adapters translate IDE-specific events to the [CESP standard](https://github.com/PeonPing/openpeon).

| IDE | Status | Setup |
|---|---|---|
| **Claude Code** | Built-in | `curl \| bash` install handles everything |
| **Gemini CLI** | Adapter | Add hooks to `~/.gemini/settings.json` pointing to `adapters/gemini.sh` ([setup](#gemini-cli-setup)) |
| **GitHub Copilot** | Adapter | Add hooks to `.github/hooks/hooks.json` pointing to `adapters/copilot.sh` ([setup](#github-copilot-setup)) |
| **OpenAI Codex** | Adapter | Add `notify = ["bash", "/absolute/path/to/.claude/hooks/peon-ping/adapters/codex.sh"]` to `~/.codex/config.toml` |
| **Cursor** | Built-in | `curl \| bash`, `peon-ping-setup`, or Windows `install.ps1` auto-detect and register hooks. On Windows, enable **Settings → Features → Third-party skills** so Cursor loads `~/.claude/settings.json` for SessionStart/Stop sounds. |
| **OpenCode** | Adapter | `curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode.sh \| bash` ([setup](#opencode-setup)) |
| **Kilo CLI** | Adapter | `curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/kilo.sh \| bash` ([setup](#kilo-cli-setup)) |
| **Kiro** | Adapter | Add hook entries to `~/.kiro/agents/peon-ping.json` pointing to `adapters/kiro.sh` ([setup](#kiro-setup)) |
| **Windsurf** | Adapter | Add hook entries to `~/.codeium/windsurf/hooks.json` pointing to `adapters/windsurf.sh` ([setup](#windsurf-setup)) |
| **Google Antigravity** | Adapter | `bash ~/.claude/hooks/peon-ping/adapters/antigravity.sh` (requires `fswatch`: `brew install fswatch`) |
| **OpenClaw** | Adapter | Call `adapters/openclaw.sh <event>` from your OpenClaw skill. Supports all CESP categories and raw Claude Code event names. |

### GitHub Copilot setup

A shell adapter for [GitHub Copilot](https://github.com/features/copilot) with full [CESP v1.0](https://github.com/PeonPing/openpeon) conformance.

**Setup:**

1. Ensure peon-ping is installed (`curl -fsSL https://peonping.com/install | bash`)

2. Create `.github/hooks/hooks.json` in your repository (on the default branch):

   ```json
   {
     "version": 1,
     "hooks": {
       "sessionStart": [
         {
           "type": "command",
           "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh sessionStart"
         }
       ],
       "userPromptSubmitted": [
         {
           "type": "command",
           "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh userPromptSubmitted"
         }
       ],
       "postToolUse": [
         {
           "type": "command",
           "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh postToolUse"
         }
       ],
       "errorOccurred": [
         {
           "type": "command",
           "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh errorOccurred"
         }
       ]
     }
   }
   ```

3. Commit and merge to your default branch. Hooks will activate on your next Copilot agent session.

**Event mapping:**

- `sessionStart` → Greeting sound (*"Ready to work?"*, *"Yes?"*)
- `userPromptSubmitted` → First prompt = greeting, subsequent = spam detection
- `postToolUse` → Completion sound (*"Work, work."*, *"Job's done!"*)
- `errorOccurred` → Error sound (*"I can't do that."*)
- `preToolUse` → Skipped (too noisy)
- `sessionEnd` → No sound (session.end not yet implemented)

**Features:**

- **Sound playback** via `afplay` (macOS), `pw-play`/`paplay`/`ffplay` (Linux) — same priority chain as the shell hook
- **CESP event mapping** — GitHub Copilot hooks map to standard CESP categories (`session.start`, `task.complete`, `task.error`, `user.spam`)
- **Desktop notifications** — large overlay banners by default, or standard notifications
- **Spam detection** — detects 3+ rapid prompts within 10 seconds, triggers `user.spam` voice lines
- **Session tracking** — separate session markers per Copilot sessionId

### OpenCode setup

A native TypeScript plugin for [OpenCode](https://opencode.ai/) with full [CESP v1.0](https://github.com/PeonPing/openpeon) conformance.

**Quick install:**

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode.sh | bash
```

The installer copies `peon-ping.ts` to `~/.config/opencode/plugins/` and creates a config at `~/.config/opencode/peon-ping/config.json`. Packs are stored at the shared CESP path (`~/.openpeon/packs/`).

**Features:**

- **Sound playback** via `afplay` (macOS), `pw-play`/`paplay`/`ffplay` (Linux) — same priority chain as the shell hook
- **CESP event mapping** — `session.created` / `session.idle` / `session.error` / `permission.asked` / rapid prompt detection all map to standard CESP categories
- **Desktop notifications** — large overlay banners by default (JXA Cocoa, visible on all screens), or standard notifications via [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) / `osascript`. Fires only when the terminal is not focused.
- **Terminal focus detection** — checks if your terminal app (Terminal, iTerm2, Warp, Alacritty, kitty, WezTerm, ghostty, Hyper) is frontmost via AppleScript before sending notifications
- **Tab titles** — updates the terminal tab to show task status (`● project: working...` / `✓ project: done` / `✗ project: error`)
- **Pack switching** — reads `default_pack` from config (with `active_pack` fallback for legacy configs), loads the pack's `openpeon.json` manifest at runtime. `path_rules` can override the pack per working directory.
- **No-repeat logic** — avoids playing the same sound twice in a row per category
- **Spam detection** — detects 3+ rapid prompts within 10 seconds, triggers `user.spam` voice lines

<details>
<summary>🖼️ Screenshot: desktop notifications with custom peon icon</summary>

![peon-ping OpenCode notifications](https://github.com/user-attachments/assets/e433f9d1-2782-44af-a176-71875f3f532c)

</details>

> **Tip:** Install `terminal-notifier` (`brew install terminal-notifier`) for richer notifications with subtitle and grouping support.

<details>
<summary>🎨 Optional: custom peon icon for notifications</summary>

By default, `terminal-notifier` shows a generic Terminal icon. The included script replaces it with the peon icon using built-in macOS tools (`sips` + `iconutil`) — no extra dependencies.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode/setup-icon.sh)
```

Or if installed locally (Homebrew / git clone):

```bash
bash ~/.claude/hooks/peon-ping/adapters/opencode/setup-icon.sh
```

The script auto-finds the peon icon (Homebrew libexec, OpenCode config, or Claude hooks dir), generates a proper `.icns`, backs up the original `Terminal.icns`, and replaces it. Re-run after `brew upgrade terminal-notifier`.

> **Future:** When [jamf/Notifier](https://github.com/jamf/Notifier) ships to Homebrew ([#32](https://github.com/jamf/Notifier/issues/32)), the plugin will migrate to it — Notifier has built-in `--rebrand` support, no icon hacks needed.

</details>

### Kilo CLI setup

A native TypeScript plugin for [Kilo CLI](https://github.com/kilocode/cli) with full [CESP v1.0](https://github.com/PeonPing/openpeon) conformance. Kilo CLI is a fork of OpenCode and uses the same plugin system — this installer downloads the OpenCode plugin and patches it for Kilo.

**Quick install:**

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/kilo.sh | bash
```

The installer copies `peon-ping.ts` to `~/.config/kilo/plugins/` and creates a config at `~/.config/kilo/peon-ping/config.json`. Packs are stored at the shared CESP path (`~/.openpeon/packs/`).

**Features:** Same as the [OpenCode adapter](#opencode-setup) — sound playback, CESP event mapping, desktop notifications, terminal focus detection, tab titles, pack switching, no-repeat logic, and spam detection.

### Gemini CLI setup

A shell adapter for **Gemini CLI** with full [CESP v1.0](https://github.com/PeonPing/openpeon) conformance.

**Setup:**

1. Ensure peon-ping is installed (`curl -fsSL https://peonping.com/install | bash`)

2. Add the following hooks to your `~/.gemini/settings.json`:

   ```json
    {
      "hooks": {
        "SessionStart": [
          {
            "matcher": "startup",
            "hooks": [
              {
                "name": "peon-start",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh SessionStart"
              }
            ]
          }
        ],
        "AfterAgent": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-after-agent",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh AfterAgent"
              }
            ]
          }
        ],
        "AfterTool": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-after-tool",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh AfterTool"
              }
            ]
          }
        ],
        "Notification": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-notification",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh Notification"
              }
            ]
          }
        ]
      }
    }
   ```

**Event mapping:**

- `SessionStart` (startup) → Greeting sound (*"Ready to work?"*, *"Yes?"*)
- `AfterAgent` → Task completion sound (*"Work, work."*, *"Job's done!"*)
- `AfterTool` → Success = Task completion sound, Failure = Error sound (*"I can't do that."*)
- `Notification` → System notification

### Windsurf setup

Add to `~/.codeium/windsurf/hooks.json` (user-level) or `.windsurf/hooks.json` (workspace-level):

```json
{
  "hooks": {
    "post_cascade_response": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/windsurf.sh post_cascade_response", "show_output": false }
    ],
    "pre_user_prompt": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/windsurf.sh pre_user_prompt", "show_output": false }
    ],
    "post_write_code": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/windsurf.sh post_write_code", "show_output": false }
    ],
    "post_run_command": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/windsurf.sh post_run_command", "show_output": false }
    ]
  }
}
```

### Kiro setup

Create `~/.kiro/agents/peon-ping.json`:

```json
{
  "hooks": {
    "agentSpawn": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/kiro.sh" }
    ],
    "userPromptSubmit": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/kiro.sh" }
    ],
    "stop": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/kiro.sh" }
    ]
  }
}
```

`preToolUse`/`postToolUse` are intentionally excluded — they fire on every tool call and would be extremely noisy.

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

### Category-based API (for lightweight remote hooks)

The relay supports a category-based endpoint that handles sound selection server-side. This is useful for remote machines where peon-ping isn't installed — the remote hook only needs to send a category name, and the relay picks a random sound from the active pack.

**Endpoints:**

| Endpoint | Description |
|---|---|
| `GET /health` | Health check (returns "OK") |
| `GET /play?file=<path>` | Play a specific sound file (legacy) |
| `GET /play?category=<cat>` | Play random sound from category (recommended) |
| `POST /notify` | Send desktop notification |

**Example remote hook (`scripts/remote-hook.sh`):**

```bash
#!/bin/bash
RELAY_URL="${PEON_RELAY_URL:-http://127.0.0.1:19998}"
EVENT=$(cat | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hook_event_name',''))" 2>/dev/null)
case "$EVENT" in
  SessionStart)      CATEGORY="session.start" ;;
  Stop)              CATEGORY="task.complete" ;;
  PermissionRequest) CATEGORY="input.required" ;;
  *)                 exit 0 ;;
esac
curl -sf "${RELAY_URL}/play?category=${CATEGORY}" >/dev/null 2>&1 &
```

Copy this to your remote machine and register it in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{"command": "bash /path/to/remote-hook.sh"}],
    "Stop": [{"command": "bash /path/to/remote-hook.sh"}],
    "PermissionRequest": [{"command": "bash /path/to/remote-hook.sh"}]
  }
}
```

The relay reads `config.json` on your local machine to get the active pack and volume, loads the pack's manifest, and picks a random sound while avoiding repeats.

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

99 packs across Warcraft, StarCraft, Red Alert, Portal, Zelda, Dota 2, Helldivers 2, Elder Scrolls, and more. The default install includes 5 curated packs:

| Pack | Character | Sounds |
|---|---|---|
| `peon` (default) | Orc Peon (Warcraft III) | "Ready to work?", "Work, work.", "Okie dokie." |
| `peasant` | Human Peasant (Warcraft III) | "Yes, milord?", "Job's done!", "Ready, sir." |
| `sc_kerrigan` | Sarah Kerrigan (StarCraft) | "I gotcha", "What now?", "Easily amused, huh?" |
| `sc_battlecruiser` | Battlecruiser (StarCraft) | "Battlecruiser operational", "Make it happen", "Engage" |
| `glados` | GLaDOS (Portal) | "Oh, it's you.", "You monster.", "Your entire team is dead." |

**[Browse all packs with audio previews &rarr; openpeon.com/packs](https://openpeon.com/packs)**

Install all with `--all`, or switch packs anytime:

```bash
peon packs use glados             # switch to a specific pack
peon packs use --install glados   # install (or update) and switch in one step
peon packs next                   # cycle to the next pack
peon packs list                   # list all installed packs
peon packs list --registry        # browse all available packs
peon packs install glados,murloc  # install specific packs
peon packs install --all          # install every pack in the registry
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

- **macOS** — `afplay` (built-in), JXA Cocoa overlay or AppleScript for notifications
- **Linux** — one of: `pw-play`, `paplay`, `ffplay`, `mpv`, `play` (SoX), or `aplay`; `notify-send` for notifications
- **Windows** — native PowerShell with `MediaPlayer` and WinForms (no WSL required), or WSL2
- **All platforms** — `python3` (not required for native Windows)
- **SSH/remote** — `curl` on the remote host
- **IDE** — Claude Code with hooks support (or any supported IDE via [adapters](#multi-ide-support))

## How it works

`peon.sh` is a Claude Code hook registered for `SessionStart`, `SessionEnd`, `SubagentStart`, `Stop`, `Notification`, `PermissionRequest`, `PostToolUseFailure`, and `PreCompact` events. On each event:

1. **Event mapping** — an embedded Python block maps the hook event to a [CESP](https://github.com/PeonPing/openpeon) sound category (`session.start`, `task.complete`, `input.required`, etc.)
2. **Sound selection** — picks a random voice line from the active pack's manifest, avoiding repeats
3. **Audio playback** — plays the sound asynchronously via `afplay` (macOS), PowerShell `MediaPlayer` (WSL2), or `pw-play`/`paplay`/`ffplay`/`mpv`/`aplay` (Linux)
4. **Notifications** — updates the Terminal tab title and sends a desktop notification if the terminal isn't focused
5. **Remote routing** — in SSH sessions, devcontainers, and Codespaces, audio and notification requests are forwarded over HTTP to a [relay server](#remote-development-ssh--devcontainers--codespaces) on your local machine

Sound packs are downloaded from the [OpenPeon registry](https://github.com/PeonPing/registry) at install time. The official packs are hosted in [PeonPing/og-packs](https://github.com/PeonPing/og-packs). Sound files are property of their respective publishers (Blizzard, Valve, EA, etc.) and are distributed under fair use for personal notification purposes.

## Links

- [@peonping on X](https://x.com/peonping) — updates and announcements
- [peonping.com](https://peonping.com/) — landing page
- [openpeon.com](https://openpeon.com/) — CESP spec, pack browser, [integration guide](https://openpeon.com/integrate), creation guide
- [OpenPeon registry](https://github.com/PeonPing/registry) — pack registry (GitHub Pages)
- [og-packs](https://github.com/PeonPing/og-packs) — official sound packs
- [peon-pet](https://github.com/PeonPing/peon-pet) — macOS desktop pet (orc sprite, reacts to hook events)
- [License (MIT)](LICENSE)

## Support the project

- Venmo: [@garysheng](https://venmo.com/garysheng)
- Community Token (DYOR / have fun): Someone created a $PEON token on Base — we receive TX fees which help fund development. [`0xf4ba744229afb64e2571eef89aacec2f524e8ba3`](https://dexscreener.com/base/0xf4bA744229aFB64E2571eef89AaceC2F524e8bA3)

