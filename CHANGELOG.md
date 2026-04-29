## Unreleased

### Added
- **Per-sound disable toggles.** New `disabled_sounds` config key (keyed by pack → category → array of filenames) lets you silence individual sounds within a pack without removing the file or disabling the whole category. If every sound in a category is disabled, the category stays silent for that pack. Three new CLI commands drive it: `peon sounds list [pack]` lists sounds with a `<-- disabled` marker, `peon sounds disable <category> <file> [--pack=<name>]` mutes a single sound, and `peon sounds enable ...` re-enables it. Applies across `peon.sh`, the Windows `peon.ps1` runtime, and the SSH/devcontainer relay.

## v2.25.0 (2026-04-28)

### Added
- **`terminal_tab_title` config flag (default `true`) to opt out of tab title overrides**. Useful when you already manage tab titles via your shell prompt or terminal automation and only want peon-ping's sounds and notifications. Set to `false` to leave the existing tab title alone. PR #497, closes #406. Thanks @pandego.
- **`notification_title_ide` config flag (default `false`) to surface the IDE label in desktop notification titles**. When enabled, titles render as `Project - IDE` (for example `myrepo - OpenAI Codex`) so parallel sessions across Claude Code, Codex, Cursor, etc. are distinguishable at a glance. Notification message bodies were also restructured: status plus details on the body line so the title carries the project (and optionally IDE) cleanly. New `{ide}` and `{ide_id}` template variables are exposed to `notification_templates`, and `notification_title_script` now receives a `PEON_IDE` env var. Terminal tab titles continue to render as `project: status`. PR #495. Thanks @kibermaks.
- **`suppress_idle_prompt_repeats` (default `true`) and `idle_prompt_suppress_window_seconds` (default `3600`)**. Claude Code re-fires its `Notification`+`idle_prompt` event roughly every 60s while the terminal is unfocused, which without dedupe replays the same `task.complete` sound on every poke. peon.sh now records `last_task_complete[session_id]` in `.state.json` and suppresses subsequent `idle_prompt` events for the same session inside the configured window. Set the flag to `false` (or the window to `0`) to restore the periodic nudge. PR #493, closes #486. Thanks @yusufkinatas.

### Changed
- **`exclude_dirs` now fully silences sounds and notifications when the cwd matches**, instead of only skipping the `path_rules` layer. The original v2.22.0 semantics still let `ide_rules`, rotation, or `default_pack` fall through to play sound, which surprised users who reasonably expected an "exclude" key to mean silence. Excluded invocations now log `suppressed=True reason=excluded_dir pattern=<match>` and emit no audio or desktop notification. Use this for noisy background agents like CodexBar's ClaudeProbe, throwaway scratch directories, or sensitive workspaces. PR #494. Thanks @kibermaks.

### Fixed
- **`peon.sh` silently failed on Windows msys2/git-bash because the consolidated Python block exceeded `CreateProcess`'s ~32 KB argv limit.** The block had grown to ~47 KB after the state-helper injection, so `python3 -c "<block>"` returned `E2BIG` and the hook exited 0 with no logs, breaking every event (`Stop`, `Notification`, `PermissionRequest`, etc.) on git-bash. Hook now writes the block to a tempfile and invokes `python3 <path>` instead, with a `trap` for defensive cleanup. Stderr on this path is no longer suppressed so any future exec failure surfaces in `peon debug status`. Linux/macOS were unaffected (argv limits are in the megabytes); native Windows (`peon.ps1`) does not use this path. PR #492, closes #488. Thanks @lmagine.
- **OpenCode adapter config now syncs categories and spam settings from the canonical peon config, and OpenCode-sourced events honor those overrides at runtime**. Toggling a category like `user.spam` or tuning `annoyed_threshold` / `annoyed_window_seconds` previously had no effect on OpenCode sessions because the adapter copy at `~/.config/opencode/peon-ping/config.json` was not refreshed and the runtime did not look at it for category gating. PR #498, closes #458. Thanks @pandego.

## v2.24.0 (2026-04-25)

