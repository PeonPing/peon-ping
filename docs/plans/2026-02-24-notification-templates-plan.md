# Notification Message Templates — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let users configure notification message content with format string templates per event type, defaulting to current behavior.

**Architecture:** Single config key `notification_templates` holds per-event format strings. A template resolution block in the Python event parser applies `str.format_map()` with available variables after each event sets its default `msg`. CLI subcommand `peon notifications template` provides get/set/reset.

**Tech Stack:** Bash + embedded Python (peon.sh), BATS tests

---

### Task 1: Template Resolution in Python Event Parser

**Files:**
- Modify: `peon.sh:2620-2625` (revert hardcoded summary concat)
- Modify: `peon.sh:2863` (insert template resolution before shell variable output block)

**Step 1: Revert the hardcoded transcript_summary change**

Replace the current Stop message block (lines 2620-2624):

```python
        _summary = event_data.get('transcript_summary', '').strip()
        if _summary:
            msg = project + ': ' + _summary[:120]
        else:
            msg = project
```

Back to the original default:

```python
        msg = project
```

This keeps `msg = project` as the default for all events. Templates will handle enrichment.

**Step 2: Add template resolution block**

Insert this Python block at `peon.sh` just BEFORE the line `# --- Output shell variables ---` (currently line 2864), after the tab color block ends:

```python
# --- Notification message template resolution ---
from collections import defaultdict as _defaultdict
_templates = cfg.get('notification_templates', {})
_tpl_key_map = {
    'task.complete': 'stop',
    'task.error': 'error',
}
_tpl_key = _tpl_key_map.get(category, '')
if event == 'Notification':
    if ntype == 'idle_prompt': _tpl_key = 'idle'
    elif ntype == 'elicitation_dialog': _tpl_key = 'question'
elif event == 'PermissionRequest':
    _tpl_key = 'permission'
_tpl = _templates.get(_tpl_key, '')
if _tpl:
    _tpl_vars = _defaultdict(str, {
        'project': project,
        'summary': event_data.get('transcript_summary', '').strip()[:120],
        'tool_name': event_data.get('tool_name', ''),
        'status': status,
        'event': event,
    })
    try:
        msg = _tpl.format_map(_tpl_vars)
    except Exception:
        pass
```

**Step 3: Run existing tests to verify no regression**

Run: `cd ~/iWorld/projects/peon-ping && bats tests/mac-overlay.bats`
Expected: All existing tests pass (the default `msg = project` behavior is unchanged when no templates configured).

**Step 4: Commit**

```bash
git add peon.sh
git commit -m "feat: notification message template resolution engine

Reads notification_templates from config.json and applies format_map
with available variables ({project}, {summary}, {tool_name}, {status},
{event}). Defaults to current behavior when no templates configured."
```

---

### Task 2: CLI Subcommand — `peon notifications template`

**Files:**
- Modify: `peon.sh:1068` (add `template)` case before the `*)` fallback)
- Modify: `peon.sh:1070` (update usage string)

**Step 1: Add the `template` case**

Insert before line 1069 (`*)`):

```bash
      template)
        TPL_KEY="${3:-}"
        TPL_VAL="${4:-}"
        if [ -z "$TPL_KEY" ]; then
          # Show all templates
          python3 -c "
import json
try:
    cfg = json.load(open('$CONFIG_PY'))
    tpls = cfg.get('notification_templates', {})
except Exception:
    tpls = {}
if not tpls:
    print('peon-ping: no notification templates configured (using defaults)')
else:
    valid = ('stop', 'permission', 'error', 'idle', 'question')
    for k in valid:
        v = tpls.get(k, '')
        if v:
            print(f'peon-ping: template {k} = \"{v}\"')
    extra = set(tpls) - set(valid)
    for k in sorted(extra):
        print(f'peon-ping: template {k} = \"{tpls[k]}\" (unknown key)')
"
          exit 0
        fi
        if [ "$TPL_KEY" = "--reset" ]; then
          python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg.pop('notification_templates', None)
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: notification templates cleared')
"
          sync_adapter_configs; exit 0
        fi
        # Validate key
        python3 -c "
import json, sys
config_path = '$CONFIG_PY'
key = '$TPL_KEY'
valid = ('stop', 'permission', 'error', 'idle', 'question')
if key not in valid:
    print(f'peon-ping: invalid template key \"{key}\" — use one of: ' + ', '.join(valid), file=sys.stderr)
    sys.exit(1)
val = sys.argv[1] if len(sys.argv) > 1 else ''
if not val:
    # Show single template
    try:
        cfg = json.load(open(config_path))
        tpls = cfg.get('notification_templates', {})
    except Exception:
        tpls = {}
    v = tpls.get(key, '')
    if v:
        print(f'peon-ping: template {key} = \"{v}\"')
    else:
        print(f'peon-ping: template {key} not set (default: \"{{project}}\")')
    sys.exit(0)
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
tpls = cfg.get('notification_templates', {})
tpls[key] = val
cfg['notification_templates'] = tpls
json.dump(cfg, open(config_path, 'w'), indent=2)
print(f'peon-ping: template {key} set to \"{val}\"')
" "$TPL_VAL"
        _rc=$?; [ "$_rc" -ne 0 ] && exit "$_rc"
        sync_adapter_configs; exit 0 ;;
```

**Step 2: Update usage string**

