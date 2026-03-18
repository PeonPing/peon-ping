The reviewer flagged 1 non-blocking item, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Remove unreachable $pathRulePack check inside pack_rotation branch in install.ps1
Type: FASTFOLLOW
Sprint: TECHDEBT2
Files touched: install.ps1
Items:
- L1: Install.ps1 lines 1068-1071 contain a `$pathRulePack` check inside the `pack_rotation` branch, but `$pathRulePack` is already handled by the preceding `elseif ($pathRulePack)` at line 1065. If `$pathRulePack` is truthy, execution never reaches line 1069. This is dead code that should be removed.
