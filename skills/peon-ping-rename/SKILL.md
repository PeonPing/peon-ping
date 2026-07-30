---
name: peon-ping-rename
description: Rename the current Claude session for peon-ping notifications and terminal tab title. Use when user wants to give this session a custom name like "/peon-ping-rename Auth Refactor". Call with no argument to reset to auto-detect.
user-invocable: true
license: MIT
metadata:
  author: PeonPing
  version: "1.0"
---

# peon-ping-rename

Give the current session a custom name shown in desktop notification titles and the terminal tab title.

## How it works

When the user types `/peon-ping-rename <name>`, a **UserPromptSubmit hook** intercepts the command before it reaches the model:

1. Extracts the session ID and name
2. Writes `session_names[session_id] = name` to `.state.json`
3. Immediately updates the terminal tab title via ANSI escape sequence
4. Returns confirmation (zero tokens used)

On every subsequent hook event, peon.sh reads `session_names[session_id]` as the highest-priority project name. Multiple tabs in the same repo each get independent names.

## Usage

```
/peon-ping-rename Auth Refactor
/peon-ping-rename API: payments
/peon-ping-rename          ← reset to auto-detect
```

Names are capped at 50 characters. Allowed: letters, numbers, spaces, dots, hyphens, underscores.

## Manual fallback (if hook fails)

### 1. Get the session ID

```bash
echo "$CLAUDE_SESSION_ID"
```

### 2. Write name to state

```bash
python3 -c "
import json, os, time
state_path = os.path.expanduser('~/.claude/hooks/peon-ping/.state.json')
try:
    state = json.load(open(state_path))
except:
    state = {}
state.setdefault('session_names', {})['SESSION_ID_HERE'] = 'My Session Name'
json.dump(state, open(state_path, 'w'), indent=2)
"
```

### 3. Trigger a hook event to refresh the tab title

Submit any prompt — peon.sh will pick up the new name on the next `UserPromptSubmit` or `Stop` event.

## Reset

```
/peon-ping-rename
```

Or remove the session ID from `session_names` in `.state.json` directly.

## Priority

`/peon-ping-rename` > `CLAUDE_SESSION_NAME` env var > `.peon-label` file > `notification_title_script` > `project_name_map` > `notification_title_override` > git repo name > folder name
