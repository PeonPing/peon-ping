# Trainer Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Pavel-style daily exercise trainer to peon-ping that nags you to do pushups and squats during coding sessions.

**Architecture:** Trainer logic lives inside the existing peon.sh Python block. On each hook event, after normal sound routing, the Python block checks trainer config/state and optionally outputs a second set of sound variables for a trainer reminder. CLI subcommands (`peon trainer ...`) are added to the existing `case` statement. Trainer sounds use a dedicated `trainer/` directory with its own manifest.json.

**Tech Stack:** Bash, embedded Python 3, BATS for testing

**Design doc:** `docs/plans/2026-02-16-trainer-mode-design.md`

**Branch:** Create `feat/trainer-mode` from current HEAD before starting.

---

### Task 1: Create branch and trainer sound directory scaffold

**Files:**
- Create: `trainer/sounds/remind/.gitkeep`
- Create: `trainer/sounds/log/.gitkeep`
- Create: `trainer/sounds/complete/.gitkeep`
- Create: `trainer/sounds/slacking/.gitkeep`
- Create: `trainer/manifest.json`

**Step 1: Create branch**

```bash
cd /Users/garysheng/Documents/github-repos/peonping-repos/peon-ping
git checkout -b feat/trainer-mode
```

**Step 2: Create trainer directory structure**

```bash
mkdir -p trainer/sounds/{remind,log,complete,slacking}
touch trainer/sounds/remind/.gitkeep
touch trainer/sounds/log/.gitkeep
touch trainer/sounds/complete/.gitkeep
touch trainer/sounds/slacking/.gitkeep
```

**Step 3: Create manifest.json**

Create `trainer/manifest.json`:

```json
{
  "trainer.remind": [
    { "file": "sounds/remind/placeholder.wav", "label": "Time for reps!" }
  ],
  "trainer.log": [
    { "file": "sounds/log/placeholder.wav", "label": "Logged." }
  ],
  "trainer.complete": [
    { "file": "sounds/complete/placeholder.wav", "label": "Goal reached!" }
  ],
  "trainer.slacking": [
    { "file": "sounds/slacking/placeholder.wav", "label": "You're falling behind." }
  ]
}
```

Note: placeholder entries will be replaced with real ElevenLabs audio later. The code should gracefully handle missing sound files.

**Step 4: Update config.json with trainer defaults**

Add trainer section to `config.json` (the default template):

```json
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "desktop_notifications": true,
  "categories": {
    "session.start": true,
    "task.acknowledge": true,
    "task.complete": true,
    "task.error": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  },
  "annoyed_threshold": 3,
  "annoyed_window_seconds": 10,
  "silent_window_seconds": 0,
  "pack_rotation": [],
  "pack_rotation_mode": "random",
  "session_ttl_days": 7,
  "linux_audio_player": "",
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

**Step 5: Commit**

```bash
git add trainer/ config.json
git commit -m "feat(trainer): add directory scaffold and config defaults"
```

---

### Task 2: Add trainer CLI subcommands (on/off/status/log/goal)

**Files:**
- Modify: `peon.sh` (lines 599-1288, the `case` statement)

**Step 1: Write BATS tests for trainer CLI**

Create `tests/trainer.bats`:

```bash
#!/usr/bin/env bats

load setup

setup() {
  setup_test_env

  # Create trainer directory with mock sounds
  mkdir -p "$TEST_DIR/trainer/sounds/remind"
  mkdir -p "$TEST_DIR/trainer/sounds/log"
  mkdir -p "$TEST_DIR/trainer/sounds/complete"
  mkdir -p "$TEST_DIR/trainer/sounds/slacking"

  # Create placeholder sound files
  for d in remind log complete slacking; do
    touch "$TEST_DIR/trainer/sounds/$d/placeholder.wav"
  done

  # Create trainer manifest
  cat > "$TEST_DIR/trainer/manifest.json" <<'JSON'
{
  "trainer.remind": [
    { "file": "sounds/remind/placeholder.wav", "label": "Time for reps!" }
  ],
  "trainer.log": [
    { "file": "sounds/log/placeholder.wav", "label": "Logged." }
  ],
  "trainer.complete": [
    { "file": "sounds/complete/placeholder.wav", "label": "Goal reached!" }
  ],
  "trainer.slacking": [
    { "file": "sounds/slacking/placeholder.wav", "label": "You're falling behind." }
  ]
}
JSON
}

