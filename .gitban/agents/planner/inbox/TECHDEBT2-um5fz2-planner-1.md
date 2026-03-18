The reviewer flagged 1 non-blocking item, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Align PEON_DEBUG check pattern to strict equality across all .ps1 files
Type: FASTFOLLOW
Sprint: TECHDEBT2
Files touched: adapters/windsurf.ps1, adapters/gemini.ps1, adapters/deepagents.ps1, adapters/copilot.ps1, adapters/kimi.ps1, adapters/kiro.ps1, install.ps1, scripts/win-play.ps1
Items:
- L1: The adapters use `if ($env:PEON_DEBUG)` (truthy for any non-empty string including "0") while `install.ps1` and `win-play.ps1` use the stricter `$peonDebug = $env:PEON_DEBUG -eq "1"` pattern. Pick one canonical form and apply it everywhere. The strict equality form is preferred since it matches the existing established pattern and avoids unexpected warnings when PEON_DEBUG is set to "0" or "false".
