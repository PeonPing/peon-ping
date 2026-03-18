The reviewer flagged 3 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Windows CLI install.ps1 bind/unbind quality improvements
Type: BACKLOG
Sprint: none
Files touched: install.ps1
Items:
- L1: `--install` flag downloads sounds one-at-a-time without parallelism or progress feedback. The `bind --install` code (lines 484-518) fetches the registry, manifest, and each sound file sequentially via `Invoke-WebRequest`. For packs with 40+ sounds this could take 30+ seconds with no output. Consider extracting a shared `Install-Pack` function or calling pack-download logic. No functional test covers `--install` end-to-end.
- L3: Duplicated config I/O pattern across bind/unbind/bindings. Each subcommand independently does `Get-Content | ConvertFrom-Json`, manipulates `path_rules`, then `ConvertTo-Json | Set-Content`. Consider a helper like `Update-PeonConfig { param($Mutator) }` to reduce duplication.
