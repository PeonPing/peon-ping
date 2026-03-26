---
verdict: APPROVAL
card_id: xb6c47
review_number: 1
commit: 3f7b64b
date: 2026-03-25
has_backlog_items: false
---

## Summary

This card addresses three reviewer-flagged issues from the HOOKLOG sprint: a word-splitting bug in `validate_log_fixture`, DRY violations from copy-pasted config-enable boilerplate, and a missing error-path test required by PRD-002. All three are cleanly resolved.

## Analysis

### 1. validate_log_fixture word-splitting fix (tests/peon.bats)

The old code used `for kv in $(echo "$line" | sed ...)` which breaks on quoted values containing spaces. The replacement uses a Python regex parser via process substitution that correctly handles `key="value with spaces"` patterns. The regex `(\w+)=("[^"]*"|\S*)` is correct for this use case -- it matches either a quoted value or a non-whitespace sequence after the `=`.

The function comment says "Python shlex" but actually uses `re.finditer`, not `shlex.split`. This is a minor inaccuracy in the comment but the implementation is sound -- `shlex.split` would actually be wrong here since it strips quotes and splits on spaces in a shell-aware way, whereas the regex preserves the key=value structure needed for downstream assertions. The right tool was chosen; the comment is slightly misleading but not worth blocking over.

### 2. enable_debug_logging helper extraction (tests/setup.bash)

14 identical 6-line Python blocks replaced with single-line `enable_debug_logging` calls. The 2 remaining inline blocks legitimately set additional config keys (`debug_retention_days`, `default_pack`) and cannot use the simple helper. Net reduction of 19 lines. Clean DRY improvement.

The helper uses `/usr/bin/python3` (absolute path), consistent with the rest of the test infrastructure. The `$TEST_DIR` variable expands correctly because the function body uses double-quoted heredoc (no single-quote escaping on the Python string).

### 3. Missing audio backend error-path test (peon.sh + tests/peon.bats)

**Production code change** (+2 lines in `peon.sh`): Adds `_peon_log play "error=..."` to the `linux` case when `detect_linux_player` returns empty. This is the minimal change needed -- the error path already existed (the `else` branch was implicit via the `if [ -n "$player" ]` guard), it just lacked logging.

**Test**: Builds a clean PATH containing only essential utilities (no audio players), sets `PLATFORM=linux`, and asserts `[play] error=` appears in the log. The PATH manipulation is thorough -- it symlinks only the utilities needed for peon.sh to run (python3, bash, coreutils) while excluding all six audio backends. The test properly saves/restores PATH and unsets PLATFORM after the run.

### TDD compliance

This is a test-hardening card. The card's motivation is fixing existing test infrastructure and closing coverage gaps flagged by a prior review. The changes are:
- A bug fix to test tooling (validate_log_fixture)
- A refactor of test boilerplate (enable_debug_logging)
- A new test + minimal production code to enable it (error-path logging)

For item 3, the production code change (2 lines) exists solely to make the new test's assertion possible -- the error path already silently fell through. This is consistent with TDD: the test defines the expected behavior (log an error), and the production code is the minimal implementation. The card's work log and commit message demonstrate awareness of the test-first flow.

### Checkbox integrity

All checked boxes are truthful:
- Component identified, related work linked, motivation documented
- TDD workflow steps all marked done with evidence in the executor work log
- Coverage verification: branch coverage gap (missing error-path) is closed, +1 net new test
- Completion checklist items are all verifiable from the diff

### Security

No concerns. Changes are confined to test infrastructure and a single diagnostic log line in production code. No secrets, no user input handling changes.

## BLOCKERS

None.

## FOLLOW-UP

None. The comment in `validate_log_fixture` mentioning "Python shlex" when it actually uses `re.finditer` is a trivial inaccuracy that does not warrant a follow-up card.
