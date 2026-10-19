#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {}, "session_start_cooldown_seconds": 0,
  "pack_rotation": ["peon", "sc_kerrigan"],
  "pack_rotation_mode": "round-robin"
}
JSON
  # Each invocation has a controlled terminal identity, including no terminal.
  # The hook walks one `ps -A` table: keep the real parent chain and give every
  # process the test's terminal. The per-pid cases serve the fallback walk.
  export TEST_HOOK_TTY=""
  cat > "$MOCK_BIN/ps" <<'SCRIPT'
#!/bin/bash
case "$*" in
  "-A -o pid=,ppid=,tty=")
    /bin/ps -A -o pid=,ppid= | while read -r pid ppid; do
      printf '%s %s %s\n' "$pid" "$ppid" "${TEST_HOOK_TTY:-??}"
    done ;;
  *"-o tty="*) printf '%s\n' "$TEST_HOOK_TTY" ;;
  *"-o ppid="*) echo 1 ;;
  *) /bin/ps "$@" ;;
esac
SCRIPT
  chmod +x "$MOCK_BIN/ps"
}

teardown() {
  teardown_test_env
}

assert_session_pack() {
  "$PEON_PY" - "$TEST_DIR/.state.json" "$1" "$2" <<'PYTHON'
import json, sys
state = json.load(open(sys.argv[1]))
entry = state['session_packs'][sys.argv[2]]
pack = entry['pack'] if isinstance(entry, dict) else entry
assert pack == sys.argv[3], (sys.argv[2], pack, sys.argv[3])
PYTHON
}

@test "rotation: rapid independent sessions in the same directory each advance round-robin" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/project","session_id":"first"}'
  assert_session_pack first peon
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/project","session_id":"first"}'
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/project","session_id":"second"}'
  assert_session_pack second sc_kerrigan
  [[ "$(afplay_sound)" == *"/packs/sc_kerrigan/sounds/"* ]]
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/project","session_id":"third"}'
  assert_session_pack third peon
}

@test "rotation: startup does not inherit another session even on the same terminal" {
  export TEST_HOOK_TTY=ttys001
  run_peon '{"hook_event_name":"SessionStart","source":"startup","cwd":"/tmp/project","session_id":"first"}'
  run_peon '{"hook_event_name":"SessionStart","source":"startup","cwd":"/tmp/project","session_id":"second"}'
  assert_session_pack second sc_kerrigan
}

@test "rotation: random independently selects a pack despite unrelated recent activity" {
  "$PEON_PY" - "$TEST_DIR" <<'PYTHON'
import json, sys, time
root = sys.argv[1]
cfg = json.load(open(root + '/config.json'))
cfg['pack_rotation_mode'] = 'random'
json.dump(cfg, open(root + '/config.json', 'w'))
json.dump({'last_active': {'session_id': 'other', 'pack': 'peon',
                         'timestamp': time.time(), 'event': 'UserPromptSubmit'}},
          open(root + '/.state.json', 'w'))
PYTHON
  # The routing interpreter is isolated (-I), so PYTHONPATH/sitecustomize is
  # intentionally ignored. Bootstrap the unchanged routing file in that same
  # isolated interpreter, controlling only pack randomness, not sound choice.
  cat > "$MOCK_BIN/python3" <<'SCRIPT'
#!/bin/bash
if [ "$#" -eq 2 ] && [ "$1" = -I ] && [ -f "$2" ]; then
  exec "$PEON_PY" -I -c '
import random, runpy, sys
choice = random.choice
def choose(values):
    if values == ["peon", "sc_kerrigan"]:
        return "sc_kerrigan"
    return choice(values)
random.choice = choose
sys.argv = sys.argv[1:]
runpy.run_path(sys.argv[0], run_name="__main__")
' "$2"
fi
exec "$PEON_PY" "$@"
SCRIPT
  chmod +x "$MOCK_BIN/python3"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/project","session_id":"new"}'
  assert_session_pack new sc_kerrigan
}

@test "rotation: resume without a cached pack cannot borrow an unrelated last_active" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/project","session_id":"first"}'
  run_peon '{"hook_event_name":"SessionStart","source":"resume","cwd":"/tmp/project","session_id":"resumed"}'
  assert_session_pack resumed sc_kerrigan
}

@test "rotation: resume restores last_active only for the matching session" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/project","session_id":"first"}'
  run_peon '{"hook_event_name":"SessionEnd","cwd":"/tmp/project","session_id":"first"}'
  run_peon '{"hook_event_name":"SessionStart","source":"resume","cwd":"/tmp/project","session_id":"first"}'
  assert_session_pack first peon
}

@test "rotation: cached resume and compact preserve their pack after another session runs" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/project","session_id":"first"}'
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/project","session_id":"second"}'
  run_peon '{"hook_event_name":"SessionStart","source":"resume","cwd":"/tmp/project","session_id":"first"}'
  assert_session_pack first peon
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/project","session_id":"second"}'
  count_before=$(afplay_call_count)
  run_peon '{"hook_event_name":"SessionStart","source":"compact","cwd":"/tmp/project","session_id":"first"}'
  assert_session_pack first peon
  [ "$(afplay_call_count)" = "$count_before" ]
}

