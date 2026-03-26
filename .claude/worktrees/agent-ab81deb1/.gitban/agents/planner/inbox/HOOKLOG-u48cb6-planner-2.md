The reviewer flagged 1 new non-blocking item in review-2, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.
All cards go into the current sprint unless marked BLOCKED with a reason.

Note: L2 from review-2 carries forward L1-L3 from review-1. L1 (timestamp precision) and L3 (newline escaping) were already routed to the planner in cycle 1 (see HOOKLOG-u48cb6-planner-1.md). L2 (card 77eri8 incomplete acceptance criteria) is a process note — that card should not move to done until its remaining criteria are met. Do not create duplicate cards for any of these.

### Card 1: Per-path [exit] log tests for early-exit paths
Sprint: HOOKLOG
Files touched: tests/peon.bats
Items:
- L1: The 4 early-exit paths added in commit c209636 (SubagentStop suppression, SubagentStart, SessionEnd cleanup, non-Bash tool failure) do not have dedicated tests verifying their [exit] emission. Add targeted tests analogous to the delegate_mode and agent_session tests from commit 8908a13 (e.g., "debug log emits [exit] on SubagentStop suppression"). This closes the coverage gap and catches regressions that remove a log call from one of these paths.