### Fixed
- **TTS now actually speaks**. The TTS pipeline landed earlier in the v2.20.x series was calling two backend scripts (`scripts/tts-native.sh` and `scripts/tts-native.ps1`) that had never been written to disk, so flipping `tts.enabled: true` produced no voice, no error, no log line. This release ships those backends. macOS `say`, Linux piper-with-model or espeak-ng (in that priority order), MSYS2/MINGW bridges to the Windows backend, native Windows SAPI5. After upgrading, `peon tts on` actually speaks. Defense-in-depth on text quoting (speech text comes in on stdin, never as argv) and numeric injection (rate / volume go through `awk -v`, not into awk source). PR #487, thanks @muunkky.
- **Windows `peon` CLI shim now prefers `pwsh` over `powershell.exe`**. On dev environments where `PSModulePath` has PowerShell 7 module dirs ahead of the PS 5.1 inbox paths (CloudSDK, Az, similar tooling having touched the env), Windows PowerShell 5.1 tries to load PS 7's incompatible `Microsoft.PowerShell.Security` and `Get-ExecutionPolicy` blows up, breaking every `peon …` invocation. The generated `peon.cmd` and bash shim now probe for `pwsh` first and fall back to `powershell.exe` only when pwsh is absent. PR #487.
- **Pester `removes hooks from settings.json` regression**. Test regex anchored on plain-dot literals (`peon\.ps1.*peon\.sh...`) had been failing on main since #485 narrowed the inner-hook filter from a bare `peon` string to escaped regex literals (`peon\\.ps1`, `peon\\.sh`). Loosened the assertion to allow the optional escaped backslash so both source forms match.

### Tests
- BATS test harness now resolves Python via `command -v python3` then `command -v python` instead of hardcoding `/usr/bin/python3` (four call sites in `tests/setup.bash`). Pester test setup canonicalizes `$env:TEMP` through `Push-Location` to expand 8.3 short names on GitHub Windows runners (`C:\Users\RUNNER~1\…`), and switches one `Set-Location` to `Set-Location -LiteralPath` so paths with bracket characters are handled correctly. PR #487.

## v2.23.0 (2026-04-25)

### Added
- **Claude Code integration in the Nix Home Manager module**. New `programs.peon-ping.claudeCodeIntegration` flag installs the Claude Code hook scripts under `~/.claude/hooks/peon-ping/` and merges the standard peon-ping hook entries into `~/.claude/settings.json`. PR #480, closes #368. Thanks @pandego.

### Fixed
- **Linux focus detection**. `terminal_is_focused` now checks both the X11 window class and the window title, so `zellij` running inside Alacritty is correctly detected as a terminal, while a window titled `start` no longer false-matches the `st` terminal. PR #491, closes #472. Thanks @pandego.
- **`peon packs install` failed for packs whose manifest sits at the registry source repo root**. An empty `source_path` is a valid "manifest at root" signal, but `pack-download.sh` was treating it as missing metadata and falling back to the og-packs registry. Aligned with the Windows installer's existing handling. PR #490, closes #343. Thanks @ventopreto.
- **`install.sh` and `peon update` dropped sibling custom hooks**. The matcher-entry filter was too coarse and removed the entire matcher entry whenever any inner hook contained `peon.sh` or `notify.sh`, silently nuking unrelated hooks composed under the same matcher. Now filters at the inner-hook level. Symmetric fix in `install.sh`, `install.ps1`, `uninstall.sh`, `uninstall.ps1`. PR #485, closes #484. Thanks @tarekrached.
- **`save_sound_pid $!` aborted hooks under `set -u` when audio ran synchronously**. In `PEON_TEST=1` paths and any branch where the player call returned without backgrounding, `$!` was unset and tripped nounset. The four `play_linux_sound` call sites now skip `save_sound_pid` in test/sync mode, and `save_sound_pid` itself early-returns on an empty arg as defense in depth.

### Tests
- Windows Pester expectations recalibrated to match the runtime changes from #475 (`Test-PathRuleMatch`, `pack_rotation.Count`, IDE-rule status output). PR #479, closes #478. Thanks @kibermaks.

