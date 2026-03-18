# PR Draft: sprint/SMARTPACK

**Title:** `sprint/SMARTPACK: per-project pack assignment via path_rules and config key cleanup`

**Base:** `main`
**Head:** `sprint/SMARTPACK`
**Draft:** yes

---

## Motivation

peon-ping has always been one pack for everything. If you want GLaDOS on your work repos and Peon on personal projects, your options are: manually drop a `config.json` in each repo's `.claude/hooks/peon-ping/` directory, or run `/peon-ping-use <pack>` at the start of every session. Neither sticks — the first is tedious file management, the second is ephemeral.

This PR adds `path_rules` — glob-based rules that automatically select the right pack based on your working directory. You bind a pack to a path pattern once, and it just works from then on.

While adding this, we also cleaned up two config keys whose names had become misleading. `active_pack` sounds like "the pack currently playing" when it's actually the global fallback — renamed to `default_pack`. `agentskill` (a rotation mode) named the implementation mechanism (a Claude Code skill) instead of the behavior — renamed to `session_override`. Both renames include automatic migration via `peon update` and runtime fallback reads so existing configs keep working.

The design doc for this work is at `docs/plans/2026-02-19-path-rules-design.md`.

## Approach

The central design decision was the **override hierarchy** — five layers, most-specific wins:

```
session_override > local config > path_rules > pack_rotation > default_pack
```

The philosophy: more specific and more immediate beats more general. A temporary in-session choice beats a standing rule, which beats a global default. `path_rules` is a floor for matched repos, not a ceiling — you can always escape it for a session.

For the matching engine, we chose Python's `fnmatch` (already available in the embedded Python block) over shell globbing or regex. fnmatch gives users familiar glob syntax (`*`, `?`, `[seq]`) without regex complexity. First match wins — no merge semantics, no priority weighting, just a simple ordered list. If a matched pack isn't installed, the rule is skipped and evaluation continues down the list, which avoids hard failures when packs get removed.

Rather than asking users to hand-edit JSON arrays for `path_rules`, we added `peon packs bind/unbind/bindings` CLI commands. `bind` captures your cwd as the pattern by default (with `--pattern` for custom globs), making the common case a one-liner: `peon packs bind glados` from your work directory.

We explicitly scoped out per-rule rotation, `path_rules` inside local project configs (redundant — local config already scopes to that directory), and a `peon config set path_rules` command (JSON arrays are awkward via CLI args).

## What changed

**Pack selection engine** — The Python block in `peon.sh` now evaluates `path_rules` after config load and before rotation/default logic. About 10 lines of fnmatch matching, inserted at a single point in the event flow. The same Python block handles the config key renames at read time via `cfg.get('default_pack', cfg.get('active_pack', 'peon'))`.

**Migration** — `peon update` renames `active_pack` → `default_pack` and rewrites `pack_rotation_mode: "agentskill"` → `"session_override"` in-place. The migration is idempotent — running it twice is safe. During the transition window, runtime reads both old and new key names (new preferred, old as fallback).

**CLI** — Three new subcommands under `peon packs`: `bind <pack>` (creates a rule for cwd or `--pattern`), `unbind` (removes the matching rule), and `bindings` (lists all rules with an active-match marker). `peon status` now shows the active path rule when one matches. Shell completions updated for both bash and fish.

**Windows** — The `install.ps1` embedded hook had the `default_pack`/`active_pack` fallback expression duplicated ~10 times across pack resolution sites. We extracted a `Get-ActivePack($config)` helper to consolidate this into a single function, which also makes the eventual removal of the legacy `active_pack` key a one-line change instead of a 10-site hunt. Note: the Windows hook does not evaluate `path_rules` at runtime — it relies on the CLI `bind/unbind` having written the config, which is read at pack resolution time. Full parity would require a PowerShell fnmatch equivalent, which we deferred.

**Adapters and plugins** — Config templates in `kilo`, `opencode`, and `kiro` adapters updated to use `default_pack`. The TypeScript plugins (`peon-ping.ts`, `peon-ping-internals.ts`) updated their `PeonConfig` interface and `resolveActivePack` to read both keys with fallback. `hook-handle-use` scripts write `session_override` instead of `agentskill`.