teardown() {
  teardown_test_env
}

# --- trainer on/off ---

@test "trainer on enables trainer in config" {
  run bash "$PEON_SH" trainer on
  [ "$status" -eq 0 ]
  [[ "$output" == *"trainer enabled"* ]]
  # Verify config was updated
  enabled=$(python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('trainer',{}).get('enabled',False))")
  [ "$enabled" = "True" ]
}

@test "trainer off disables trainer in config" {
  # Enable first
  bash "$PEON_SH" trainer on
  run bash "$PEON_SH" trainer off
  [ "$status" -eq 0 ]
  [[ "$output" == *"trainer disabled"* ]]
  enabled=$(python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('trainer',{}).get('enabled',False))")
  [ "$enabled" = "False" ]
}

# --- trainer status ---

@test "trainer status shows progress when enabled" {
  # Enable trainer and set some reps in state
  bash "$PEON_SH" trainer on
  python3 -c "
import json
s = json.load(open('$TEST_DIR/.state.json'))
s['trainer'] = {'date': '$(date +%Y-%m-%d)', 'reps': {'pushups': 50, 'squats': 30}, 'last_reminder_ts': 0}
json.dump(s, open('$TEST_DIR/.state.json', 'w'))
"
  run bash "$PEON_SH" trainer status
  [ "$status" -eq 0 ]
  [[ "$output" == *"pushups"* ]]
  [[ "$output" == *"50/300"* ]]
  [[ "$output" == *"squats"* ]]
  [[ "$output" == *"30/300"* ]]
}

@test "trainer status shows disabled message when off" {
  run bash "$PEON_SH" trainer status
  [ "$status" -eq 0 ]
  [[ "$output" == *"disabled"* ]] || [[ "$output" == *"not enabled"* ]]
}

# --- trainer log ---

@test "trainer log adds reps to state" {
  bash "$PEON_SH" trainer on
  run bash "$PEON_SH" trainer log 25 pushups
  [ "$status" -eq 0 ]
  [[ "$output" == *"25"* ]]
  [[ "$output" == *"pushups"* ]]
  # Check state
  reps=$(python3 -c "import json; print(json.load(open('$TEST_DIR/.state.json')).get('trainer',{}).get('reps',{}).get('pushups',0))")
  [ "$reps" = "25" ]
}

@test "trainer log accumulates reps" {
  bash "$PEON_SH" trainer on
  bash "$PEON_SH" trainer log 25 pushups
  run bash "$PEON_SH" trainer log 30 pushups
  [ "$status" -eq 0 ]
  reps=$(python3 -c "import json; print(json.load(open('$TEST_DIR/.state.json')).get('trainer',{}).get('reps',{}).get('pushups',0))")
  [ "$reps" = "55" ]
}

@test "trainer log rejects unknown exercise" {
  bash "$PEON_SH" trainer on
  run bash "$PEON_SH" trainer log 25 burpees
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown exercise"* ]] || [[ "$output" == *"not configured"* ]]
}

@test "trainer log requires number" {
  bash "$PEON_SH" trainer on
  run bash "$PEON_SH" trainer log abc pushups
  [ "$status" -eq 1 ]
}

# --- trainer goal ---

@test "trainer goal sets both exercises" {
  run bash "$PEON_SH" trainer goal 200
  [ "$status" -eq 0 ]
  pushups=$(python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['trainer']['exercises']['pushups'])")
  squats=$(python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['trainer']['exercises']['squats'])")
  [ "$pushups" = "200" ]
  [ "$squats" = "200" ]
}

@test "trainer goal sets single exercise" {
  run bash "$PEON_SH" trainer goal pushups 100
  [ "$status" -eq 0 ]
  pushups=$(python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['trainer']['exercises']['pushups'])")
  squats=$(python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['trainer']['exercises']['squats'])")
  [ "$pushups" = "100" ]
  [ "$squats" = "300" ]
}

# --- daily reset ---

