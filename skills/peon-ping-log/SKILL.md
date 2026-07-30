---
name: peon-ping-log
description: Log exercise reps for the Peon Trainer. Use when user says they did pushups, squats, or wants to log reps. Examples - "/peon-ping-log 25 pushups", "/peon-ping-log 30 squats", "log 50 pushups".
user-invocable: true
---

# peon-ping-log

Log exercise reps for the Peon Trainer.

## Usage

The user provides a number and exercise type. Run the following command using the Bash tool:

```bash
bash ~/.claude/hooks/peon-ping/peon.sh trainer log <count> <exercise>
```

Where:
- `<count>` is the number of reps (e.g. `25`)
- `<exercise>` is `pushups` or `squats`

### Examples

```bash
bash ~/.claude/hooks/peon-ping/peon.sh trainer log 25 pushups
bash ~/.claude/hooks/peon-ping/peon.sh trainer log 30 squats
```

Report the output to the user. The command will print the updated rep count and play a trainer voice line.

## If trainer is not enabled

If the output says trainer is not enabled, tell the user to run `/peon-ping-toggle` or `peon trainer on` first.

## Check status

If the user asks for their progress after logging, also run:

```bash
bash ~/.claude/hooks/peon-ping/peon.sh trainer status
```