**Documentation** — README.md gained a "Pack Selection Hierarchy" table and "Per-Project Pack Assignment" section with CLI examples. README_zh.md mirrored in Chinese. `docs/public/llms.txt` updated with path_rules context and corrected config key names.

## Verification

The BATS test suite has 9 new path_rules tests covering: basic match, no match, first-match-wins ordering, missing-pack fallthrough (rule skipped when pack isn't installed), glob patterns, empty rules array, session_override taking precedence over path_rules, and status display with/without an active match. Separate migration tests cover the rename operation, idempotency (safe to re-run), and fallback reads of the old key names.

On Windows, all 198 Pester tests pass. Two existing tests were updated to validate the `Get-ActivePack` helper. The adapter syntax validation suite covers all `.ps1` files including the modified ones.

The TypeScript plugin test suite has a new `resolveActivePack` test confirming legacy `active_pack` fallback behavior in `peon-ping-internals`.

Backward compatibility is covered implicitly: existing test fixtures intentionally retain `active_pack` in their config JSON, so every test run exercises the fallback path.

CI (BATS on macOS, Pester on Windows) must pass after merge.

## Risks and limitations

**Legacy keys live on for now.** `active_pack` and `agentskill` are still accepted at runtime via fallback reads. We haven't scheduled the breaking change to remove them. This is intentional — we want users to migrate at their own pace via `peon update`, and the fallback cost is negligible (one extra dict lookup).

**Windows path_rules gap.** The matching engine lives in `peon.sh`'s Python block, which doesn't run on native Windows. Windows users can still use `peon packs bind/unbind` (the CLI writes to config.json), and the embedded PowerShell hook reads `default_pack` correctly — but path_rules evaluation at hook time doesn't happen. A user with two path_rules would always get whichever was last `bind`-ed. Full parity requires either embedding fnmatch logic in PowerShell or porting the Python block.

## How to review

The diff is 122 files / 11k lines, but the vast majority is `.gitban/` agent artifacts (card templates, review logs, archive manifests). **Production code changes are ~20 files, ~320 lines net.**

Suggested reading order:
1. **`docs/plans/2026-02-19-path-rules-design.md`** — the design doc. Read this first and the code will make immediate sense.
2. **`peon.sh`** — path_rules matching logic (search for `fnmatch`) and migration logic (search for `peon update` or `default_pack`).
3. **`install.ps1`** — `Get-ActivePack` helper extraction. The before/after is clean: ~10 inline ternary expressions replaced with function calls.
4. **`tests/peon.bats`** — new test cases. These double as executable documentation of the matching behavior.
5. **`README.md`** — new user-facing docs.

Safe to skim: adapter config template one-liners (`kilo.sh`, `opencode.sh`, etc.), skills SKILL.md terminology swaps, `.gitban/` directory entirely.

## Deferred work

Five follow-up items were identified during development and tracked in the backlog:
- **Diagnostic logging for silent audio failures** — when a sound doesn't play, there's no way to tell why. Needs a `--debug` or `PEON_DEBUG` mode.
- **Harden Windows atomic state I/O edge cases** — the atomic write pattern (write-to-temp + rename) works but hasn't been stress-tested under heavy concurrent hook invocations.
- **DRY up peon.sh state helpers** — the state read/write functions have some redundancy that could be consolidated, and the first-run read path does unnecessary work.
- **ffplay install guidance on Windows** — Windows users without ffplay get silent failures; we should detect this and suggest installation.
- **Upgrade atomic overwrite when PS 5.1 is dropped** — PowerShell 5.1 lacks `Move-Item -Force` atomicity guarantees that 7+ has.

## Drift note

`origin/main` has 2 commits not on this branch:
- `6203fed` — sprint/HOOKBUG PR merge (#363)
- `b35c70a` — suppress sounds in non-interactive sessions (#364)

Test merge is **clean** — no conflicts. Merge or rebase before landing.
