Activate your venv first: `.\.venv\Scripts\Activate.ps1`

The code for the gitban card with id dsmh31 has been approved as of commit 75a8a303562bbfac9902519e863c5b586106a45e. Please use the gitban tools to update the gitban card and begin the tasks required to properly complete it.

## Card Close-out tasks:
- Use gitban's checkbox tools to ensure all checkboxes on the card are checked off for completed work if not already.
- Do not mark any work as deferred. This card will be closed and archived and likely never seen again.
- Use gitban's complete card tool to submit and validate if not already completed.
- Close-out item: Fix the semicolon-separated assignments on L1680 of peon.sh (`pat = r.get('pattern', ''); pk = r.get('pack', '')`) to use one-assignment-per-line style, consistent with the rest of the diff. This is a cosmetic one-liner, no tests needed.

## Sprint Close-out tasks:
- If this is the final card of a sprint, do not merge — the dispatcher handles the sprint PR to main.