@test "trainer status resets reps on new day" {
  bash "$PEON_SH" trainer on
  # Set yesterday's state
  python3 -c "
import json
s = json.load(open('$TEST_DIR/.state.json'))
s['trainer'] = {'date': '2020-01-01', 'reps': {'pushups': 250, 'squats': 200}, 'last_reminder_ts': 0}
json.dump(s, open('$TEST_DIR/.state.json', 'w'))
"
  run bash "$PEON_SH" trainer status
  [ "$status" -eq 0 ]
  [[ "$output" == *"0/300"* ]]
}
```

**Step 2: Run tests to verify they fail**

```bash
bats tests/trainer.bats
```

Expected: All tests FAIL (trainer subcommand not implemented yet).

**Step 3: Add trainer subcommand to peon.sh case statement**

Insert before the `--*)` catch-all (line 1282) in the `case` statement. Add a `trainer)` branch:

```bash
  trainer)
    shift
    _trainer_sub="${1:-help}"
    case "$_trainer_sub" in
      on)
        python3 -c "
import json, os
config_path = '$CONFIG'
try:
    c = json.load(open(config_path))
except Exception:
    c = {}
if 'trainer' not in c:
    c['trainer'] = {'enabled': False, 'exercises': {'pushups': 300, 'squats': 300}, 'reminder_interval_minutes': 20, 'reminder_min_gap_minutes': 5}
c['trainer']['enabled'] = True
json.dump(c, open(config_path, 'w'), indent=2)
"
        echo "peon-ping: trainer enabled"
        exit 0 ;;
      off)
        python3 -c "
import json, os
config_path = '$CONFIG'
try:
    c = json.load(open(config_path))
except Exception:
    c = {}
if 'trainer' not in c:
    c['trainer'] = {'enabled': False, 'exercises': {'pushups': 300, 'squats': 300}, 'reminder_interval_minutes': 20, 'reminder_min_gap_minutes': 5}
c['trainer']['enabled'] = False
json.dump(c, open(config_path, 'w'), indent=2)
"
        echo "peon-ping: trainer disabled"
        exit 0 ;;
      status)
        python3 -c "
import json, os, math
from datetime import date

config_path = '$CONFIG'
state_path = '$STATE'

try:
    c = json.load(open(config_path))
except Exception:
    c = {}

trainer_cfg = c.get('trainer', {})
if not trainer_cfg.get('enabled', False):
    print('peon-ping: trainer not enabled (run: peon trainer on)')
    raise SystemExit(0)

exercises = trainer_cfg.get('exercises', {'pushups': 300, 'squats': 300})

try:
    s = json.load(open(state_path))
except Exception:
    s = {}

trainer_state = s.get('trainer', {})
today = date.today().isoformat()

# Auto-reset on new day
if trainer_state.get('date') != today:
    trainer_state = {'date': today, 'reps': {k: 0 for k in exercises}, 'last_reminder_ts': 0}
    s['trainer'] = trainer_state
    json.dump(s, open(state_path, 'w'), indent=2)

reps = trainer_state.get('reps', {})

print(f'Pavel Daily Trainer -- {today}')
print()

bar_width = 16
for ex, goal in exercises.items():
    done = reps.get(ex, 0)
    pct = min(done / goal, 1.0) if goal > 0 else 1.0
    filled = round(pct * bar_width)
    bar = chr(9608) * filled + chr(9617) * (bar_width - filled)
    print(f'  {ex}:  {bar}  {done}/{goal}  ({round(pct*100)}%)')

print()

import time
last_ts = trainer_state.get('last_reminder_ts', 0)
interval = trainer_cfg.get('reminder_interval_minutes', 20)
elapsed = (time.time() - last_ts) / 60 if last_ts > 0 else interval
remaining = max(0, interval - elapsed)
print(f'  Next reminder in ~{round(remaining)} min')
"
        exit 0 ;;
      log)
        shift
        _count="${1:-}"
        _exercise="${2:-}"
        if [ -z "$_count" ] || [ -z "$_exercise" ]; then
          echo "Usage: peon trainer log <count> <exercise>" >&2
          echo "Example: peon trainer log 25 pushups" >&2
          exit 1
        fi
        # Validate count is a number
        if ! [[ "$_count" =~ ^[0-9]+$ ]]; then
          echo "Error: count must be a number, got '$_count'" >&2
          exit 1
        fi
        python3 -c "
