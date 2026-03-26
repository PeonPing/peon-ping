Use `.venv/Scripts/python.exe` to run Python commands.

The code for the gitban card with id kt3ucx has been approved as of commit 213fd2f. Please use the gitban tools to update the gitban card and begin the tasks required to properly complete it.

## Card Close-out tasks:
- Use gitban's checkbox tools to ensure all checkboxes on the card are checked off for completed work if not already.
- Do not mark any work as deferred. This card will be closed and archived and likely never seen again.
- Use gitban's complete card tool to submit and validate if not already completed.
- Close-out items:
  - **L1 (unquoted command substitution in logs --last):** In peon.sh, the `logs --last` block has `cat $(ls -1 "$LOGS_DIR"/peon-ping-*.log 2>/dev/null | sort) | tail -n "$N"`. The unquoted `$()` breaks if LOGS_DIR contains spaces. Replace with: `ls -1 "$LOGS_DIR"/peon-ping-*.log 2>/dev/null | sort | xargs cat | tail -n "$N"`
  - **L2 (grep vs grep -F in logs --session):** In peon.sh, the `logs --session` block uses `grep "session=$SESSION_ID"`. Change to `grep -F "session=$SESSION_ID"` to treat the pattern as a fixed string rather than a regex, guarding against future session ID formats with metacharacters.
- If this card is not in a sprint, push the feature branch and create a draft PR to main using `gh pr create --draft`. Do not merge it -- the user reviews and merges.

Note: You are closing out this card only. The dispatcher owns sprint lifecycle -- do not close, archive, or finalize the sprint itself. The exception is a sprint close-out card, which will be obvious from its content.
