---
verdict: APPROVAL
card_id: 261745
review_number: 1
commit: fa7cf8c
date: 2026-03-26
has_backlog_items: false
---

## Review: Extract Set-PeonConfig helper to DRY config writes in install.ps1

Clean, well-scoped Extract Method refactor. The diff does exactly what the card describes and nothing more.

### What was reviewed

The commit consolidates 9 instances of the culture-swap + ConvertTo-Json + Set-Content boilerplate into a single `Set-PeonConfig` helper function, defined in two locations: `scripts/install-utils.ps1` (install-time) and the embedded hook heredoc in `install.ps1` (CLI runtime).

### Assessment

**DRY compliance**: The primary motivation is satisfied. All config-write call sites now go through `Set-PeonConfig`. The remaining `ConvertTo-Json` calls in `install.ps1` are for IDE settings files (Claude settings.json, Cursor hooks, Deepagents hooks) and state writes (`Write-StateAtomic`), which are correctly outside the scope of this helper.

**Duplicate definition in two files**: `Set-PeonConfig` is defined identically in `scripts/install-utils.ps1` and in the `install.ps1` embedded heredoc. This mirrors the existing pattern for `Get-PeonConfigRaw` and `Get-ActivePack`, which also exist in both locations. The duplication is an architectural constraint of the project (install-time utilities vs. embedded CLI runtime are separate execution contexts that cannot share code at runtime). Not a blocker.

**Behavioral side-effects (non-breaking)**: Two changes beyond pure extraction are worth noting:
1. **Depth normalization**: Two call sites previously used `-Depth 5` (pack bind/unbind) and one used `-Depth 3` (initial config creation). All now serialize at `-Depth 10`. This is strictly safer -- the config object is shallow, so deeper serialization only prevents potential future truncation. No risk of behavior change for current config shapes.
2. **Culture-swap protection added to 8 sites**: Only the initial config creation (line 231, old) had culture-swap protection. The remaining 8 CLI call sites were writing config without culture protection, meaning European-locale users running `peon notify on` or `peon trainer on` could produce locale-damaged JSON (e.g., `"volume": 0,5`). The helper now protects all paths uniformly. This is a latent bug fix, correctly bundled with the DRY extraction.

**TDD proportionality**: This is a pure refactor with no new user-facing behavior. The card reports 421 Pester tests passing (360 adapters + 21 cli-config-write + 28 trainer + 20 notification-templates + 13 packs). The existing test suite covers config write behavior. No new tests are required.

**Checkbox integrity**: All checked boxes are truthful. The three unchecked boxes are code-review gates, correctly left open for this review cycle.

**Security**: No secrets exposed, no injection vectors. The helper takes a PSObject and a file path -- no user-controlled string interpolation.

**ADR compliance**: No ADRs exist in this repository. No architectural decisions were made that would warrant one -- this is a mechanical extraction.

**Change enforcement rules**: No README, CESP, hook event, config key, or CLI command changes. No enforcement rules triggered.

### Close-out actions

None. This is ready to merge as-is.