import json, os, time
from datetime import date

config_path = '$CONFIG'
state_path = '$STATE'
peon_dir = '$PEON_DIR'
count = int('$_count')
exercise = '$_exercise'

try:
    c = json.load(open(config_path))
except Exception:
    c = {}

trainer_cfg = c.get('trainer', {})
exercises = trainer_cfg.get('exercises', {'pushups': 300, 'squats': 300})

if exercise not in exercises:
    print(f'Error: unknown exercise \"{exercise}\". Configured: {', '.join(exercises.keys())}')
    raise SystemExit(1)

try:
    s = json.load(open(state_path))
except Exception:
    s = {}

today = date.today().isoformat()
trainer_state = s.get('trainer', {})

if trainer_state.get('date') != today:
    trainer_state = {'date': today, 'reps': {k: 0 for k in exercises}, 'last_reminder_ts': 0}

reps = trainer_state.get('reps', {})
reps[exercise] = reps.get(exercise, 0) + count
trainer_state['reps'] = reps
s['trainer'] = trainer_state
json.dump(s, open(state_path, 'w'), indent=2)

goal = exercises[exercise]
total = reps[exercise]
pct = round(min(total / goal, 1.0) * 100) if goal > 0 else 100

# Check if goal just reached
if total >= goal and (total - count) < goal:
    print(f'peon-ping: {exercise} GOAL REACHED! {total}/{goal}')
    # Play trainer.complete sound
    manifest_path = os.path.join(peon_dir, 'trainer', 'manifest.json')
    try:
        m = json.load(open(manifest_path))
        sounds = m.get('trainer.complete', [])
        if sounds:
            sfile = os.path.join(peon_dir, 'trainer', sounds[0]['file'])
            if os.path.isfile(sfile):
                print(f'TRAINER_SOUND={sfile}')
    except Exception:
        pass
else:
    print(f'peon-ping: logged {count} {exercise} ({total}/{goal}, {pct}%)')
    # Play trainer.log sound
    manifest_path = os.path.join(peon_dir, 'trainer', 'manifest.json')
    try:
        m = json.load(open(manifest_path))
        sounds = m.get('trainer.log', [])
        if sounds:
            sfile = os.path.join(peon_dir, 'trainer', sounds[0]['file'])
            if os.path.isfile(sfile):
                print(f'TRAINER_SOUND={sfile}')
    except Exception:
        pass
" || exit $?
        # Play sound if the Python block emitted TRAINER_SOUND
        # (handled in a future task — for now just log/complete text output)
        exit 0 ;;
      goal)
        shift
        _arg1="${1:-}"
        _arg2="${2:-}"
        if [ -z "$_arg1" ]; then
          echo "Usage: peon trainer goal <number>           (set all exercises)" >&2
          echo "       peon trainer goal <exercise> <number> (set one exercise)" >&2
          exit 1
        fi
        python3 -c "
import json
config_path = '$CONFIG'
arg1 = '$_arg1'
arg2 = '$_arg2'

try:
    c = json.load(open(config_path))
except Exception:
    c = {}

if 'trainer' not in c:
    c['trainer'] = {'enabled': False, 'exercises': {'pushups': 300, 'squats': 300}, 'reminder_interval_minutes': 20, 'reminder_min_gap_minutes': 5}

exercises = c['trainer']['exercises']

if arg2:
    # peon trainer goal pushups 100
    exercise = arg1
    try:
        goal = int(arg2)
    except ValueError:
        print(f'Error: goal must be a number, got \"{arg2}\"')
        raise SystemExit(1)
    if exercise not in exercises:
        print(f'Error: unknown exercise \"{exercise}\". Configured: {list(exercises.keys())}')
        raise SystemExit(1)
    exercises[exercise] = goal
    print(f'peon-ping: {exercise} goal set to {goal}')
else:
    # peon trainer goal 200
    try:
        goal = int(arg1)
    except ValueError:
        print(f'Error: goal must be a number, got \"{arg1}\"')
        raise SystemExit(1)
    for ex in exercises:
        exercises[ex] = goal
    print(f'peon-ping: all goals set to {goal}')

