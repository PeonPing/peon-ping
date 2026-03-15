Activate your venv first: `.\.venv\Scripts\Activate.ps1`

The code for the gitban card with id q52ygy has been approved as of commit 0d965db0b56917726b9bfcdabd52842df58d4e0c. Please use the gitban tools to update the gitban card and begin the tasks required to properly complete it.

## Card Close-out tasks:
- Use gitban's checkbox tools to ensure all checkboxes on the card are checked off for completed work if not already.
- Do not mark any work as deferred. This card will be closed and archived and likely never seen again.
- Use gitban's complete card tool to submit and validate if not already completed.
- Close-out item (L1): In `tests/windows-setup.ps1`, the `Invoke-PeonHook` function sets `CLAUDE_PEON_DIR` and `PEON_TEST` environment variables that peon.ps1 never reads. Add a brief comment above those two lines explaining they exist for parity with the BATS harness (which uses `PEON_TEST` in peon.sh) and are not consumed by peon.ps1.
- If this card is not in a sprint, push the feature branch and create a PR to main using `gh pr create`. Do not merge it -- the user reviews and merges.

## Sprint Close-out tasks:
- If this is the final card of a sprint, do not merge -- the dispatcher handles the sprint PR to main.
