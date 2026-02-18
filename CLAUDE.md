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

# Install locally for development (Unix/WSL2)
bash install.sh --local

# Install only specific packs (Unix/WSL2)
bash install.sh --packs=peon,glados,peasant

# Install locally for development (native Windows)
powershell -ExecutionPolicy Bypass -File install.ps1

# Install specific packs (native Windows)
powershell -ExecutionPolicy Bypass -File install.ps1 -Packs peon,glados,peasant

# Install all packs (native Windows)
powershell -ExecutionPolicy Bypass -File install.ps1 -All
```

There is no build step, linter, or formatter configured for the shell codebase.

See [RELEASING.md](RELEASING.md) for the full release process (version bumps, tagging, Homebrew tap updates).

## Related Repos

peon-ping is part of the [PeonPing](https://github.com/PeonPing) org:

| Repo | Purpose |
|---|---|
| **[peon-ping](https://github.com/PeonPing/peon-ping)** (this repo) | CLI tool, installer, hook runtime, IDE adapters |
| **[registry](https://github.com/PeonPing/registry)** | Pack registry (`index.json` served via GitHub Pages at `peonping.github.io/registry/index.json`) |
| **[og-packs](https://github.com/PeonPing/og-packs)** | Official sound packs (40 packs, tagged releases) |
| **[homebrew-tap](https://github.com/PeonPing/homebrew-tap)** | Homebrew formula (`brew install PeonPing/tap/peon-ping`) |
| **[openpeon](https://github.com/PeonPing/openpeon)** | CESP spec + openpeon.com website (Next.js in `site/`) |

## Architecture

### Core Files

- **`peon.sh`** — Main hook script (Unix/WSL2). Receives JSON event data on stdin, routes events via an embedded Python block that handles config loading, event parsing, sound selection, and state management in a single invocation. Shell code then handles async audio playback (`nohup` + background processes), desktop notifications, and mobile push notifications.
- **`peon.ps1`** — Main hook script (native Windows). Pure PowerShell implementation with same event flow as `peon.sh` but without Python dependency. Handles JSON parsing, config/state management, CESP category mapping, sound selection (no-repeat logic), and async audio playback via `win-play.ps1`.
- **`relay.sh`** — HTTP relay server for SSH/devcontainer/Codespaces. Runs on the local machine, receives audio and notification requests from remote sessions.
- **`install.sh`** — Installer (Unix/WSL2). Fetches pack registry from GitHub Pages, registers hooks in `~/.claude/settings.json`, and delegates pack downloads to `pack-download.sh`. Falls back to a hardcoded pack list if registry is unreachable.
- **`install.ps1`** — Installer (native Windows). PowerShell version with registry fetching, pack downloads, hook registration, CLI shortcut creation (`peon.cmd` in `~/.local/bin`), and skills installation. Supports `-Packs` param for selective installs and `-All` for full registry.
- **`scripts/pack-download.sh`** — Shared pack download engine used by both `install.sh` and `peon packs install`. Handles registry fetching, pack validation, tarball downloads, and extraction.
- **`scripts/win-play.ps1`** — Windows audio playback backend. Async MP3/WAV player using `MediaPlayer` class with volume control.
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
- **`adapters/windsurf.sh`** — Translates Windsurf Cascade hook events to CESP JSON
- **`adapters/antigravity.sh`** — Filesystem watcher for Google Antigravity agent events

All adapters translate IDE-specific events into the standardized CESP JSON format that `peon.sh` expects.

### Platform Audio Backends

- **macOS:** `afplay`
- **WSL2:** PowerShell `MediaPlayer` (via `peon.sh` cross-platform detection)
- **Native Windows:** PowerShell `MediaPlayer` (via `scripts/win-play.ps1`)
- **Linux:** priority chain: `pw-play` → `paplay` → `ffplay` → `mpv` → `play` (SoX) → `aplay` (each with different volume scaling)
- **SSH/devcontainer:** HTTP relay to local machine (see `relay.sh`)

### State Management

`.state.json` persists across invocations: agent session tracking (suppresses sounds in delegate mode), pack rotation index, prompt timestamps (for annoyed easter egg), last-played sounds (no-repeat), and stop debouncing.

### Pack System

Packs use `openpeon.json` ([CESP v1.0](https://github.com/PeonPing/openpeon)) manifests with dotted categories mapping to arrays of `{ "file": "sound.wav", "label": "text" }` entries. Packs are downloaded at install time from the [OpenPeon registry](https://github.com/PeonPing/registry) into `~/.claude/hooks/peon-ping/packs/`. The registry `index.json` contains `source_repo`, `source_ref`, and `source_path` fields pointing to each pack's source (official packs in og-packs, community packs in contributor repos).

## Testing

Tests use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). Test setup (`tests/setup.bash`) creates isolated temp directories with mock audio backends, manifests, and config so tests never touch real state. Key mock: `afplay` is replaced with a script that logs calls instead of playing audio.

CI runs on macOS (`macos-latest`) via GitHub Actions.

## Releasing

After merging PRs that add features, fix bugs, or make notable changes, **proactively suggest a version bump**. Don't wait to be asked.

**When to bump:**
- **Patch** (1.8.1): bug fixes, small tweaks, test-only changes
- **Minor** (1.9.0): new features, new adapters, new platform support
- **Major** (2.0.0): breaking changes to config, hooks, or CLI

**Release checklist:**
1. Run `bats tests/` — all tests must pass
2. Update `CHANGELOG.md` — add new section at top with version, date, and categorized changes (Added/Fixed/Breaking)
3. Bump `VERSION` file
4. Commit: `git commit -m "chore: bump version to X.Y.Z"`
5. Tag: `git tag vX.Y.Z`
6. Push: `git push && git push --tags`

The tag push triggers CI to create a GitHub Release and auto-update the Homebrew tap.

See [RELEASING.md](RELEASING.md) for full details.

## Skills

Four Claude Code skills live in `skills/`:
- `/peon-ping-toggle` — Mute/unmute sounds
- `/peon-ping-config` — Modify any peon-ping setting (volume, packs, categories, etc.)
- `/peon-ping-use <pack>` — Assign a specific pack to the current agent session (agentskill mode)
- `/peon-ping-log <n> <exercise>` — Log exercise reps to the Peon Trainer (e.g. `/peon-ping-log 25 pushups`)

## Documentation rules

**Whenever `README.md` is updated, also update all language variants:**
- `README_zh.md` — Chinese translation (currently the only language variant)

Apply the same changes in the appropriate language. If a section is added to `README.md`, add the translated equivalent to each language README in the same location.

**Whenever the website or README is updated for a new feature, also update:**
- `docs/public/llms.txt` — peonping.com LLM context file
- `../openpeon/site/public/llms.txt` — openpeon.com LLM context file (if the feature relates to CESP/MCP/packs)

## Website

`docs/` contains the static landing page ([peonping.com](https://peonping.com)), deployed via Vercel. A `vercel.json` in `docs/` provides the `/install` redirect so `curl -fsSL peonping.com/install | bash` works. `video/` is a separate Remotion project for promotional videos (React + TypeScript, independent from the main codebase).
