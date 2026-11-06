---
standard: "https://hypercontext.wiki/standards/hdsop/v2"
title: "Set the voice pack for the current chat session"
id: peon-ping-use
version: 0.1
skill: peon-ping-use
doc_status: drafting
tags: [peon-ping, voice-packs, session]
frequency: "unknown"
est_time_per_run: "unknown"
automation_potential: "unknown"
related_skills: []
related_workflows: []
concepts: []
---

# Purpose
The user picks a character voice, such as GLaDOS, Peon or Kerrigan, and that voice plays for the current chat session. Rotation switches to session_override mode if it is not already set. Without it, the voice follows the global rotation.

# When to use (Trigger)
The user types /peon-ping-use <packname>, or asks for a specific character voice for this conversation. A beforeSubmitPrompt hook usually intercepts the command before it reaches the model, so the skill file exists mainly for discoverability in the autocomplete menu. The manual steps run only if the hook is not installed or fails.

# Inputs / Prerequisites
- A pack name such as `peasant`, `glados`, `sc_kerrigan`, `peon` or `hk47`.
- peon-ping installed, with `peon.sh`, `config.json` and `.state.json` under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping/`.
- The session ID in `CLAUDE_SESSION_ID`. Cursor does not expose one, so the key `"default"` is used there.

# Roles
| Role | Responsibility |
|---|---|
| **Human operator** | Names the pack. |
| **Hook script** | `scripts/hook-handle-use.sh` or `scripts/hook-handle-use.ps1` handles the command with zero model tokens. |
| **Agent executor** | Runs the manual fallback if the hook does not. |

# Procedure

Steps say WHAT happens and who does it. The map is drawn from the block below.

```json steps
{
  "ends": [
    {
      "id": "voice-set",
      "what": "The pack is mapped to this session and the user has the confirmation."
    },
    {
      "id": "no-session-id",
      "what": "There is no session ID and the user has been told the feature needs Claude Code."
    }
  ],
  "steps": [
    {
      "id": "hook-handles-command",
      "what": "The hook validates the pack, enables session_override rotation mode in config.json, maps the session ID to the pack in .state.json, and returns the confirmation at once.",
      "actor": "script:hook-handle-use.sh",
      "outcomes": [
        {
          "when": "the hook handled it",
          "then": "voice-set"
        },
        {
          "when": "the hook is missing or fails",
          "then": "parse-pack-name"
        }
      ]
    },
    {
      "id": "parse-pack-name",
      "what": "Take the pack name from the user's request.",
      "actor": "agent",
      "after": [
        "hook-handles-command"
      ]
    },
    {
      "id": "list-packs",
      "what": "Run bash \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}\"/hooks/peon-ping/peon.sh packs list and confirm the pack exists. If it does not, list the available packs and ask the user to choose.",
      "actor": "agent",
      "after": [
        "parse-pack-name"
      ]
    },
    {
      "id": "get-session-id",
      "what": "Read CLAUDE_SESSION_ID. On Cursor it is empty, so use \"default\" as the key in session_packs.",
      "actor": "agent",
      "after": [
        "list-packs"
      ],
      "outcomes": [
        {
          "when": "no session ID and not Cursor",
          "do": "tell the user this feature requires Claude Code",
          "then": "no-session-id"
        },
        {
          "when": "an ID or the default key",
          "then": "set-rotation-mode"
        }
      ]
    },
    {
      "id": "set-rotation-mode",
      "what": "Read config.json. Set pack_rotation_mode to \"session_override\", changing it from \"random\" or \"round-robin\" if needed. Add the pack to pack_rotation if it is missing.",
      "actor": "agent",
      "after": [
        "get-session-id"
      ]
    },
    {
      "id": "assign-pack-to-session",
      "what": "Read .state.json and set session_packs[<session id>] to the pack. Create session_packs if it does not exist.",
      "actor": "agent",
      "after": [
        "set-rotation-mode"
      ]
    },
    {
      "id": "confirm-to-user",
      "what": "Report success, for example \"Voice set to [PACK_NAME] for this session\" and \"Rotation mode: session_override\".",
      "actor": "agent",
      "after": [
        "assign-pack-to-session"
      ],
      "outcomes": [
        {
          "when": "confirmed",
          "then": "voice-set"
        }
      ]
    }
  ]
}
```

# Done / Verification
- `config.json` has `pack_rotation_mode` set to `session_override`.
- `.state.json` maps this session (or `default`) to the pack.
- The user has the confirmation message.

# Exceptions & Troubleshooting
- **Pack not found.** List the available packs and ask the user to choose one.
- **Assigned pack is missing or invalid later.** peon-ping falls back to `default_pack` and removes the stale assignment.
- **No session ID.** Tell the user the feature requires Claude Code. On Cursor, use the `default` key.
- **File read or write error.** Report the error and suggest editing the config by hand.
- **Reset to default.** Remove the session ID from `session_packs` in `.state.json`, or set `pack_rotation_mode` back to `random` or `round-robin`.

# Automation Opportunities
- unknown. The skill does not list any.

# Related
- unknown. The skill names no related skills.

# Revision History
| Version | Date | Changes |
|---|---|---|
| 0.1 | 2026-11-06T21:51:00Z | First map, drafted from SKILL.md. |