c['trainer']['exercises'] = exercises
json.dump(c, open(config_path, 'w'), indent=2)
"
        exit 0 ;;
      help|--help|-h)
        cat <<'TRAINERHELP'
Usage: peon trainer <command>

Commands:
  on                         Enable trainer mode
  off                        Disable trainer mode
  status                     Show today's progress
  log <count> <exercise>     Log reps (e.g. peon trainer log 25 pushups)
  goal <number>              Set goal for all exercises
  goal <exercise> <number>   Set goal for one exercise
  help                       Show this help
TRAINERHELP
        exit 0 ;;
      *)
        echo "Unknown trainer command: $_trainer_sub" >&2
        echo "Run 'peon trainer help' for usage." >&2
        exit 1 ;;
    esac ;;
```

**Step 4: Run tests to verify they pass**

```bash
bats tests/trainer.bats
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add peon.sh tests/trainer.bats
git commit -m "feat(trainer): add CLI subcommands (on/off/status/log/goal)"
```

---

### Task 3: Add trainer reminder logic to Python hook block

**Files:**
- Modify: `peon.sh` (lines 1310-1672, the embedded Python block)

**Step 1: Write BATS tests for trainer reminders on hook events**

Append to `tests/trainer.bats`:

```bash
# --- trainer reminders during hook events ---

