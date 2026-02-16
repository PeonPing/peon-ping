# Trainer Mode Design

**Date:** 2026-02-16
**Status:** Approved

## Overview

Pavel-style daily exercise trainer baked into peon-ping. Nags you to do 300 pushups and 300 squats throughout the day using custom ElevenLabs voice lines. Piggybacks on IDE hook events — no daemon, no cron.

## Config

New `trainer` section in `config.json`:

```json
{
  "trainer": {
    "enabled": false,
    "exercises": {
      "pushups": 300,
      "squats": 300
    },
    "reminder_interval_minutes": 20,
    "reminder_min_gap_minutes": 5
  }
}
```

- `exercises` — exercise name to daily goal. Default Pavel 300/300, configurable to 100 or 200.
- `reminder_interval_minutes` — how often to nag (clock time, checked on each hook event).
- `reminder_min_gap_minutes` — minimum gap between reminders to prevent spam during rapid task completions.

## State

Trainer state in `.state.json`:

```json
{
  "trainer": {
    "date": "2026-02-16",
    "reps": { "pushups": 75, "squats": 50 },
    "last_reminder_ts": 1739721600
  }
}
```

- Auto-resets when `date` doesn't match today.
- `last_reminder_ts` — unix timestamp for hybrid timing logic.

## Sounds

Trainer sounds live in a dedicated directory, separate from packs:

```
~/.claude/hooks/peon-ping/trainer/
  sounds/
    remind/          # "DROP AND GIVE ME 20", "TIME FOR SQUATS", etc.
    log/             # "GOOD WORK", "KEEP GOING", acknowledgment lines
    complete/        # "YOU DID IT", daily goal celebration
    slacking/        # fired when behind pace for the day
  manifest.json
```

`manifest.json` maps categories to files (same structure as `openpeon.json`):

```json
{
  "trainer.remind": [
    { "file": "remind/drop_and_give_me_20.mp3", "label": "Drop and give me 20!" }
  ],
  "trainer.log": [
    { "file": "log/good_work.mp3", "label": "Good work soldier" }
  ],
  "trainer.complete": [
    { "file": "complete/goal_reached.mp3", "label": "300! You're done!" }
  ],
  "trainer.slacking": [
    { "file": "slacking/pathetic.mp3", "label": "Pathetic." }
  ]
}
```

- Custom ElevenLabs voice lines (generated separately, dropped into folders).
- No-repeat logic (same as packs).
- `trainer.slacking` fires when behind pace (< 25% done past noon).

## CLI

```bash
peon trainer on                  # enable trainer mode
peon trainer off                 # disable trainer mode
peon trainer status              # show today's progress
peon trainer log 25 pushups      # log 25 pushups
peon trainer log 30 squats       # log 30 squats
peon trainer goal 200            # set both exercises to 200
peon trainer goal pushups 100    # set just pushups to 100
```

`peon trainer status` output example:

```
Pavel Daily Trainer -- 2026-02-16

  pushups:  ████████░░░░░░░░  125/300  (42%)
  squats:   ██░░░░░░░░░░░░░░   50/300  (17%)

  Next reminder in ~12 min
```

## Reminder Logic

On every hook event, after normal sound logic:

1. Check `trainer.enabled` — if false, skip.
2. Check `trainer.date` vs today — if different, reset reps to 0.
3. Check if daily goal already hit for all exercises — if so, skip reminders.
4. Calculate time since `last_reminder_ts`.
5. If `>= reminder_interval_minutes` AND `>= reminder_min_gap_minutes`:
   - Pick random sound from `trainer.remind` (or `trainer.slacking` if behind pace).
   - Output trainer sound variables.
   - Update `last_reminder_ts`.
   - Desktop notification with progress summary.

**Pace check:** If current time is past noon and reps below 25% of goal, use `trainer.slacking`.

**Sound priority:** Trainer reminder plays after the normal hook sound with ~1s delay. Skip trainer reminder on `session.start` to avoid stacking.

**On rep log:** Play `trainer.log` sound. If log pushes total to goal, play `trainer.complete` instead.

## Files Touched

- `peon.sh` — trainer logic in Python block + CLI subcommand + delayed trainer sound playback
- `config.json` — add `trainer` section defaults
- `tests/` — new BATS tests for trainer logic
- `README.md` — trainer section in docs

## Not In Scope

- No daemon or background process.
- No ElevenLabs API integration (audio files provided separately).
- No generalized exercise framework — Pavel pushups + squats with configurable goal number.
- No web UI or dashboard.
- No trainer-specific mobile notifications (reuses existing mobile infra).
