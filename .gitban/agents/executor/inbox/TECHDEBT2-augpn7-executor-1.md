Activate your venv first: `.\.venv\Scripts\Activate.ps1`

The code for the gitban card with id augpn7 has been approved as of commit 371c945. Please use the gitban tools to update the gitban card and begin the tasks required to properly complete it.

## Card Close-out tasks:
- Use gitban's checkbox tools to ensure all checkboxes on the card are checked off for completed work if not already.
- Do not mark any work as deferred. This card will be closed and archived and likely never seen again.
- Use gitban's complete card tool to submit and validate if not already completed.
- Close-out items: Three unchecked checkboxes on the card are review-gated ("Code reviewed..." items in Refactoring Phases, Safe Refactoring Workflow, and Completion Checklist). Check them off upon close-out.
- If this card is not in a sprint, push the feature branch and create a draft PR to main using `gh pr create --draft`. Do not merge it — the user reviews and merges.

Note: You are closing out this card only. The dispatcher owns sprint lifecycle — do not close, archive, or finalize the sprint itself. The exception is a sprint close-out card, which will be obvious from its content.
