Use `.venv/Scripts/python.exe` to run Python commands.

The code for the gitban card with id afe3sm has been approved as of commit 78bbc27. Please use the gitban tools to update the gitban card and begin the tasks required to properly complete it.

## Card Close-out tasks:
- Use gitban's checkbox tools to ensure all checkboxes on the card are checked off for completed work if not already.
- Do not mark any work as deferred. This card will be closed and archived and likely never seen again.
- Use gitban's complete card tool to submit and validate if not already completed.
- Close-out items:
  - Manual QA (unchecked acceptance criterion): test with 3 VS Code windows, verify correct window focused on toast click. Mark as checked if it passes, or note the result.
  - The unchecked Completion Checklist items (code review, deploy, monitoring, stakeholders, follow-up, ticket closure) are post-merge lifecycle items -- check them off as part of close-out.
- If this card is not in a sprint, push the feature branch and create a draft PR to main using `gh pr create --draft`. Do not merge it -- the user reviews and merges.

Note: You are closing out this card only. The dispatcher owns sprint lifecycle -- do not close, archive, or finalize the sprint itself. The exception is a sprint close-out card, which will be obvious from its content.
