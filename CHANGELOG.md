# Changelog

## v2.6.0 (2026-02-19)

### Added
- `suppress_subagent_complete` config option (default: `false`) — when enabled, suppresses `task.complete` sounds and notifications for sub-agent sessions spawned via Claude Code's Task tool, so only the parent session's completion sound fires

## v2.5.0 (2026-02-18)

### Added
- `cwd` field in `last_active` state (`.state.json`) — records the working directory of each hook invocation, enabling [peon-pet](https://github.com/PeonPing/peon-pet) to display the project folder name in session dot tooltips

## v2.4.1 (2026-02-18)

### Fixed
- Pack rotation: `session_packs` entries in dict format (after cleanup upgrade) were not recognized by the `in pack_rotation` check, causing a new random pack to be picked on every non-SessionStart event — same session could play sounds from different characters each turn
- `SubagentStart` now exits silently after saving state — previously could play `task.acknowledge` sound on the parent session
- Task-spawned subagent sessions now inherit the parent session's voice pack via `pending_subagent_pack` state, ensuring a single conversation always uses one character

## v2.4.0 (2026-02-18)

### Added
- Project-local config override: place a `config.json` at `.claude/hooks/peon-ping/config.json` in any project to override the global config for that project only

### Fixed
- `hook-handle-use.sh`: macOS BSD sed does not support `\s`/`\S` — replaced with POSIX `[[:space:]]`/`[^[:space:]]` classes (closes #212)
- OpenCode plugin: `desktop_notifications: false` in config was ignored — AppleScript notifications now respect the setting (closes #207)
- OpenCode plugin: Linux audio backend chain now matches `peon.sh` priority order (`pw-play` → `paplay` → `aplay`) with correct per-backend volume scaling

## v2.3.0 (2026-02-18)

### Added
- `peon volume [0.0-1.0]` CLI command — get or set volume from the terminal
- `peon rotation [random|round-robin|agentskill]` CLI command — get or set pack rotation mode from the terminal

### Fixed
- macOS overlay (`mac-overlay.js`) is now correctly copied during install — previously only `.sh`/`.ps1`/`.swift` scripts were copied, so the visual overlay banner never appeared
- Resume sessions (`source: "resume"`) preserve the active voice pack instead of picking a new random one

### Changed
- Default pack set reduced to 5 curated WC/SC/Portal packs: `peon`, `peasant`, `sc_kerrigan`, `sc_battlecruiser`, `glados`

## v2.2.3 (2026-02-18)

### Changed
- `UserPromptSubmit` removed from default registered hooks — peon no longer fires on every user message. The `/peon-ping-use` skill hook remains registered under `UserPromptSubmit`. Re-add manually to `~/.claude/settings.json` if you want the annoyed easter egg or `task.acknowledge`.
- `task.acknowledge` default changed to `false` in `config.json` template (was `true`, which caused a sound on every message even without the hook firing explicitly)

This also mitigates the Windows console raw mode issue (#205) where spawning `powershell.exe` on every `UserPromptSubmit` corrupted Claude Code's keyboard input.

## v2.2.2 (2026-02-18)

### Fixed
- `peon-play` and `mac-overlay.js` now resolve correctly on Homebrew/adapter installs where `$PEON_DIR` is remapped (same root cause as the `pack-download.sh` issue fixed in v2.2.1)
- Overlay notifications fall through to standard notifications when `mac-overlay.js` is not found rather than silently failing
- `USE_SOUND_EFFECTS_DEVICE` unbound variable crash in `play_sound` when called from preview context

## v2.2.1 (2026-02-18)

### Fixed
- `peon packs install`, `peon packs use --install`, and `peon packs list --registry` now correctly locate `pack-download.sh` on Homebrew and adapter installs where `$PEON_DIR` is remapped away from the script directory ([#204](https://github.com/PeonPing/peon-ping/pull/204))
- Test isolation: `PEON_TEST=1` now exported globally in test setup so all `run bash peon.sh` calls correctly skip the Homebrew path probe

## v2.2.0 (2026-02-17)

### Added
- MCP server (`mcp/`) for agent-driven sound playback via Model Context Protocol
- OpenClaw adapter documented in README and llms.txt
- `SubagentStart` and `PostToolUseFailure` now registered in installer hook list
- `task.error` and `task.acknowledge` added to "What you'll hear" README table
- `/peon-ping-use` and `/peon-ping-log` skills documented in CLAUDE.md and llms.txt

### Fixed
- MCP server: `pw-play` volume now uses correct 0.0–1.0 float scale (was 0–65536)
- MCP server: reads volume from `config.json` instead of requiring `PEON_VOLUME` env var
- `openclaw.sh`: error events now map to `PostToolUseFailure` (task.error) not `Stop`
- `peon help`: added missing `mobile on/pushover/telegram` and `relay --bind` entries
- Windows installer: `PostToolUseFailure` and `SubagentStart` now registered and handled

### Changed
- Pack count updated to 75+ across all docs
- Hero copy updated to "any AI agent" framing with MCP server mention

## v2.1.1 (2026-02-17)

### Security
- Pass WSL Windows Forms notification message via temp file to prevent PowerShell script injection ([#187](https://github.com/PeonPing/peon-ping/pull/187))

### Added
- macOS JXA Cocoa overlay notifications with configurable `overlay`/`standard` styles and `peon notifications` CLI ([#185](https://github.com/PeonPing/peon-ping/pull/185))
- CESP §5.5 icon resolution chain for pack-aware notifications (sound → category → pack → icon.png → default) with path traversal protection ([#189](https://github.com/PeonPing/peon-ping/pull/189))

### Fixed
- Background relay health check on SessionStart to avoid blocking greeting sound for SSH/devcontainer users ([#190](https://github.com/PeonPing/peon-ping/pull/190))
- OpenCode adapter `task.complete` debounce increased to 5s to prevent repeated notifications in plan mode ([#188](https://github.com/PeonPing/peon-ping/pull/188))

## v2.1.0 (2026-02-17)

### Added
- `peon packs install <pack1,pack2>` and `peon packs install --all` for post-install pack management ([#179](https://github.com/PeonPing/peon-ping/pull/179))
- `peon packs list --registry` to browse all available packs from the registry ([#179](https://github.com/PeonPing/peon-ping/pull/179))
- Bash and fish shell completions for new packs commands ([#179](https://github.com/PeonPing/peon-ping/pull/179))
- Shared `scripts/pack-download.sh` engine extracted from installer ([#179](https://github.com/PeonPing/peon-ping/pull/179))

### Fixed
- Local installs (`--local`) now use correct `INSTALL_DIR` for skill hook paths instead of hardcoded global path ([#180](https://github.com/PeonPing/peon-ping/pull/180))
- Cursor IDE hooks registration now handles flat-array `hooks.json` format

## v2.0.0 (2026-02-16)

### Added
- **Peon Trainer**: Pavel-style daily exercise mode — 300 pushups and 300 squats per day, tracked through your coding sessions
- Trainer CLI: `peon trainer on/off/status/log/goal/help` subcommands
- Trainer reminders piggyback on IDE hook events every ~20 minutes with orc peon voice lines
- Session-start encouragement: peon immediately greets you with a workout prompt when you start a new coding session
- 24 ElevenLabs orc voice lines across 5 categories: session_start, remind, log, complete, slacking
- Pace-based slacking detection: past noon with less than 25% progress triggers slacking voice lines
- Daily auto-reset at midnight
- Configurable goals (`peon trainer goal 200`) and per-exercise goals (`peon trainer goal pushups 100`)
- Trainer section in README with quick start guide

## v1.8.2 (2026-02-15)

### Fixed
- SHA256 checksum-based caching for sound downloads: re-runs skip files that are already downloaded and intact, corrupted files are auto-detected and re-downloaded ([#164](https://github.com/PeonPing/peon-ping/pull/164))
- URL-encode special characters (`?`, `!`, `#`) in filenames when downloading from GitHub, fixing packs with filenames like `New_construction?.mp3` ([#164](https://github.com/PeonPing/peon-ping/pull/164))
- Allow `?` and `!` in sound filenames (`is_safe_filename`) ([#164](https://github.com/PeonPing/peon-ping/pull/164))
- Remove destructive `rm -rf` that wiped all sounds before re-downloading on updates ([#164](https://github.com/PeonPing/peon-ping/pull/164))

## v1.8.1 (2026-02-13)

### Fixed
- Eliminate test race conditions: `peon.sh` runs afplay synchronously in test mode instead of relying on sleep ([#134](https://github.com/PeonPing/peon-ping/pull/134))
- Local uninstall now cleans hooks from global `settings.json` ([#134](https://github.com/PeonPing/peon-ping/pull/134))
- Background sound playback and notifications on WSL/Linux to avoid blocking the IDE ([#132](https://github.com/PeonPing/peon-ping/pull/132))

## v1.8.0 (2026-02-13)

### Added
- **Native Windows support**: PowerShell installer (`install.ps1`), hook script (`peon.ps1`), and uninstaller with two-tier audio fallback (WPF MediaPlayer + SoundPlayer) ([#105](https://github.com/PeonPing/peon-ping/pull/105))
- **Windsurf adapter**: Full CESP adapter for Windsurf Cascade hooks with session tracking ([#130](https://github.com/PeonPing/peon-ping/pull/130))
- **Kilo CLI adapter**: Native TypeScript plugin for Kilo CLI (OpenCode fork) ([#129](https://github.com/PeonPing/peon-ping/pull/129))
- **Install progress bar**: Live-updating per-pack progress bar in TTY mode, dot-based fallback for non-TTY ([#121](https://github.com/PeonPing/peon-ping/pull/121))
- **OpenCode adapter tests**: 21 BATS tests covering install, uninstall, idempotency, XDG support, and icon replacement ([#131](https://github.com/PeonPing/peon-ping/pull/131))

### Fixed
- Fix code injection vulnerability in `peon packs use/remove` — pack args now passed via env vars ([#127](https://github.com/PeonPing/peon-ping/pull/127))
- Fix `pw-play` silent on non-English locales by setting `LC_ALL=C` ([#124](https://github.com/PeonPing/peon-ping/pull/124))
- Fix Telegram API call to use POST body instead of URL params ([#128](https://github.com/PeonPing/peon-ping/pull/128))
- Replace bare `except:` clauses with `except Exception:` across all embedded Python ([#126](https://github.com/PeonPing/peon-ping/pull/126))
- Remove broken symlink before curl download in OpenCode adapter ([#125](https://github.com/PeonPing/peon-ping/pull/125))
- Remove Claude Code paths from OpenCode icon resolution ([#123](https://github.com/PeonPing/peon-ping/pull/123))
- Fix race condition in peon.bats (background afplay timing)
- Fix install.bats `--local` tests to check correct settings.json path

## v1.7.1 (2026-02-13)

### Fixed
- `peon packs list` and other CLI commands now work correctly for Homebrew installs ([#101](https://github.com/PeonPing/peon-ping/issues/101))

## v1.7.0 (2026-02-12)

### Added
- **SSH remote audio support**: Auto-detects SSH sessions and routes audio through a relay server running on your local machine (`peon relay`)
- **Relay daemon mode**: `peon relay --daemon`, `--stop`, `--status` for persistent background relay
- **Devcontainer / Codespaces support**: Auto-detects container environments and routes audio to `host.docker.internal`
- **Mobile push notifications**: `peon mobile ntfy|pushover|telegram` — get phone notifications via ntfy.sh, Pushover, or Telegram
- **Enhanced `peon status`**: Shows active pack, installed pack count, and detected IDE ([#91](https://github.com/PeonPing/peon-ping/pull/91))
- **Relay test suite**: 20 tests covering health, playback, path traversal protection, notifications, and daemon mode
- **Automated Homebrew tap updates**: Release workflow now auto-updates `PeonPing/homebrew-tap`

### Fixed
- Prevent duplicate hooks when both global and local installs exist
- Correct Ghostty process name casing in focus detection ([#92](https://github.com/PeonPing/peon-ping/pull/92))
- Suppress replay sounds during session continue ([#19](https://github.com/PeonPing/peon-ping/issues/19))
- Harden installer reliability ([#93](https://github.com/PeonPing/peon-ping/pull/93))

## v1.6.0 (2026-02-12)

### Breaking
- **Subcommand CLI**: All `--flag` commands replaced with subcommands. `peon --pause` is now `peon pause`, `peon --packs` is now `peon packs list`, etc. ([#90](https://github.com/PeonPing/peon-ping/pull/90))

### Added
- **Homebrew install**: `brew install PeonPing/tap/peon-ping` as primary install method
- **Multi-IDE messaging**: Updated all docs and landing page to highlight Claude Code, Codex, Cursor, and OpenCode support
- **`peon packs remove`**: Uninstall specific packs without removing everything ([#89](https://github.com/PeonPing/peon-ping/pull/89))
- **`peonping.com/install` redirect**: Clean install URL via Vercel redirect
- **Dynamic pack counts**: peonping.com fetches live pack count from registry at runtime
- **Session replay suppression**: Sounds no longer fire 3x when continuing a session with `claude -c` ([#19](https://github.com/PeonPing/peon-ping/issues/19))

### Fixed
- Handle read-only shell rc files during install ([#86](https://github.com/PeonPing/peon-ping/issues/86))
- Fix raw escape codes in OpenCode adapter output ([#88](https://github.com/PeonPing/peon-ping/pull/88))
- Fix OpenCode adapter registry lookup and add missing plugin file

## v1.5.14 (2026-02-12)

### Added
- **Registry-based pack discovery**: install.sh fetches packs from the [OpenPeon registry](https://github.com/PeonPing/registry) instead of bundling sounds in the repo
- **CESP standard**: Migrated to the [Coding Event Sound Pack Specification](https://github.com/PeonPing/openpeon) with `openpeon.json` manifests
- **Multi-IDE adapters**: Cursor (`adapters/cursor.sh`), Codex (`adapters/codex.sh`), OpenCode (`adapters/opencode.sh`)
- **`--packs` flag**: Install specific packs by name (`--packs=peon,glados,peasant`)
- **Interactive pack picker**: peonping.com lets you select packs and generates a custom install command
- **`silent_window_seconds`**: Suppress sounds for tasks shorter than N seconds ([#82](https://github.com/PeonPing/peon-ping/pull/82))
- **Help on bare invocation**: Running `peon` with no args on a TTY shows usage ([#83](https://github.com/PeonPing/peon-ping/pull/83))
- **Desktop notification toggle**: Independent `desktop_notifications` config option ([#47](https://github.com/PeonPing/peon-ping/issues/47))
- **Duke Nukem** sound pack
- **Red Alert Soviet Soldier** sound pack

### Fixed
- Missing sound file references in several packs
- zsh completions `bashcompinit` ordering

## v1.4.0 (2026-02-12)

### Added
- **Stop debouncing**: Prevents sound spam from rapid background task completions
- **Pack rotation**: Configure multiple packs in `pack_rotation`, each session picks one randomly
- **CLAUDE_CONFIG_DIR** support for non-standard Claude installs ([#61](https://github.com/PeonPing/peon-ping/pull/61))
- **13 community sound packs**: Czech (peon_cz, peasant_cz), Spanish (peon_es, peasant_es), RA2 Kirov, WC2 Peasant, AoE2, Russian Brewmaster, Elder Scrolls (Molag Bal, Sheogorath), Dota 2 Axe, Helldivers 2, Sopranos, Rick Sanchez

## v1.2.0 (2026-02-11)

### Added
- **WSL2 (Windows) support**: PowerShell `MediaPlayer` audio backend with visual popup notifications
- **PermissionRequest hook**: Sound alert when IDE needs permission approval
- **`peon --pack` command**: Switch packs from CLI with tab completion and cycling
- **Performance**: Consolidated 5 Python invocations into 1 per hook event
- **Polish Orc Peon** sound pack ([#9](https://github.com/PeonPing/peon-ping/pull/9))
- **French packs**: Human Peasant (FR) and Orc Peon (FR) ([#7](https://github.com/PeonPing/peon-ping/pull/7))

### Fixed
- Prevent install.sh from hanging when run via `curl | bash` ([#8](https://github.com/PeonPing/peon-ping/pull/8))

## v1.1.0 (2026-02-11)

### Added
- **Pause/mute toggle**: `peon --toggle` CLI and `/peon-ping-toggle` slash command ([#6](https://github.com/PeonPing/peon-ping/pull/6))
- **Battlecruiser + Kerrigan** sound packs
- **RA2 Soviet Engineer** sound pack
- **Self-update check**: Checks for new versions once per day
- **BATS test suite**: 30+ automated tests with CI ([#5](https://github.com/PeonPing/peon-ping/pull/5))
- **Terminal-agnostic tab titles**: ANSI escape sequences instead of AppleScript ([#3](https://github.com/PeonPing/peon-ping/pull/3))

### Fixed
- Hook runner compatibility ([#5](https://github.com/PeonPing/peon-ping/pull/5))

## v1.0.0 (2026-02-10)

### Added
- Initial release
- Warcraft III Orc Peon and GLaDOS sound packs
- Claude Code hook for `SessionStart`, `UserPromptSubmit`, `Stop`, `Notification`
- Desktop notifications (macOS)
- Terminal tab title updates
- Agent session detection (suppress sounds in delegate mode)
- macOS + Linux audio support