### Docs
- Chinese and Japanese READMEs updated with the new Nix `claudeCodeIntegration` option and the split between Claude Code (auto-installed) and other-IDE (opt-in) hook setup.

## v2.22.0 (2026-04-19)

### Added
- **IDE-based pack rules**. New `ide_rules` config layer and `peon packs ide-bind/unbind/bindings` CLI for assigning packs by IDE/source, e.g. `peon packs ide-bind codex glados`. Adapters now emit a `source` field so routing is explicit. Useful when multiple agents share a workspace (Conductor, CodexBar, parallel agent teams). PR #475, closes #298. Thanks @kibermaks.
- **Path exclusions for path_rules**. New `exclude_dirs` config and `peon packs exclude add/remove/list` CLI to skip `path_rules` for specific globs or directory trees. Pairs with `ide_rules` for workspaces that share paths across IDEs. PR #475.
- Pack selection hierarchy expanded to 6 layers: session_override, path_rules, ide_rules, pack_rotation, default_pack, hardcoded. First valid installed pack wins. If `exclude_dirs` matches the current cwd, the `path_rules` layer is skipped for that invocation.

### Fixed
- **`{summary}` template variable empty for Claude, Codex, and Gemini turn-complete hooks**. `peon.sh` now falls through `last_assistant_message`, `last-assistant-message`, `prompt_response`, `transcript_summary`, `message` when resolving `{summary}` for notification and TTS templates. Windows `install.ps1` parity. PR #477, closes #476. Thanks @pandego, @Jorjon.

## v2.21.0 (2026-04-17)

### Added
- **Day-of-week trainer schedule**. New `schedule` config block under `trainer` lets you set per-weekday goals (e.g. pushups Mon/Wed/Fri, squats Tue/Thu/Sat). Setting a goal of `0` marks a rest day, which skips reminders and shows `[REST DAY]` in `peon trainer status`. New CLI commands: `peon trainer goal <exercise> <day> <n>` and `peon trainer goal <day> <n>`. Backwards-compatible with existing uniform `exercises` config. PR #474, closes #323. Thanks @garfieldnate.

### Docs
- Japanese README updated with the new trainer schedule commands and rest-day behavior.

## v2.20.1 (2026-04-16)

### Fixed
- **macOS notifications aborted on non-iTerm2/kitty terminals**. `local` declarations outside function scope in `scripts/notify.sh` caused Terminal.app, Warp, Ghostty, Zed, etc. to fail with `unbound variable` under `set -u`. Removed `local`, variables are now script-scoped. PR #471.
- **Overlay never displayed when `NSScreen.screens.count` probe returned empty**. The `|| echo 1` fallback only triggered on non-zero exit, not empty stdout. Added numeric-and-greater-than-zero validation so `seq 0 -1` never runs zero iterations on restricted macOS environments or when osascript is mocked. PR #471.
- **`notify.sh` exit code 1 leaked from `_run_overlay` subshell when `session_file` was empty**. Replaced the `[ -n "$session_file" ] && rm ...` short-circuit with explicit `if/then` so the subshell always exits 0. PR #471.
- **`peon notifications marker ""` now correctly disables the marker**. Previously both "no arg" and "empty arg" hit the "show current" branch because `${3:-}` collapsed them. Now `peon notifications marker` (no arg) shows current, `peon notifications marker ""` disables. Behavior change scoped to this edge case. PR #471.

### Docs
- **TTS architecture documents landed**. ADR-001 (backend architecture), TTS integration design doc, and PRD-003 (product requirements), all referenced in #442 but not previously committed. PR #471.

### Internal
- Pester tests updated to match the MediaPlayer MP3/WMA routing change from #442 (seven scenarios in `adapters-windows.Tests.ps1`, `peon-debug.Tests.ps1`, `peon-security.Tests.ps1`). PR #471.
- `tests/peon.bats` mac overlay ide_pid extraction anchored on `top-center` and walking backward to the first numeric token. Robust against TTY vs non-TTY test environments.

## v2.20.0 (2026-04-14)

