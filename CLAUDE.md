# CLAUDE.md

Developer guide for AI coding agents working on this codebase. For user-facing docs (install, configuration, CLI usage, sound packs, remote dev, mobile notifications), see [README.md](README.md).

## Commands

```bash
# Run all tests (requires bats-core: brew install bats-core)
bats tests/

# Run a single test file
bats tests/peon.bats
bats tests/install.bats

# Run a specific test by name
bats tests/peon.bats -f "SessionStart plays a greeting sound"

# Install locally for development
bash install.sh --local

# Install only specific packs
bash install.sh --packs=peon,glados,peasant
```

There is no build step, linter, or formatter configured for the shell codebase.

See [RELEASING.md](RELEASING.md) for the full release process (version bumps, tagging, Homebrew tap updates).

## Related Repos

peon-ping is part of the [PeonPing](https://github.com/PeonPing) org:

| Repo | Purpose |
|---|---|
| **[peon-ping](https://github.com/PeonPing/peon-ping)** (this repo) | CLI tool, installer, hook runtime, IDE adapters |
| **[registry](https://github.com/PeonPing/registry)** | Pack registry (`index.json` served via GitHub Pages at `peonping.github.io/registry/index.json`) |
| **[og-packs](https://github.com/PeonPing/og-packs)** | Official sound packs (40+ packs, tagged releases) |
| **[homebrew-tap](https://github.com/PeonPing/homebrew-tap)** | Homebrew formula (`brew install PeonPing/tap/peon-ping`) |
| **[openpeon](https://github.com/PeonPing/openpeon)** | CESP spec + openpeon.com website (Next.js in `site/`) |

## Architecture

### Core Files

- **`peon.sh`** — Main hook script. Receives JSON event data on stdin, routes events via an embedded Python block that handles config loading, event parsing, sound selection, and state management in a single invocation. Shell code then handles async audio playback (`nohup` + background processes), desktop notifications, and mobile push notifications.
- **`relay.sh`** — HTTP relay server for SSH/devcontainer/Codespaces. Runs on the local machine, receives audio and notification requests from remote sessions.
- **`install.sh`** — Installer. Fetches pack registry from GitHub Pages, downloads selected packs, registers hooks in `~/.claude/settings.json`. Falls back to a hardcoded pack list if registry is unreachable.
- **`config.json`** — Default configuration template.

### Event Flow

IDE triggers hook → `peon.sh` reads JSON stdin → single Python call maps events to CESP categories (`session.start`, `task.complete`, `input.required`, `user.spam`, etc.) → picks a sound (no-repeat logic) → shell plays audio async and optionally sends desktop/mobile notification.

### Platform Detection

`peon.sh` detects the runtime environment and routes audio accordingly:

- **mac / linux / wsl2** — Direct audio playback via native backends
- **ssh** — Detected via `SSH_CONNECTION`/`SSH_CLIENT` env vars → relay at `localhost:19998`
- **devcontainer** — Detected via `REMOTE_CONTAINERS`/`CODESPACES` env vars → relay at `host.docker.internal:19998`

### Multi-IDE Adapters

- **`adapters/codex.sh`** — Translates OpenAI Codex events to CESP JSON
- **`adapters/cursor.sh`** — Translates Cursor events to CESP JSON
- **`adapters/opencode.sh`** — Installer for OpenCode adapter
- **`adapters/opencode/peon-ping.ts`** — Full TypeScript CESP plugin for OpenCode IDE
- **`adapters/kilo.sh`** — Installer for Kilo CLI adapter (downloads and patches the OpenCode plugin)
- **`adapters/kiro.sh`** — Translates Kiro CLI (Amazon) events to CESP JSON
- **`adapters/antigravity.sh`** — Filesystem watcher for Google Antigravity agent events

All adapters translate IDE-specific events into the standardized CESP JSON format that `peon.sh` expects.

### Platform Audio Backends

- **macOS:** `afplay`
- **WSL2:** PowerShell `MediaPlayer`
- **Linux:** priority chain: `pw-play` → `paplay` → `ffplay` → `mpv` → `play` (SoX) → `aplay` (each with different volume scaling)
- **SSH/devcontainer:** HTTP relay to local machine (see `relay.sh`)

### State Management

`.state.json` persists across invocations: agent session tracking (suppresses sounds in delegate mode), pack rotation index, prompt timestamps (for annoyed easter egg), last-played sounds (no-repeat), and stop debouncing.

### Pack System

Packs use `openpeon.json` ([CESP v1.0](https://github.com/PeonPing/openpeon)) manifests with dotted categories mapping to arrays of `{ "file": "sound.wav", "label": "text" }` entries. Packs are downloaded at install time from the [OpenPeon registry](https://github.com/PeonPing/registry) into `~/.claude/hooks/peon-ping/packs/`. The registry `index.json` contains `source_repo`, `source_ref`, and `source_path` fields pointing to each pack's source (official packs in og-packs, community packs in contributor repos).

## Testing

Tests use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). Test setup (`tests/setup.bash`) creates isolated temp directories with mock audio backends, manifests, and config so tests never touch real state. Key mock: `afplay` is replaced with a script that logs calls instead of playing audio.

CI runs on macOS (`macos-latest`) via GitHub Actions.

## Skills

Two Claude Code skills live in `skills/`:
- `/peon-ping-toggle` — Mute/unmute sounds
- `/peon-ping-config` — Modify any peon-ping setting (volume, packs, categories, etc.)

## Website

`docs/` contains the static landing page ([peonping.com](https://peonping.com)), deployed via Vercel. A `vercel.json` in `docs/` provides the `/install` redirect so `curl -fsSL peonping.com/install | bash` works. `video/` is a separate Remotion project for promotional videos (React + TypeScript, independent from the main codebase).
