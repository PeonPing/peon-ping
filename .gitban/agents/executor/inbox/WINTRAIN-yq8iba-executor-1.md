Use `.venv/Scripts/python.exe` to run Python commands.

The code for the gitban card with id yq8iba has been approved as of commit c42ba95. Please use the gitban tools to update the gitban card and begin the tasks required to properly complete it.

## Card Close-out tasks:
- Use gitban's checkbox tools to ensure all checkboxes on the card are checked off for completed work if not already.
- Do not mark any work as deferred. This card will be closed and archived and likely never seen again.
- Use gitban's complete card tool to submit and validate if not already completed.
- Close-out item (L1): Replace 5 occurrences of `Get-Content $ConfigPath -Raw | ConvertFrom-Json` with `Get-PeonConfigRaw $ConfigPath | ConvertFrom-Json` in the trainer subcommand block of `install.ps1`'s embedded `peon.ps1` (lines 918, 943, 957, 1026, 1082). This aligns trainer commands with the helper used by every other CLI command.
- If this card is not in a sprint, push the feature branch and create a draft PR to main using `gh pr create --draft`. Do not merge it — the user reviews and merges.

Note: You are closing out this card only. The dispatcher owns sprint lifecycle — do not close, archive, or finalize the sprint itself. The exception is a sprint close-out card, which will be obvious from its content.
