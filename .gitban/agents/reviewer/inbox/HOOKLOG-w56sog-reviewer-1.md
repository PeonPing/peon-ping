---
verdict: APPROVAL
card_id: w56sog
review_number: 1
commit: 3f8fc20
date: 2026-03-25
has_backlog_items: true
---

## Summary

This commit adds structured debug logging infrastructure to peon.ps1 (the Windows native hook script embedded in install.ps1), achieving logging parity with the Unix peon.sh implementation from step 2. The implementation follows ADR-002's design: a `$peonLog` scriptblock that is either an empty no-op (debug=false, zero overhead) or an append-to-file writer (debug=true or PEON_DEBUG=1), emitting key=value log lines across 9 phases with 4-char hex invocation IDs, daily rotation, and IOException fault tolerance.

The diff is clean and well-structured. 149 lines of production code in install.ps1, 536 lines of new Pester tests, and 2 lines of surgical regex fixes to existing tests. The implementation correctly mirrors every ADR-002 requirement.

## BLOCKERS

None.

## FOLLOW-UP

**L1: Misleading comment on config error fallback.**
The comment at the config catch block says "Fall back to minimal defaults so logging can still initialize" but the fallback object sets `debug = $false`, which means logging does NOT initialize (the empty scriptblock path is taken). The subsequent `$_configError` log calls at lines 1498-1500 go to the no-op scriptblock and are silently discarded. This matches peon.sh behavior (where `cfg = {}` also defaults debug to False), so the runtime behavior is correct and intentional -- the comment is simply inaccurate. It should read something like "Fall back to minimal defaults so the hook can still run (logging requires PEON_DEBUG=1 when config is broken)."

**L2: Paused fixture does not validate cross-platform parity.**
The shared fixture `paused.expected.txt` expects `[hook] ... paused=True` and `[route] ... reason=paused`. The peon.sh implementation logs these because the Python block runs past the enabled check and handles paused state mid-pipeline. In peon.ps1, `if (-not $config.enabled) { exit 0 }` fires before logging infrastructure is initialized, so no log file is created at all. The Pester test acknowledges this divergence in a comment ("expected behavior divergence from peon.sh") and only asserts exit code 0. This means the paused fixture is a Unix-only assertion that provides no Windows parity validation. Worth tracking as a known asymmetry in the design doc or ADR, since it undermines the stated goal of the shared fixture system ("Any format divergence fails CI on both platforms").

**L3: Hashtable enumeration order is non-deterministic.**
`$Fields.GetEnumerator()` in the `$peonLog` scriptblock iterates hashtable entries in an undefined order. This means the same log call could produce `volume=0.5 pack=peon loaded=...` on one invocation and `pack=peon loaded=... volume=0.5` on another. This doesn't affect log parsing (key=value pairs are self-describing and order-independent), but it does mean the output is not byte-identical to peon.sh for the same input, as the Python implementation uses explicit string formatting with a fixed field order. The ADR acceptance criterion says "Log format byte-identical to peon.sh output for same events (modulo timestamps, invocation IDs, and platform-specific paths)." Field ordering is arguably in the "modulo" category, but if strict byte parity is desired, switch to `[ordered]@{}` hashtables at the call sites or build the string with explicit field ordering.

**L4: Agent detection logic is new behavior beyond logging.**
The delegate mode / agent_session suppression block (lines 1595-1621 in the post-image) is not just a log emitter -- it adds entirely new route suppression behavior to peon.ps1 that previously only existed in peon.sh. The commit message mentions this ("Delegate mode / agent_session suppression detection (parity with peon.sh route logic)"), but this is a behavioral change to the hook script, not just logging infrastructure. The tests cover it (delegate_mode and agent_session route suppression), so it is verified, but it should be called out explicitly as a behavioral parity fix rather than being bundled under "logging infrastructure." If this behavior change breaks something, bisecting to this commit would be confusing since the title says "logging infrastructure." Consider noting this in the changelog entry when the version is bumped.

## Approval Notes

The implementation is solid. All 9 phases are covered, the zero-overhead path is correct, IOException fault tolerance works, daily rotation logic is sound, and the PEON_DEBUG=1 override correctly makes stderr warnings and file logging additive. The 29 Pester tests are well-structured with proper setup/teardown, covering both happy paths and error paths (missing pack, debounce, delegate mode, category disabled). The static analysis tests that inspect the embedded here-string for structural invariants are a good pattern for catching regressions in embedded code.

The 2 existing test regex fixes (`.*` to `[\s\S]*` for multiline matching) are correct and minimal -- the logging code insertions added newlines between the patterns being matched, requiring multiline-aware regexes.

Close-out actions:
- Address L1 (comment fix) in a follow-up commit or the documentation card.
- Track L2 (paused fixture asymmetry) as a known limitation in the design doc.
- L3 and L4 are informational; no action required unless strict byte parity or changelog clarity is desired.
