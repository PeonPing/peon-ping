Use `.venv/Scripts/python.exe` to run Python commands.

The code for the gitban card with id unkjkl has been approved as of commit 65aaad1. Please use the gitban tools to update the gitban card and begin the tasks required to properly complete it.

## Card Close-out tasks:
- Use gitban's checkbox tools to ensure all checkboxes on the card are checked off for completed work if not already.
- Do not mark any work as deferred. This card will be closed and archived and likely never seen again.
- Use gitban's complete card tool to submit and validate if not already completed.
- Close-out items:
  - L2: Add graceful error handling for `peon logs --last` with non-numeric argument. Currently `[int]$Arg2` throws an unhandled terminating error on input like `peon logs --last foo`. Add a `try/catch` or `-as [int]` pattern with a fallback usage message, consistent with how other commands handle bad input. This is in the `--last` branch of the logs switch case in install.ps1's embedded $hookScript.
- If this card is not in a sprint, push the feature branch and create a draft PR to main using `gh pr create --draft`. Do not merge it — the user reviews and merges.

Note: You are closing out this card only. The dispatcher owns sprint lifecycle — do not close, archive, or finalize the sprint itself. The exception is a sprint close-out card, which will be obvious from its content.
