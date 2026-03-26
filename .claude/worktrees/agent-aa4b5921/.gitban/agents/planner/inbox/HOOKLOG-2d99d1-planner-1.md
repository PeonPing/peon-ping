The reviewer flagged 1 non-blocking item, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.
All cards go into the current sprint unless marked BLOCKED with a reason.

### Card 1: Gate peon.ps1 status output behind --verbose flag (Windows parity)
Sprint: HOOKLOG
Files touched: peon.ps1, tests/adapters-windows.Tests.ps1
Items:
- L1: The Windows PowerShell status handler (`peon.ps1`) still prints all informational status lines unconditionally. Apply the same verbose gating pattern from `peon.sh` to `peon.ps1` to maintain platform parity. Essential lines (paused/active state, default pack, pack count) stay unconditional; informational lines (notifications, headphones, path rules, IDE detection) move behind `--verbose`.
