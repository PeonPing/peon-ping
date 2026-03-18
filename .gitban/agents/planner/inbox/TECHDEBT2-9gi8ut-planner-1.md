The reviewer flagged 2 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Harden install.ps1 volume regex to handle optional trailing comma in JSON
Type: FASTFOLLOW
Sprint: TECHDEBT2
Files touched: install.ps1
Items:
- L1: The volume config-write regex at line ~696 of install.ps1 uses `'"volume"\s*:\s*[\d.]+,'` which requires a trailing comma after the value. PowerShell hashtable enumeration order is not guaranteed, so if `volume` is serialized as the last JSON key (no trailing comma), the regex silently fails to match and the write is skipped. Fix by making the trailing comma optional in the regex pattern (e.g., `',?'`) or by switching to proper JSON parse/reserialize. This is pre-existing debt not introduced by card 9gi8ut.
