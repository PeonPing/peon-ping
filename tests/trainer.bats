#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  # Create trainer sound directory with mock sounds
  mkdir -p "$TEST_DIR/packs/peon/sounds/trainer"
  for f in encouragement1.wav encouragement2.wav reminder1.wav; do
    touch "$TEST_DIR/packs/peon/sounds/trainer/$f"
  done

  # Create trainer manifest and dummy sound files for reminder tests
  mkdir -p "$TEST_DIR/trainer/sounds/remind"
  mkdir -p "$TEST_DIR/trainer/sounds/slacking"
  mkdir -p "$TEST_DIR/trainer/sounds/log"
  mkdir -p "$TEST_DIR/trainer/sounds/complete"

  mkdir -p "$TEST_DIR/trainer/sounds/session_start"

  cat > "$TEST_DIR/trainer/manifest.json" <<'JSON'
{
  "trainer.session_start": [
    { "file": "sounds/session_start/start.mp3", "label": "Session start! Pushups first!" }
  ],
  "trainer.remind": [
    { "file": "sounds/remind/reminder.mp3", "label": "Time for reps!" }
  ],
  "trainer.slacking": [
    { "file": "sounds/slacking/slacking.mp3", "label": "You are slacking!" }
  ],
  "trainer.log": [
    { "file": "sounds/log/logged.mp3", "label": "Logged!" }
  ],
  "trainer.complete": [
    { "file": "sounds/complete/done.mp3", "label": "All done!" }
  ]
}
JSON

  touch "$TEST_DIR/trainer/sounds/session_start/start.mp3"
  touch "$TEST_DIR/trainer/sounds/remind/reminder.mp3"
  touch "$TEST_DIR/trainer/sounds/slacking/slacking.mp3"
  touch "$TEST_DIR/trainer/sounds/log/logged.mp3"
  touch "$TEST_DIR/trainer/sounds/complete/done.mp3"
}

teardown() {
  teardown_test_env
}

# ============================================================
# trainer on / off
# ============================================================

@test "trainer on enables trainer in config.json" {
  run bash "$PEON_SH" trainer on
  [ "$status" -eq 0 ]
  [[ "$output" == *"trainer enabled"* ]]

  # Verify config.json has trainer.enabled = true
  enabled=$(python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('trainer',{}).get('enabled',False))")
  [ "$enabled" = "True" ]
}

@test "trainer off disables trainer in config.json" {
  # First enable
  bash "$PEON_SH" trainer on
  # Then disable
  run bash "$PEON_SH" trainer off
  [ "$status" -eq 0 ]
  [[ "$output" == *"trainer disabled"* ]]

  enabled=$(python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('trainer',{}).get('enabled',False))")
  [ "$enabled" = "False" ]
}

# ============================================================
# trainer status
# ============================================================

@test "trainer status shows progress when enabled" {
  # Enable trainer and add some reps to state
  bash "$PEON_SH" trainer on
  python3 -c "
import json, datetime
state_path = '$TEST_DIR/.state.json'
s = json.load(open(state_path))
s['trainer'] = {'date': datetime.date.today().isoformat(), 'reps': {'pushups': 125, 'squats': 50}, 'last_reminder_ts': 0}
json.dump(s, open(state_path, 'w'), indent=2)
"
  run bash "$PEON_SH" trainer status
  [ "$status" -eq 0 ]
  [[ "$output" == *"pushups"* ]]
  [[ "$output" == *"125"* ]]
  [[ "$output" == *"squats"* ]]
  [[ "$output" == *"50"* ]]
}

@test "trainer status shows not enabled when off" {
  run bash "$PEON_SH" trainer status
  [ "$status" -eq 0 ]
  [[ "$output" == *"not enabled"* ]]
}

# ============================================================
# trainer log
# ============================================================

@test "trainer log adds reps to state" {
  bash "$PEON_SH" trainer on
  run bash "$PEON_SH" trainer log 25 pushups
  [ "$status" -eq 0 ]
  [[ "$output" == *"25"* ]]
  [[ "$output" == *"pushups"* ]]

  reps=$(python3 -c "import json; s=json.load(open('$TEST_DIR/.state.json')); print(s.get('trainer',{}).get('reps',{}).get('pushups',0))")
  [ "$reps" = "25" ]
}

@test "trainer log accumulates reps across calls" {
  bash "$PEON_SH" trainer on
  bash "$PEON_SH" trainer log 25 pushups
  bash "$PEON_SH" trainer log 30 pushups
  run bash "$PEON_SH" trainer log 10 pushups
  [ "$status" -eq 0 ]

  reps=$(python3 -c "import json; s=json.load(open('$TEST_DIR/.state.json')); print(s.get('trainer',{}).get('reps',{}).get('pushups',0))")
  [ "$reps" = "65" ]
}