### Added
- **Rich native macOS notifications** — `terminal-notifier` and osascript fallback now include a subtitle (CESP category) and group notifications by session so they replace each other in Notification Center instead of piling up. Uses `PEON_SESSION_ID` as the group key. PR #466.
- **`peon packs rotation add --install`** — add one or more packs to rotation AND download them from the registry in one command. Works with the flag before or after the pack names. PR #468.

### Changed
- **Security hardening**: migrated inline `'$SHELL_VAR'` interpolation in `python3 -c "..."` blocks throughout `peon.sh` to `os.environ.get()` pattern. Prevents quote-injection on config values with special characters; no behavior change for normal usage. PR #469.
- **Homebrew formula simplified**: delegates pack downloads in `peon-ping-setup` to the shared `pack-download.sh` engine rather than duplicating download/fallback logic in the Ruby formula. PR #15 (homebrew-tap).

### Docs
- **`peon setup` wizard guide added to README** — quickstart example, screenshots of the wizard flow, and a pointer back to per-setting `peon` subcommands for advanced users. PR #467.

## v2.19.0 (2026-04-14)

### Added
- **`peon setup` interactive wizard** — guided first-time setup covering volume, category toggles, desktop notifications, overlay theme, position, and auto-dismiss timing. PR #465, closes #283.
- **Session-based notification stacking** — notifications from the same Claude session now stack into a single overlay with a count badge (`(3) project — needs approval`). Auto-dismisses when the user resumes interaction (UserPromptSubmit, Stop, PreToolUse, etc.). New config: `notification_stacking` (default `true`). PR #463, addresses #340.
- **Visible X close button on overlays** — `glass`, `sakura`, and `jarvis` themes now show a discoverable `×` in the top-right. New config: `notification_close_button` (default `true`). PR #464.
- **`notification_title_marker` config** — customize or disable the `●` shown before project names in notification titles and terminal tabs. Set to `""` to disable, or `"🔔"` to customize. PR #457.
- **Expanded `peon status`** — structured sections (core, packs, categories, notifications, audio routing, behavior timings, trainer, TTS, debug, IDEs), resolved active pack display with path-rule reasoning, Linux player detection, relay status for SSH/devcontainer. PR #461.

### Fixed
- **NSPanel overlays no longer steal focus** — switched `glass`, `sakura`, `jarvis` themes to `NSPanel` with `NSWindowStyleMaskNonactivatingPanel` so clicking a notification doesn't dismiss iTerm2 hotkey/overlay windows. PR #462.
- **Correct overlay labels for red/yellow notifications** — color-based fallback no longer mislabels permission requests as "LIMIT REACHED". Red → "APPROVAL NEEDED", yellow → "STANDING BY". Disabled categories now suppress both sound AND the overlay. PR #460.
- **Pack sync robustness** — `pack-download.sh` now skips already-installed packs via on-disk checksum verification, probes the manifest URL before creating local directories, shows per-pack status (✓/✅/⚠️/❌), and includes a summary with counts and disk usage. Fixes a bug where filenames with spaces (e.g. `incoming (1).mp3`) re-downloaded every run due to incorrect checksum parsing. PR #453.
- **Linux `notify-send` respects `notification_dismiss_seconds`** — previously hardcoded to 5000ms, now uses the configured value. PR #455.
- **Nix home-manager zsh module** — updated `programs.zsh.initExtra` to `programs.zsh.initContent` for the current home-manager API. PR #456.

### Docs
- **Updated Warcraft III Orc peon mapping examples** in README (EN/zh/ja) to correctly reflect which voice lines belong to which CESP category. Closes #333.

## v2.18.0 (2026-04-11)

### Added
- **`--lang` flag for pack filtering** — filter sound packs by language during install and registry listing. Supports prefix matching (`--lang en` matches `en`, `en-GB`) and multi-language packs. Works with `install.sh`, `peon packs install`, and `peon packs list --registry`. PR #450, closes #395.

