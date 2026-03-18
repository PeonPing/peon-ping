Activate your venv first: `.\.venv\Scripts\Activate.ps1`

The code for the gitban card with id 1dnbzv has been approved as of commit 91d1774e2a956b9c902024e0219edfe3bb3b7933. Please use the gitban tools to update the gitban card and begin the tasks required to properly complete it.

## Card Close-out tasks:
- Use gitban's checkbox tools to ensure all checkboxes on the card are checked off for completed work if not already.
- Do not mark any work as deferred. This card will be closed and archived and likely never seen again.
- Use gitban's complete card tool to submit and validate if not already completed.
- Close-out items:
  - **L1 (dead hashtable branch):** In `tests/peon-engine.Tests.ps1`, Scenario 15 session TTL assertion -- remove the `if ($sessionPacks -is [hashtable])` branch (lines ~540-541 in the diff). `ConvertFrom-Json` never returns hashtables in PowerShell 5.1, so that branch is dead code. Keep only the PSCustomObject path.
  - **L2 (smoke test overlap comment):** In `tests/peon-engine.Tests.ps1`, add a brief section comment above the smoke test block (the existing "Invoke-PeonHook:" scenarios from step 1) explaining: "These smoke tests validate harness infrastructure, not engine contracts. The engine scenarios below test the same events with stricter assertions." This clarifies the intentional overlap for future contributors.
- If this card is not in a sprint, push the feature branch and create a PR to main using `gh pr create`. Do not merge it -- the user reviews and merges.

## Sprint Close-out tasks:
- If this is the final card of a sprint, do not merge -- the dispatcher handles the sprint PR to main.
