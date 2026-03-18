Activate your venv first: `.\.venv\Scripts\Activate.ps1`

===BEGIN REFACTORING INSTRUCTIONS===

**B1: BATS test suite was never executed.**

The executor trace (`executor-a69155e0.jsonl`) shows the lint script was tested manually via direct `bash scripts/lint-python-quoting.sh peon.sh` invocations and ad-hoc bad-file creation, but `bats tests/lint-python-quoting.bats` was never run. The 10-test BATS suite was written and committed without execution. This means:

- We have no evidence the BATS tests actually pass.
- The test file references `BATS_TEST_FILENAME` and `BATS_TMPDIR` which are BATS-specific variables -- if there is a setup issue, a typo in a heredoc, or a quoting problem in the test assertions themselves, it would only surface when actually running the suite.
- The "all shell scripts" test uses `grep -rl` with `--include='*.sh'` which has platform-specific behavior (GNU vs BSD grep). This was never validated.

**Refactor plan:** Run `bats tests/lint-python-quoting.bats` and fix any failures. If BATS is not available in the executor environment, document that limitation and provide the actual output from a manual equivalent that exercises all 10 test scenarios. The card claims "Lint passes on all 17 .sh files" -- provide the actual output.
