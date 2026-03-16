The reviewer flagged 3 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Port path_rules to peon.ps1 and add pack selection test scenarios 4-7
Type: BACKLOG
Sprint: none
Files touched: peon.ps1, tests/peon-packs.Tests.ps1
Items:
- L3: No backlog card exists for porting path_rules to peon.ps1 and adding the 4 deferred test scenarios (scenarios 4-7 from the frjune card spec: path_rules glob match, first-match-wins, missing cwd fallthrough, missing pack directory fallthrough). The path_rules feature currently only exists in peon.sh (Unix). The peon.ps1 Windows engine needs the same glob matching via -like operator, first-match-wins logic, and fallthrough behavior. Once implemented, the 4 test scenarios should be added to tests/peon-packs.Tests.ps1.
