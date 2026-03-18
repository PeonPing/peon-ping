The reviewer flagged 3 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Add diagnostic logging for silent audio failures in win-play.ps1 and peon.ps1
Type: BACKLOG
Sprint: none
Files touched: `scripts/win-play.ps1`, `install.ps1` (embedded peon.ps1)
Items:
- L2: Silent failure when `win-play.ps1` is missing. The `if (Test-Path $winPlayScript)` guard silently skips audio if the script doesn't exist. A corrupted install where win-play.ps1 is missing produces no sound with no diagnostic output. Consider logging to stderr.
- L3: Empty `catch {}` blocks swallow all exceptions in WAV playback path. Both in the embedded peon.ps1 state write and in win-play.ps1 WAV path, empty catch blocks swallow errors silently. This is pre-existing tech debt. At minimum, log to a debug file or stderr when `$DebugPreference` is set.
