The reviewer flagged 3 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Harden --install flag: E2E test, registry fallbacks, and help text
Type: BACKLOG
Sprint: none
Files touched: install.ps1, tests/adapters-windows.Tests.ps1
Items:
- L1: `--install` flag has no functional E2E test. The acceptance criteria checkbox is marked done but only a structural regex test exists. A true E2E requires mocking the registry HTTP endpoint. Track and implement when feasible.
- L2: `--install` download path lost registry field fallbacks (`source_repo` defaults to "PeonPing/og-packs", `source_ref` defaults to "main", `source_path` defaults to pack name) and lost explicit "pack not found in registry" error message. Restore defensive defaults.
- L3: Help text alignment regression. The `--help` output lost column alignment for `unbind`, and the `--pattern <glob>` and `--install` flags are no longer documented in help text.
