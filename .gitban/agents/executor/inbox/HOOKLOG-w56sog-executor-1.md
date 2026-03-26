Use `.venv/Scripts/python.exe` to run Python commands.

The code for the gitban card with id w56sog has been approved as of commit 3f8fc20. Please use the gitban tools to update the gitban card and begin the tasks required to properly complete it.

## Card Close-out tasks:
- Use gitban's checkbox tools to ensure all checkboxes on the card are checked off for completed work if not already.
- Do not mark any work as deferred. This card will be closed and archived and likely never seen again.
- Use gitban's complete card tool to submit and validate if not already completed.
- Close-out items:
  - **L1 (comment fix):** In install.ps1, find the config error catch block's comment that says "Fall back to minimal defaults so logging can still initialize" and change it to "Fall back to minimal defaults so the hook can still run (logging requires PEON_DEBUG=1 when config is broken)." This accurately reflects the behavior where the fallback sets debug=$false, meaning the empty scriptblock path is taken and subsequent log calls are no-ops.
  - **L2 (paused fixture asymmetry):** In `docs/designs/structured-hook-logging.md`, add a "Known Asymmetries" section (or append to an existing limitations section) documenting that the `paused.expected.txt` shared fixture is Unix-only. On Windows, `if (-not $config.enabled) { exit 0 }` fires before logging infrastructure is initialized, so no log file is created when paused. The Pester test validates exit code 0 only. This is a documented divergence from peon.sh where the Python block runs past the enabled check and logs paused state mid-pipeline.
- If this card is not in a sprint, push the feature branch and create a draft PR to main using `gh pr create --draft`. Do not merge it -- the user reviews and merges.

Note: You are closing out this card only. The dispatcher owns sprint lifecycle -- do not close, archive, or finalize the sprint itself. The exception is a sprint close-out card, which will be obvious from its content.
