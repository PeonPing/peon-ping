The reviewer flagged 2 non-blocking items, grouped into 2 cards below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.
All cards go into the current sprint unless marked BLOCKED with a reason.

### Card 1: Sync debugging docs to README_ja.md and README_ko.md
Sprint: HOOKLOG
Files touched: README_ja.md, README_ko.md
Items:
- L1: The Debugging section added in README.md/README_zh.md was not propagated to the Japanese and Korean translations. CLAUDE.md enforcement rules only mandate zh, so this was not a blocker, but these translations will drift further out of sync. Add the translated Debugging section to both files.

### Card 2: Gate informational status lines behind --verbose flag
Sprint: HOOKLOG
Files touched: peon.sh
Items:
- L2: The debug status line (and other "mode" lines like headphones_only, meeting_detect) always print even when not using --verbose. As more features accumulate, the non-verbose status output grows long. Refactor informational mode lines in `peon status` to only display when `--verbose` is passed, keeping the default output concise.