@test "rotation: explicit compact with a new ID inherits on the same terminal and directory" {
  export TEST_HOOK_TTY=ttys001
  run_peon '{"hook_event_name":"PreCompact","cwd":"/tmp/project","session_id":"first"}'
  count_before=$(afplay_call_count)
  run_peon '{"hook_event_name":"SessionStart","source":"compact","cwd":"/tmp/project","session_id":"compacted"}'
  assert_session_pack compacted peon
  [ "$(afplay_call_count)" = "$count_before" ]
}

# A ps that rejects -A makes the hook fall back to one lookup per ancestor.
use_ps_without_list_all() {
  cat > "$MOCK_BIN/ps" <<'SCRIPT'
#!/bin/bash
case "$*" in
  *"-A"*) exit 1 ;;
  *"-o tty="*) printf '%s\n' "$TEST_HOOK_TTY" ;;
  *"-o ppid="*) echo 1 ;;
  *) /bin/ps "$@" ;;
esac
SCRIPT
  chmod +x "$MOCK_BIN/ps"
}

@test "rotation: without ps -A, compact on the same terminal still inherits" {
  use_ps_without_list_all
  export TEST_HOOK_TTY=ttys001
  run_peon '{"hook_event_name":"PreCompact","cwd":"/tmp/project","session_id":"first"}'
  run_peon '{"hook_event_name":"SessionStart","source":"compact","cwd":"/tmp/project","session_id":"compacted"}'
  assert_session_pack compacted peon
}

@test "rotation: without ps -A, compact from a different terminal still cannot inherit" {
  use_ps_without_list_all
  export TEST_HOOK_TTY=ttys001
  run_peon '{"hook_event_name":"PreCompact","cwd":"/tmp/project","session_id":"first"}'
  export TEST_HOOK_TTY=ttys002
  run_peon '{"hook_event_name":"SessionStart","source":"compact","cwd":"/tmp/project","session_id":"compacted"}'
  assert_session_pack compacted sc_kerrigan
}

@test "rotation: compact from a different terminal cannot inherit another session" {
  export TEST_HOOK_TTY=ttys001
  run_peon '{"hook_event_name":"PreCompact","cwd":"/tmp/project","session_id":"first"}'
  export TEST_HOOK_TTY=ttys002
  count_before=$(afplay_call_count)
  run_peon '{"hook_event_name":"SessionStart","source":"compact","cwd":"/tmp/project","session_id":"compacted"}'
  assert_session_pack compacted sc_kerrigan
}

@test "rotation: compact without a terminal identity cannot inherit another session" {
  run_peon '{"hook_event_name":"PreCompact","cwd":"/tmp/project","session_id":"first"}'
  count_before=$(afplay_call_count)
  run_peon '{"hook_event_name":"SessionStart","source":"compact","cwd":"/tmp/project","session_id":"compacted"}'
  assert_session_pack compacted sc_kerrigan
}

@test "rotation: compact in another directory cannot inherit a previous terminal session" {
  export TEST_HOOK_TTY=ttys001
  run_peon '{"hook_event_name":"PreCompact","cwd":"/tmp/project","session_id":"first"}'
  count_before=$(afplay_call_count)
  run_peon '{"hook_event_name":"SessionStart","source":"compact","cwd":"/tmp/other","session_id":"compacted"}'
  assert_session_pack compacted sc_kerrigan
}

@test "rotation: unrelated startup after SubagentStart neither inherits nor becomes a subagent" {
  run_peon '{"hook_event_name":"SubagentStart","cwd":"/tmp/project","session_id":"parent","agent_id":"child-agent"}'
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/project","session_id":"unrelated"}'
  assert_session_pack unrelated sc_kerrigan
  "$PEON_PY" - "$TEST_DIR/.state.json" <<'PYTHON'
import json, sys
state = json.load(open(sys.argv[1]))
assert 'unrelated' not in state.get('subagent_sessions', {}), state
PYTHON
}

@test "rotation: a different agent ID cannot inherit a pending subagent pack" {
  run_peon '{"hook_event_name":"SubagentStart","cwd":"/tmp/project","session_id":"parent","agent_id":"child-agent"}'
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/project","session_id":"unrelated","agent_id":"other-agent"}'
  assert_session_pack unrelated sc_kerrigan
}

@test "rotation: identified child inherits its parent pack after unrelated activity" {
  run_peon '{"hook_event_name":"SubagentStart","cwd":"/tmp/project","session_id":"parent","agent_id":"child-agent"}'
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/other","session_id":"unrelated"}'
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/project","session_id":"child","agent_id":"child-agent"}'
  assert_session_pack child peon
  "$PEON_PY" - "$TEST_DIR/.state.json" <<'PYTHON'
import json, sys
state = json.load(open(sys.argv[1]))
assert 'child' in state['subagent_sessions'], state
PYTHON
}
