# Review: TECHDEBT-5efwxz-reviewer-1

**Card:** 5efwxz — Update-PeonConfig skip-write optimization
**Commit:** ec12caa
**Review number:** 1

## Verdict: APPROVAL

The change adds a skip-write guard (`if ($updated -ne $raw)`) to all 7 CLI config-write sites in `install.ps1`. The optimization is correct. PowerShell's `-replace` returns the original string when the regex doesn't match, so the `-ne` comparison reliably detects whether content changed. The pattern is applied uniformly across toggle, pause, resume, packs use, packs next, pack, and volume commands.

## Backlog Items

- **L1**: CLI config-write commands have no behavioral test coverage (existing tests are structural source-code pattern matches, not execution tests). Pre-existing debt.
