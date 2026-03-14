---
name: peon-ping-use
description: Set which voice pack (character voice) plays for the current chat session. Automatically enables session_override rotation mode if not already set. Use when user wants a specific character voice like GLaDOS, Peon, or Kerrigan for this conversation.
user_invocable: true
license: MIT
metadata:
  author: PeonPing
  version: "1.0"
---

# peon-ping-use

Set which voice pack (character voice) plays for the current chat session.

## How it works

When the user types `/peon-ping-use <packname>`, a **beforeSubmitPrompt hook** intercepts the command before it reaches the model and handles it instantly:

1. Validates the requested pack exists
2. Enables `session_override` rotation mode in config.json
3. Maps the current session ID to the requested pack in .state.json
4. Returns immediate confirmation (zero tokens used)

When the hook blocks the message, Cursor keeps your cursor in the input field so you can type your next message right away.

The hook scripts (`scripts/hook-handle-use.sh` and `scripts/hook-handle-use.ps1`) do all the work - this SKILL.md file exists solely for discoverability in the `/` command autocomplete menu.

## Usage

Users can invoke this by typing:

```
/peon-ping-use peasant
/peon-ping-use glados
/peon-ping-use sc_kerrigan
```

If the hook is not installed or fails, you can fallback to manual execution by following the instructions below.

## Manual fallback (if hook fails)

If for some reason the hook doesn't intercept the command, follow these steps:

### 1. Parse the pack name

Extract the pack name from the user's request. Common pack names:
- `peon` — Warcraft Peon
- `glados` — Portal's GLaDOS
- `sc_kerrigan` — StarCraft Kerrigan
- `peasant` — Warcraft Peasant
- `hk47` — Star Wars HK-47

### 2. List available packs

Run this command to see installed packs:

```bash
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/peon.sh packs list
```

Parse the output to verify the requested pack exists.

### 3. Get session ID

The session ID is available in the environment variable `CLAUDE_SESSION_ID`. Read it:

```bash
echo "$CLAUDE_SESSION_ID"
```

**If empty (Cursor users):** Use `"default"` as the key in `session_packs`. This applies the pack to all sessions without explicit assignment. Add `session_packs["default"] = {"pack": "PACK_NAME", "last_used": UNIX_TIMESTAMP}`.

### 4. Update config to enable session_override mode

Read the config file:

```bash
cat "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/config.json
```

**Required:** Set `pack_rotation_mode` to `"session_override"`. The pack must exist in the packs directory; if the assigned pack is missing or invalid, peon-ping falls back to `default_pack` and removes the stale assignment. The hook also adds the pack to `pack_rotation` (manual fallback can do the same).

Example config after setup:

```json
"pack_rotation_mode": "session_override",
"pack_rotation": ["peasant", "peon", "ra2_kirov"]
```

If `pack_rotation_mode` is `"random"` or `"round-robin"`, change it to `"session_override"`. If the requested pack is not in `pack_rotation`, add it.

### 5. Update state to assign pack to this session

Read the state file:

```bash
cat "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/.state.json
```

Update the `session_packs` object to map this session to the requested pack. If `session_packs` doesn't exist, create it:

```json
{
  "session_packs": {
    "SESSION_ID_HERE": "pack_name_here"
  }
}
```

Use StrReplace or edit the JSON to add/update the entry:

- If `session_packs` exists: add or update the session ID key
- If `session_packs` doesn't exist: add it after the opening brace

### 6. Confirm to user

Report success with a message like:

```
Voice set to [PACK_NAME] for this session
   Rotation mode: session_override
```

## Error handling

- **Pack not found**: List available packs and ask user to choose one
- **No session ID**: Inform user this feature requires Claude Code
- **File read/write errors**: Report the error and suggest manual config editing

## Example interaction

```
User: Use GLaDOS voice for this chat
Assistant: [Lists packs to verify glados exists]
Assistant: [Gets session ID]
Assistant: [Updates config.json to set pack_rotation_mode: "session_override"]
Assistant: [Updates .state.json to set session_packs[session_id] = "glados"]
Assistant: Voice set to GLaDOS for this session
           Rotation mode: session_override
```

## Cursor compatibility note

Cursor doesn't expose session IDs. Use `session_packs["default"]` instead: when doing the manual fallback, add `"default": {"pack": "peasant", "last_used": 0}` to `session_packs`. This applies the voice to sessions without explicit assignment (including Cursor chats).

## Reset to default

To stop using a specific pack for this session, remove the session ID from `session_packs` in `.state.json`, or change `pack_rotation_mode` back to `"random"` or `"round-robin"`.
