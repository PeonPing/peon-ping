Activate your venv first: `.\.venv\Scripts\Activate.ps1`

The code for the gitban card with id 9pjhy5 has been approved as of commit a18a0ec. Please use the gitban tools to update the gitban card and begin the tasks required to properly complete it.

## Card Close-out tasks:
- Use gitban's checkbox tools to ensure all checkboxes on the card are checked off for completed work if not already.
- Do not mark any work as deferred. This card will be closed and archived and likely never seen again.
- Use gitban's complete card tool to submit and validate if not already completed.
- Close-out items:
  - **L2 fix:** Add a comment at `install.ps1` line 472 (the `$i++` inside the `switch` block within the `for` loop) explaining the intentional skip of the next argument after `--pattern`. Something like: `# Intentionally advance loop counter to skip the next arg (the pattern value)`.
- If this card is not in a sprint, push the feature branch and create a PR to main using `gh pr create`. Do not merge it — the user reviews and merges.

## Sprint Close-out tasks:
- If this is the final card of a sprint, do not merge — the dispatcher handles the sprint PR to main.
