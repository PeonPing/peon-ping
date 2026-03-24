Use `.venv/Scripts/python.exe` to run Python commands.

The code for the gitban card with id hchc5z has been approved as of commit 5b32211. Please use the gitban tools to update the gitban card and begin the tasks required to properly complete it.

## Card Close-out tasks:
- Use gitban's checkbox tools to ensure all checkboxes on the card are checked off for completed work if not already.
- Do not mark any work as deferred. This card will be closed and archived and likely never seen again.
- Use gitban's complete card tool to submit and validate if not already completed.
- Close-out items:
  - L1: In `tests/trainer-windows.Tests.ps1`, add a comment to the performance test noting that the 5000ms threshold is CI-relaxed from the 500ms design target in the card spec. A one-line comment like `# CI-relaxed: design target is 500ms (see card spec), 5s for CI stability` near the `5000` assertion is sufficient.
- If this card is not in a sprint, push the feature branch and create a draft PR to main using `gh pr create --draft`. Do not merge it -- the user reviews and merges.

Note: You are closing out this card only. The dispatcher owns sprint lifecycle -- do not close, archive, or finalize the sprint itself. The exception is a sprint close-out card, which will be obvious from its content.