@test "trainer log rejects unknown exercise" {
  bash "$PEON_SH" trainer on
  run bash "$PEON_SH" trainer log 25 burpees
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown exercise"* ]] || [[ "$output" == *"Unknown exercise"* ]]
}

@test "trainer log requires numeric count" {
  bash "$PEON_SH" trainer on
  run bash "$PEON_SH" trainer log abc pushups
  [ "$status" -ne 0 ]
  [[ "$output" == *"numeric"* ]] || [[ "$output" == *"number"* ]]
}

# ============================================================
# trainer goal
# ============================================================

@test "trainer goal sets both exercises" {
  bash "$PEON_SH" trainer on
  run bash "$PEON_SH" trainer goal 200
  [ "$status" -eq 0 ]

  pushups_goal=$(python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('trainer',{}).get('exercises',{}).get('pushups',0))")
  squats_goal=$(python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('trainer',{}).get('exercises',{}).get('squats',0))")
  [ "$pushups_goal" = "200" ]
  [ "$squats_goal" = "200" ]
}

@test "trainer goal sets single exercise" {
  bash "$PEON_SH" trainer on
  run bash "$PEON_SH" trainer goal pushups 100
  [ "$status" -eq 0 ]

  pushups_goal=$(python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('trainer',{}).get('exercises',{}).get('pushups',0))")
  [ "$pushups_goal" = "100" ]
}

# ============================================================
# trainer goal adds new exercise type
# ============================================================

@test "trainer goal adds new exercise type" {
  bash "$PEON_SH" trainer on
  run bash "$PEON_SH" trainer goal pullups 10
  [ "$status" -eq 0 ]
  [[ "$output" == *"new exercise added"* ]]

  pullups_goal=$(python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('trainer',{}).get('exercises',{}).get('pullups','missing'))")
  [ "$pullups_goal" = "10" ]
}

# ============================================================
# trainer log suggests goal for unknown exercise
# ============================================================

@test "trainer log suggests goal for unknown exercise" {
  bash "$PEON_SH" trainer on
  run bash "$PEON_SH" trainer log 5 pullups
  [ "$status" -ne 0 ]
  [[ "$output" == *"peon trainer goal pullups"* ]]
}

# ============================================================
# trainer status resets reps on new day
# ============================================================

@test "trainer status resets reps on new day" {
  bash "$PEON_SH" trainer on
  # Set state with an old date
  python3 -c "
import json
state_path = '$TEST_DIR/.state.json'
s = json.load(open(state_path))
s['trainer'] = {'date': '2020-01-01', 'reps': {'pushups': 200, 'squats': 150}, 'last_reminder_ts': 0}
json.dump(s, open(state_path, 'w'), indent=2)
"
  run bash "$PEON_SH" trainer status
  [ "$status" -eq 0 ]
  # Reps should have been reset to 0
  reps=$(python3 -c "import json; s=json.load(open('$TEST_DIR/.state.json')); print(s.get('trainer',{}).get('reps',{}).get('pushups',0))")
  [ "$reps" = "0" ]
}

# ============================================================
# trainer reminders during hook events
# ============================================================

@test "hook event fires trainer reminder when interval elapsed" {
  bash "$PEON_SH" trainer on
  python3 -c "
import json, time
s = json.load(open('$TEST_DIR/.state.json'))
s['trainer'] = {'date': '$(date +%Y-%m-%d)', 'reps': {'pushups': 0, 'squats': 0}, 'last_reminder_ts': int(time.time()) - 3600}
json.dump(s, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count=$(afplay_call_count)
  [ "$count" = "2" ]
}

@test "hook event skips trainer reminder when interval not elapsed" {
  bash "$PEON_SH" trainer on
  python3 -c "
import json, time
s = json.load(open('$TEST_DIR/.state.json'))
s['trainer'] = {'date': '$(date +%Y-%m-%d)', 'reps': {'pushups': 0, 'squats': 0}, 'last_reminder_ts': int(time.time())}
json.dump(s, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count=$(afplay_call_count)
  [ "$count" = "1" ]
}

@test "hook event fires session_start sound on SessionStart" {
  bash "$PEON_SH" trainer on
  python3 -c "
import json, time
s = json.load(open('$TEST_DIR/.state.json'))
s['trainer'] = {'date': '$(date +%Y-%m-%d)', 'reps': {'pushups': 0, 'squats': 0}, 'last_reminder_ts': int(time.time()) - 3600}
json.dump(s, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count=$(afplay_call_count)
  # 2 calls: main session sound + trainer session_start sound
  [ "$count" = "2" ]
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