@test "hook event fires trainer reminder when interval elapsed" {
  bash "$PEON_SH" trainer on
  # Set last_reminder_ts to long ago so interval has elapsed
  python3 -c "
import json, time
s = json.load(open('$TEST_DIR/.state.json'))
s['trainer'] = {'date': '$(date +%Y-%m-%d)', 'reps': {'pushups': 0, 'squats': 0}, 'last_reminder_ts': int(time.time()) - 3600}
json.dump(s, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Should have played 2 sounds: task.complete + trainer.remind
  count=$(afplay_call_count)
  [ "$count" = "2" ]
}

@test "hook event skips trainer reminder when interval not elapsed" {
  bash "$PEON_SH" trainer on
  # Set last_reminder_ts to now (interval not elapsed)
  python3 -c "
import json, time
s = json.load(open('$TEST_DIR/.state.json'))
s['trainer'] = {'date': '$(date +%Y-%m-%d)', 'reps': {'pushups': 0, 'squats': 0}, 'last_reminder_ts': int(time.time())}
json.dump(s, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Should have played only 1 sound: task.complete (no trainer)
  count=$(afplay_call_count)
  [ "$count" = "1" ]
}

@test "hook event skips trainer reminder on SessionStart" {
  bash "$PEON_SH" trainer on
  python3 -c "
import json, time
s = json.load(open('$TEST_DIR/.state.json'))
s['trainer'] = {'date': '$(date +%Y-%m-%d)', 'reps': {'pushups': 0, 'squats': 0}, 'last_reminder_ts': int(time.time()) - 3600}
json.dump(s, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Should have played only 1 sound: session.start (trainer skipped on SessionStart)
  count=$(afplay_call_count)
  [ "$count" = "1" ]
}

@test "hook event skips trainer reminder when daily goal complete" {
  bash "$PEON_SH" trainer on
  python3 -c "
import json, time
s = json.load(open('$TEST_DIR/.state.json'))
s['trainer'] = {'date': '$(date +%Y-%m-%d)', 'reps': {'pushups': 300, 'squats': 300}, 'last_reminder_ts': int(time.time()) - 3600}
json.dump(s, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count=$(afplay_call_count)
  [ "$count" = "1" ]
}

@test "trainer disabled skips reminder even when interval elapsed" {
  # trainer.enabled defaults to false
  python3 -c "
import json, time
s = json.load(open('$TEST_DIR/.state.json'))
s['trainer'] = {'date': '$(date +%Y-%m-%d)', 'reps': {'pushups': 0, 'squats': 0}, 'last_reminder_ts': int(time.time()) - 3600}
json.dump(s, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count=$(afplay_call_count)
  [ "$count" = "1" ]
}
```

**Step 2: Run tests to verify they fail**

```bash
bats tests/trainer.bats
```

Expected: New hook-event tests FAIL.

**Step 3: Add trainer reminder logic to the Python block**

In the embedded Python block (around line 1650, after the main sound selection but before the final variable output), add trainer check logic. The Python block should:

1. Read `trainer` from config — if not enabled, set `TRAINER_SOUND=""` and skip.
2. Load trainer state from `.state.json` — auto-reset if date doesn't match today.
3. Check if event is `SessionStart` — if so, skip trainer.
4. Check if all exercises at or above goal — if so, skip.
5. Check elapsed time vs interval/min_gap — if not due, skip.
6. Load `trainer/manifest.json`, pick random sound from `trainer.remind` (or `trainer.slacking` if behind pace).
7. Update `last_reminder_ts` in state, save state.
8. Output `TRAINER_SOUND`, `TRAINER_VOL`, `TRAINER_MSG` variables.

The exact insertion point is near the end of the Python block, after `SOUND_FILE` is determined but before the final `print()` statements that output shell variables. Add these output lines:

```python
# --- Trainer reminder check ---
trainer_cfg = config.get('trainer', {})
trainer_sound = ''
trainer_msg = ''
if trainer_cfg.get('enabled', False) and event != 'session.start':
    import time as _time
    from datetime import date as _date
    today = _date.today().isoformat()
    trainer_state = state.get('trainer', {})
    if trainer_state.get('date') != today:
        exercises = trainer_cfg.get('exercises', {'pushups': 300, 'squats': 300})
        trainer_state = {'date': today, 'reps': {k: 0 for k in exercises}, 'last_reminder_ts': 0}

    exercises = trainer_cfg.get('exercises', {'pushups': 300, 'squats': 300})
    reps = trainer_state.get('reps', {})
    all_done = all(reps.get(ex, 0) >= goal for ex, goal in exercises.items())

    if not all_done:
        now = _time.time()
        last_ts = trainer_state.get('last_reminder_ts', 0)
        interval = trainer_cfg.get('reminder_interval_minutes', 20) * 60
        min_gap = trainer_cfg.get('reminder_min_gap_minutes', 5) * 60
        elapsed = now - last_ts

        if elapsed >= interval and elapsed >= min_gap:
            # Pick trainer sound
            trainer_manifest_path = os.path.join(peon_dir, 'trainer', 'manifest.json')
            try:
                tm = json.load(open(trainer_manifest_path))
                # Pace check: past noon and < 25% done = slacking
                import datetime
                hour = datetime.datetime.now().hour
                total_reps = sum(reps.get(ex, 0) for ex in exercises)
                total_goal = sum(exercises.values())
                pct = total_reps / total_goal if total_goal > 0 else 1.0
                if hour >= 12 and pct < 0.25:
                    cat = 'trainer.slacking'
                else:
                    cat = 'trainer.remind'
                sounds = tm.get(cat, [])
                if sounds:
                    import random
                    pick = random.choice(sounds)
                    sfile = os.path.join(peon_dir, 'trainer', pick['file'])
                    if os.path.isfile(sfile):
                        trainer_sound = sfile
                        # Build progress message
                        parts = []
                        for ex, goal in exercises.items():
                            done = reps.get(ex, 0)
                            parts.append(f'{ex}: {done}/{goal}')
                        trainer_msg = ' | '.join(parts)
            except Exception:
                pass

            trainer_state['last_reminder_ts'] = int(now)

    state['trainer'] = trainer_state
    # State is saved later with existing state-save logic
```

Then in the output section, add:

```python
print(f"TRAINER_SOUND='{trainer_sound}'")
print(f"TRAINER_MSG='{trainer_msg}'")
```

**Step 4: Add trainer sound playback to shell section**

After the main `_run_sound_and_notify` call (around line 1781), add trainer sound playback:

```bash
# --- Trainer reminder sound (delayed, after main sound) ---
if [ -n "${TRAINER_SOUND:-}" ] && [ -f "$TRAINER_SOUND" ]; then
  (
    sleep 1
    play_sound "$TRAINER_SOUND" "$VOLUME"
    if [ "${NOTIFY:-}" = "1" ]; then
      send_notification "Trainer" "${TRAINER_MSG:-Time for reps!}" "${NOTIFY_COLOR:-blue}"
    fi
  ) &
  if [ "${PEON_TEST:-0}" != "1" ]; then
    disown 2>/dev/null
  fi
fi
```

For test mode (PEON_TEST=1), the delayed playback needs to be synchronous. Adjust to:

```bash
if [ -n "${TRAINER_SOUND:-}" ] && [ -f "$TRAINER_SOUND" ]; then
  if [ "${PEON_TEST:-0}" = "1" ]; then
    play_sound "$TRAINER_SOUND" "$VOLUME"
  else
    (
      sleep 1
      play_sound "$TRAINER_SOUND" "$VOLUME"
      if [ "${NOTIFY:-}" = "1" ]; then
        send_notification "Trainer" "${TRAINER_MSG:-Time for reps!}" "${NOTIFY_COLOR:-blue}"
      fi
    ) & disown 2>/dev/null
  fi
fi
```

**Step 5: Run tests to verify they pass**

```bash
bats tests/trainer.bats
```

Expected: All tests PASS.

**Step 6: Run full test suite to ensure no regressions**

```bash
bats tests/peon.bats
```

Expected: All existing tests still PASS.

**Step 7: Commit**

```bash
git add peon.sh tests/trainer.bats
git commit -m "feat(trainer): add reminder logic to hook event pipeline"
```

---

### Task 4: Add trainer help text and README docs

**Files:**
- Modify: `peon.sh` (help text around line 1245)
- Modify: `README.md`

**Step 1: Add trainer to main help output**

In the `help)` case (around line 1245), add a trainer section to the help text:

```
  trainer on|off           Enable/disable daily exercise trainer
  trainer status           Show today's progress
  trainer log N exercise   Log reps (e.g. peon trainer log 25 pushups)
  trainer goal N           Set goal for all exercises
  trainer goal EX N        Set goal for one exercise
  trainer help             Show trainer help
```

**Step 2: Add trainer section to README.md**

Add a section after the existing features documentation:

```markdown
## Trainer Mode

Built-in Pavel-style daily exercise trainer. Reminds you to do pushups and squats
while you code — uses custom voice lines that play alongside your normal peon-ping sounds.

### Quick Start

```bash
peon trainer on              # enable trainer
peon trainer goal 200        # set both exercises to 200 (default: 300)
# ... code for a while, get reminded to do reps ...
peon trainer log 25 pushups  # log what you did
peon trainer log 30 squats
peon trainer status          # check progress
```

### How It Works

Trainer reminders piggyback on your coding session — every ~20 minutes of active
coding, you'll hear a voice line reminding you to do reps. No background daemon needed.

Log your reps with `peon trainer log`, and progress resets automatically at midnight.

### Custom Voice Lines

Drop your own audio files into `~/.claude/hooks/peon-ping/trainer/sounds/`:

```
trainer/sounds/remind/     # reminder voice lines
trainer/sounds/log/        # acknowledgment when logging reps
trainer/sounds/complete/   # celebration when daily goal is hit
trainer/sounds/slacking/   # fired when you're behind pace
```

Update `trainer/manifest.json` to register your sound files.
```

**Step 3: Commit**

```bash
git add peon.sh README.md
git commit -m "docs: add trainer mode to help text and README"
```

---

### Task 5: Final integration test and cleanup

**Step 1: Run full test suite**

```bash
bats tests/
```

Expected: All tests pass across all test files.

**Step 2: Manual smoke test**

```bash
# Enable trainer
peon trainer on

# Check status
peon trainer status

# Log some reps
peon trainer log 25 pushups
peon trainer log 30 squats

# Check progress updated
peon trainer status

# Set custom goal
peon trainer goal 100

# Disable
peon trainer off
```

**Step 3: Verify config.json template is clean**

Read `config.json` and confirm the trainer section is present with correct defaults.

**Step 4: Commit any fixups if needed**

If any issues found during smoke testing, fix and commit.

---

## Summary

| Task | Description | Key Files |
|------|-------------|-----------|
| 1 | Branch + scaffold | `trainer/`, `config.json` |
| 2 | CLI subcommands | `peon.sh`, `tests/trainer.bats` |
| 3 | Hook reminder logic | `peon.sh` (Python block + shell playback) |
| 4 | Help text + README | `peon.sh`, `README.md` |
| 5 | Integration test | All files |