### Fixed
- **Sounds now play in delegate/autonomous mode** — sessions using `delegate` or `dangerouslySkipPermissions` permission mode (Conductor, Claude Desktop, etc.) are no longer silenced. Set `suppress_delegate_sessions: true` in config to restore old behavior. Also adds sound to `idle_prompt` notifications (maps to `task.complete`). Fixes #452.
- **WSL audio playback** — replaced `SoundPlayer` + `setsid` with `MediaPlayer` (PresentationCore) for WSL. Handles WAV/MP3 natively with volume control, no ffmpeg dependency. Fixes #446.
- **Windows MediaPlayer for MP3/WMA** — `win-play.ps1` now uses native `MediaPlayer` for `.mp3` and `.wma` files (not just `.wav`). No more silent failure when CLI players aren't installed. Fixes #451.
- **macOS osascript process accumulation** — overlay notification processes are now cleaned up proactively on each invocation (kills stale processes >30s old) and watchdog subshells are explicitly terminated after overlay exits. Prevents CPU-consuming buildup in long sessions. Fixes #449.
- **Windows git-bash stdin hang** — bounded stdin read to 2 seconds to prevent `cat` from blocking until the outer timeout fires. Fixes #445.

## v2.17.3 (2026-03-31)

### Fixed
- **_peon_log: command not found on peon preview** — added a no-op stub for `_peon_log` before `play_sound` is called. The function was only defined inside the main Python block but called unconditionally by `play_sound`, causing `peon preview` and `peon play` to emit a shell error. Fixes #421.


## v2.17.2 (2026-03-29)

### Fixed
- **WezTerm click-to-focus** — added WezTerm bundle ID (`com.github.wez.wezterm`) to `_mac_terminal_bundle_id()` so click-to-focus works in `standard` notification mode on macOS. Fixes #417.

## v2.17.1 (2026-03-29)

### Fixed
- **Hook stderr leak on /dev/tty** — wrapped all tty write sites in brace groups so bash's own redirect-open failure is suppressed by `2>/dev/null`. Previously, Claude Code (and any tool that inspects hook stderr) would see a spurious error on every session start when `/dev/tty` is unavailable (WSL2, headless). Fixes #407.
- **Spurious update notice** — added same-version guard on update notice display; stale `.update_available` files from previous installs are cleaned up silently instead of showing "2.17.0 → 2.17.0".
- **Themed overlay position** — glass, jarvis, and sakura themed overlays now respect `notification_position` config (was always defaulting to top-right). Brought to parity with default `mac-overlay.js`. Fixed by #413.

## v2.17.0 (2026-03-26)