Change line 1070 from:
```
echo "Usage: peon notifications <on|off|overlay|standard|position|dismiss|label|test>" >&2; exit 1 ;;
```
To:
```
echo "Usage: peon notifications <on|off|overlay|standard|position|dismiss|label|template|test>" >&2; exit 1 ;;
```

**Step 3: Update help text**

Find the help text block (~line 1981-1982) and add after the `label` line:
```
  notifications template [key] [fmt]  Get/set message templates (keys: stop, permission, error, idle, question)
```

**Step 4: Add template display to `peon status`**

In the Python status output block (~lines 765-770), after the label/project_name_map display, add:

```python
_tpls = c.get('notification_templates', {})
if _tpls:
    print('peon-ping: notification templates:')
    for _tk, _tv in _tpls.items():
        print(f'  {_tk} = "{_tv}"')
```

**Step 5: Run tests**

Run: `cd ~/iWorld/projects/peon-ping && bats tests/mac-overlay.bats`
Expected: All existing tests still pass.

**Step 6: Commit**

```bash
git add peon.sh
git commit -m "feat: peon notifications template CLI for get/set/reset"
```

---

### Task 3: BATS Tests for Notification Templates

**Files:**
- Modify: `tests/mac-overlay.bats` (append new test section after the label priority chain tests, ~line 663)

**Step 1: Write the tests**

Append to `tests/mac-overlay.bats`:

```bash
# ============================================================
# Notification message templates
# ============================================================

@test "peon notifications template shows no templates by default" {
  output=$(bash "$PEON_SH" notifications template 2>/dev/null)
  [[ "$output" == *"no notification templates"* ]]
}

@test "peon notifications template stop sets config" {
  bash "$PEON_SH" notifications template stop '{project}: {summary}'
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
tpls = cfg.get('notification_templates', {})
assert tpls.get('stop') == '{project}: {summary}', f'Got: {tpls}'
"
}

@test "peon notifications template stop shows current value" {
  bash "$PEON_SH" notifications template stop '{project}: {summary}'
  output=$(bash "$PEON_SH" notifications template stop 2>/dev/null)
  [[ "$output" == *'{project}: {summary}'* ]]
}

@test "peon notifications template rejects invalid key" {
  run bash "$PEON_SH" notifications template bogus '{project}'
  [ "$status" -ne 0 ]
}

@test "peon notifications template --reset clears all templates" {
  bash "$PEON_SH" notifications template stop '{project}: {summary}'
  bash "$PEON_SH" notifications template permission '{project}: {tool_name}'
  bash "$PEON_SH" notifications template --reset
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
assert 'notification_templates' not in cfg, f'Templates still present: {cfg}'
"
}

@test "template: Stop with {summary} renders transcript_summary" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_templates'] = {'stop': '{project}: {summary}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default","transcript_summary":"Fixed the login bug"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"myproject: Fixed the login bug"* ]]
}

@test "template: Stop without transcript_summary renders empty summary" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_templates'] = {'stop': '{project}: {summary}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"myproject: "* ]]
}

@test "template: PermissionRequest with {tool_name}" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_templates'] = {'permission': '{project}: {tool_name} needs approval'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"PermissionRequest","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default","tool_name":"Bash"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"myproject: Bash needs approval"* ]]
}

@test "template: no template configured falls back to project name" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default","transcript_summary":"Some work done"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  # Without template, msg is just project name (no summary appended)
  local log
  log="$(overlay_log)"
  [[ "$log" == *"myproject"* ]]
  [[ "$log" != *"Some work done"* ]]
}

@test "template: unknown variable renders as empty string" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_templates'] = {'stop': '{project} - {nonexistent}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"myproject - "* ]]
}

@test "peon status shows templates when configured" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_templates'] = {'stop': '{project}: {summary}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  output=$(bash "$PEON_SH" status 2>/dev/null)
  [[ "$output" == *"notification templates"* ]]
  [[ "$output" == *"{project}: {summary}"* ]]
}
```

**Step 2: Run the new tests**

Run: `cd ~/iWorld/projects/peon-ping && bats tests/mac-overlay.bats`
Expected: All tests pass including the new template tests.

**Step 3: Run full test suite**

Run: `cd ~/iWorld/projects/peon-ping && bats tests/`
Expected: All 55+ tests pass.

**Step 4: Commit**

```bash
git add tests/mac-overlay.bats
git commit -m "test: BATS tests for notification message templates"
```

---

### Task 4: Integration Test with Live Hooks

**Step 1: Configure template in the dev config**

```bash
~/iWorld/projects/peon-ping/peon.sh notifications template stop '{project}: {summary}'
~/iWorld/projects/peon-ping/peon.sh notifications template permission '{project}: {tool_name} needs approval'
```

**Step 2: Fire test notifications**

```bash
echo '{"hook_event_name":"Stop","session_id":"tpl-test","cwd":"/path/to/my-project","transcript_summary":"Added notification templates"}' | ~/.claude/hooks/peon-ping/peon.sh 2>/dev/null &
```

Expected: Overlay shows "My Project: Added notification templates" at top-right, persistent.

**Step 3: Verify stacking still works**

Fire a second notification. Both should stack vertically, no overlap.

**Step 4: Verify default behavior**

Reset templates and fire again — notification should show just "My Project".

```bash
~/iWorld/projects/peon-ping/peon.sh notifications template --reset
```
