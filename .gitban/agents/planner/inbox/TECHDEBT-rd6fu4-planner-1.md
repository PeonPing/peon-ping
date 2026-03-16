The reviewer flagged 2 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Align peon.ps1 default_pack config parity and add session_override + path_rules interaction test
Type: FASTFOLLOW
Sprint: TECHDEBT
Files touched: `install.ps1` (embedded peon.ps1), `tests/peon-packs.Tests.ps1`
Items:
- L1: `default_pack` config key not supported in peon.ps1. The Python reference checks `cfg.get('default_pack', cfg.get('active_pack', 'peon'))`, supporting a `default_pack` key distinct from `active_pack`. The PS1 engine only checks `active_pack`. Add `default_pack` config key support to peon.ps1 for full config parity with peon.sh.
- L2: No test for path_rules + session_override interaction. The production code correctly integrates `$pathRulePack` into the session_override fallback paths, but there is no test scenario that exercises the combined `session_override + path_rules` fallback. Add a test where a session pack is missing and a path_rule matches, confirming the integration point directly.