### Added
- **Structured debug logging** — 9-phase decision tracing for hook execution (`peon debug on/off`, `peon logs`). Traces event routing, config loading, state management, pack selection, sound pick, playback, notification, trainer, and exit timing in a structured JSONL-like format.
- **`peon debug` CLI command** — toggle debug logging on/off with `peon debug on` and `peon debug off`. Check current state with `peon debug`.
- **`peon logs` CLI command** — view recent debug logs with `peon logs`, `peon logs --last N`, `peon logs --session`, and `peon logs --clear`. Daily log rotation with configurable retention.
- **`PEON_DEBUG=1` env var override** — enable debug logging for a single hook invocation without changing config.
- **`debug` and `debug_retention_days` config keys** — persistent debug toggle (default: `false`) and log retention period (default: 7 days).
- **Cross-platform debug parity** — identical structured log format on Unix (`peon.sh`) and Windows (`peon.ps1`).
- **Shared test fixtures** — BATS and Pester tests share fixture data enforcing format parity between platforms.
- **`peon status` verbose output** — now includes debug logging state.
- **Nix/Home Manager: custom pack sources** — `installPacks` now accepts both simple strings (for og-packs) and attribute sets with `name` and `src` fields to install packs from any source. The `src` field accepts any Nix fetcher result (e.g., `pkgs.fetchFromGitHub`), enabling community packs from the [openpeon.com registry](https://openpeon.com/) that aren't in og-packs while maintaining full reproducibility.

### Fixed
- **State contention test** — removed `|| true` that was silently masking assertion failures in concurrent state access tests.
- **Bash log helpers** — real millisecond timestamps and proper newline escaping in structured log output.
- **Missing exit/route logs** — added `[route]` and `[exit]` log entries to all early-exit paths for complete tracing.

## v2.16.1 (2026-03-20)

### Fixed
- **macOS persistent overlay (`dismiss=0`) killed by watchdog** — the shell-level safety watchdog in `notify.sh` computed `_max_wait = 0 + 5 = 5s`, killing the JXA overlay process 5 seconds after spawn even when the user had configured persistent notifications via `peon notifications dismiss 0`. Persistent mode now sets `_max_wait=86400` (24 h) so the overlay stays until clicked. (#344)
- **Linux `urgency=critical` overrides dismiss time** — `notify-send --urgency=critical` (used for red/error sounds) caused notification daemons like `dunst` and `mako` to ignore `--expire-time`, pinning the notification until manually dismissed regardless of `notification_dismiss_seconds`. Changed to always use `urgency=normal`; error sounds are already visually distinct via title/color. (#378)

## v2.16.0 (2026-03-20)

### Added
- **Windows WAV volume control** — replaced `SoundPlayer` (which ignores volume) with `MediaPlayer` (WPF/PresentationCore) in `win-play.ps1`. Volume is now respected for WAV playback on Windows. Uses `MediaOpened`/`MediaFailed` event subscription with dispatcher pump for reliable playback duration tracking. (#381)

### Fixed
- **RovoDev hook installer: multi-line YAML command values** — installer now correctly handles `- command:` entries whose values span multiple YAML continuation lines (e.g., multi-line `osascript` strings). The new hook entry is inserted after the full continuation block, preventing corruption of existing config. (#384)

## v2.15.2 (2026-03-15)

### Fixed
- **Shell quoting safety in peon.sh** — audited all 61 `python3 -c` invocations and fixed 3 hazardous patterns (7 occurrences) where escaped double quotes inside bash double-quoted strings could cause silent failures. Dict access and method args now use single-quoted Python strings extracted to temp variables.
- **Windows atomic state I/O hardening** — `Write-StateAtomic` now uses `Move-Item -Force` for truly atomic overwrites on PowerShell 7+, eliminating a sub-millisecond race window. `Read-StateWithRetry` cleans up orphaned `.tmp` files left by safety timer exits.
- **Windows ffplay install guidance** — post-install tip now recommends `choco install ffmpeg` (adds ffplay to PATH automatically), warns about `winget install ffmpeg` Gyan build PATH issues, and provides manual fallback instructions.
- **Windows CLI bind/unbind quality** — added `Get-ActivePack` helper for cross-platform parity with `peon.sh`, restored runtime `path_rules` matching engine, and added `--status` path_rules display. bind `--install` now shows download progress instead of running silently.

## v2.15.1 (2026-03-09)

### Fixed
- **Overlay themes show wrong status labels** — themed overlays (jarvis, glass, sakura) derived their banner label from notification color alone, causing mismatches: Stop events showed "INPUT REQUIRED", PermissionRequest showed "LIMIT REACHED", and idle prompts showed "LIMIT REACHED". Added a `NOTIFY_TYPE` semantic variable (`complete`/`permission`/`limit`/`idle`/`question`) that flows from `peon.sh` → `notify.sh` → overlay scripts as `argv[10]`, with color-based fallback preserved for relay.sh callers. Closes #342.

# Changelog

## v2.15.0 (2026-03-06)

### Added
- **`peon packs rotation clear`** — new subcommand to zero out the pack rotation in a single command. Sets `pack_rotation` to `[]` in config.json and syncs adapter configs. Closes #321.

### Fixed
- **`/peon-ping-rename` bleeds across tabs in same project** — names set in one terminal tab were appearing in all other tabs opened to the same project directory. Root cause: hooks run detached from the controlling terminal, so `tty` returned the same value across all tabs, collapsing the per-tab key. Switched to `$PPID` (Claude Code's process PID) as the stable tab identifier: different terminal tabs spawn separate Claude Code processes with different PIDs, while `/clear` within a tab reuses the same process. Composite key `ppid::cwd` replaces the previous `tty::cwd` key in `tty_names` state. Closes #325.


## v2.14.0 (2026-03-06)

### Added
- **Configurable SSH audio routing** (`peon ssh-audio [relay|auto|local]`) — choose how audio is routed in SSH sessions. `relay` (default) preserves existing behavior; `auto` tries relay then falls back to local playback on the SSH host; `local` always plays on the SSH host. Closes #206.

### Fixed
- **Nix/Home Manager: cursor adapter lookup** — `adapters/cursor.sh` now resolves `peon.sh` via a priority chain (`PEON_DIR` → `CLAUDE_PEON_DIR` → `$CLAUDE_CONFIG_DIR/hooks/peon-ping` → `$HOME/.openpeon`) instead of hardcoding `~/.claude`. Fixes Cursor in Nix installs.
- **Nix/Home Manager: reproducible pack installation** — sound packs now installed directly from the `og-packs` repo at a pinned version instead of a non-reproducible activation script.
- **Nix/Home Manager: hook setup documentation** — README now shows how to wire up IDE hooks manually in the Nix context; the HM module no longer attempts to manage hook files to avoid config conflicts. Closes #302.

## v2.13.1 (2026-03-05)

### Fixed
- **`/peon-ping-rename` title lost in plan mode** — when accepting a plan or entering plan mode, the session name would revert to the git repo/folder name. Early-exit paths (unknown events, unknown `Notification` types, `PostToolUseFailure` for non-Bash tools, `SubagentStart`, compact `SessionStart`) now emit `PROJECT`/`STATUS` so the shell still sets the tab title even when no sound plays.

## v2.13.0 (2026-03-03)

### Added
- **Rovo Dev CLI adapter** (`adapters/rovodev.sh`) — translates Rovo Dev event hooks (`on_complete`, `on_error`, `on_tool_permission`) into CESP categories for peon-ping sound playback. Argument-based (not stdin), matching Rovo Dev's shell command hook model.
- **Rovo Dev CLI auto-registration** — `install.sh` detects `~/.rovodev/config.yml` and automatically appends `eventHooks` configuration, so `peon-ping-setup` just works for Rovo Dev users.
- **`/peon-ping-rename` skill** — give the current Claude Code session a custom name shown in desktop notification titles and terminal tab title. Zero tokens consumed (intercepted by `UserPromptSubmit` hook). Names stored in `.state.json` keyed by session ID — multiple tabs in the same repo each get independent names. `/peon-ping-rename` with no argument resets to auto-detect.
- **`CLAUDE_SESSION_NAME` env var** — set before launching `claude` to give a session a fixed name at the environment level. Shows in both notification titles and terminal tab titles.
- **`notification_title_script` config key** — shell command run at event time to compute the project name dynamically. Receives `PEON_SESSION_ID`, `PEON_CWD`, `PEON_HOOK_EVENT`, `PEON_SESSION_NAME` env vars; stdout used as project name (max 50 chars).
- **Updated priority chain**: `/peon-ping-rename` > `CLAUDE_SESSION_NAME` > `.peon-label` > `notification_title_script` > `project_name_map` > `notification_title_override` > git repo name > folder name.

### Fixed
- `.peon-label` tier now correctly guarded with `if not project:` — was previously overwriting higher-priority tiers.

## v2.12.1 (2026-03-02)

### Fixed
- **mac-overlay cleanup** — orphaned `mac-overlay.js` osascript processes are now killed on `SessionEnd`, preventing stale overlay popups after Claude Code exits (#299, #301)
- **Adapter cooldown bug** — `amp.sh` and `antigravity.sh` no longer prematurely mark threads idle during the Stop cooldown window, fixing dropped Stop events for rapid task completions (#300)

## v2.12.0 (2026-02-27)

### Added
- **Windows PowerShell adapters** — native `.ps1` adapters for all 11 IDEs (codex, gemini, copilot, windsurf, kiro, openclaw, amp, antigravity, kimi, opencode, kilo). No Git Bash or WSL required. Filesystem watchers use .NET `FileSystemWatcher`. 198 Pester tests added. (#285)

### Fixed
- **OpenCode subagent noise** — filter subagent sessions from sound/notification events. Subagent sessions (spawned by Task tool with `parentID`) no longer trigger sounds for `session.idle`, `session.error`, and `session.status` events. (#290, fixes #289)


## v2.11.0 (2026-02-26)

### Added
- **Kimi Code adapter** — filesystem watcher for [Kimi Code CLI](https://github.com/MoonshotAI/kimi-cli) (MoonshotAI). Watches `~/.kimi/sessions/` for session events and translates them to CESP format. Uses the same `fswatch`/`inotifywait` pattern as the Amp and Antigravity adapters. Includes BATS tests.

## v2.10.1 (2026-02-25)

### Fixed
- Fix Ghostty terminal detection when running inside tmux: `_mac_terminal_bundle_id()` now falls back to env vars (`GHOSTTY_RESOURCES_DIR`, `ITERM_SESSION_ID`, `WARP_IS_LOCAL_SHELL_SESSION`) when `TERM_PROGRAM` is overwritten by tmux/screen (#269)
- Fix case-sensitive Ghostty process name in `terminal_is_focused()`: add lowercase `ghostty` match alongside `Ghostty` (#269)

## v2.10.0 (2026-02-23)

### Added
- **Amp adapter** — filesystem watcher for [Amp](https://ampcode.com) (Sourcegraph). Watches `~/.local/share/amp/threads/` for thread JSON file changes. Detects `SessionStart` (new thread) and `Stop` (agent finished turn, waiting for input) by inspecting the last message in the thread JSON. Uses the same `fswatch`/`inotifywait` + idle timer pattern as the Antigravity adapter, with an additional `thread_is_waiting()` check to confirm the agent isn't mid-tool-execution. Includes 17 BATS tests.

## v2.9.0 (2026-02-21)

### Added
- **MSYS2 / Git Bash platform support** — `install.sh`, `peon.sh`, and `scripts/notify.sh` now detect `MSYS_NT-*` / `MINGW*` uname strings as `"msys2"` platform. Audio plays via native players (`ffplay`, `mpv`, `play`) with PowerShell `win-play.ps1` fallback. Desktop notifications use Windows toast (standard) or Windows Forms overlay, with `cygpath -w` for path conversion.

## v2.8.0 (2026-02-20)

### Fixed
- **Cursor on Windows**: peon.ps1 now maps Cursor's camelCase event names (`sessionStart`, `stop`, etc.) to PascalCase, fixing no-sounds-on-new-chat when using Third-party skills
- **Cursor on Windows**: `install.ps1` and `uninstall.ps1` now handle Cursor's flat-array `hooks.json` format (matching `install.sh` fix from v2.7.x)
- peon.ps1 pack rotation: accept `session_override` alias in addition to `agentskill`

### Added
- Click-to-focus for IDE embedded terminals (Cursor, VS Code, Windsurf, Zed) — when `TERM_PROGRAM` doesn't map to a standalone terminal, falls back to deriving the IDE's bundle ID from its PID via `lsappinfo` (macOS built-in)
- PID-based `NSRunningApplication` activation in `mac-overlay.js` as belt-and-suspenders fallback when bundle ID lookup fails

## v2.7.0 (2026-02-19)

### Added
- `path_rules` config array: glob-pattern-based CWD-to-pack assignment (layer 3 in override hierarchy)
- Click-to-focus terminal on macOS notification click — overlay style detects terminal via `TERM_PROGRAM` → bundle ID mapping (Ghostty, Warp, iTerm2, Terminal.app); standard style uses `terminal-notifier` with `-activate`
- IDE PID detection (`_mac_ide_pid()`) for Cursor/Windsurf/Zed/VS Code ancestor click-to-focus

### Changed
- `active_pack` → `default_pack` (backward-compat fallback + `peon update` migration)
- `agentskill` rotation mode → `session_override` (`agentskill` accepted as alias)
- Override hierarchy (high→low): `session_override` > local project config > `path_rules` > `pack_rotation` > `default_pack`

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
