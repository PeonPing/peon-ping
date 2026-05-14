#!/bin/bash
# peon-ping adapter for GitHub Copilot CLI
# Translates GitHub Copilot CLI hook events into peon.sh stdin JSON.
#
# This adapter is mainly for users wiring per-repository hooks via
# .github/hooks/hooks.json. For user-level (global) wiring, install.sh
# now writes ~/.copilot/hooks/peon-ping.json directly with PascalCase
# event names that peon.sh reads natively (no adapter required).
#
# Setup (per-repo): see README "GitHub Copilot CLI setup" for the full hook list.

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
PEON_SCRIPT="$PEON_DIR/peon.sh"
[ -f "$PEON_SCRIPT" ] || exit 0

COPILOT_EVENT="${1:-sessionStart}"

# Map Copilot CLI camelCase events to peon.sh PascalCase events.
# - postToolUse: no mapping (peon.sh has no PostToolUse handler; mapping
#   it to Stop floods the 5s debounce window and swallows real Stop events)
# - agentStop: correct "task done" signal (Copilot CLI only)
# - errorOccurred: generic Copilot CLI error -> PostToolUseFailure
case "$COPILOT_EVENT" in
  sessionStart)        EVENT="SessionStart" ;;
  sessionEnd)          EVENT="SessionEnd" ;;
  userPromptSubmitted) EVENT="UserPromptSubmit" ;;
  preToolUse)          EVENT="PreToolUse" ;;
  postToolUseFailure)  EVENT="PostToolUseFailure" ;;
  agentStop)           EVENT="Stop" ;;
  subagentStart)       EVENT="SubagentStart" ;;
  subagentStop)        EVENT="SubagentStop" ;;
  notification)        EVENT="Notification" ;;
  permissionRequest)   EVENT="PermissionRequest" ;;
  preCompact)          EVENT="PreCompact" ;;
  errorOccurred)       EVENT="PostToolUseFailure" ;;
  *)                   exit 0 ;;  # unknown or intentionally skipped (e.g. postToolUse)
esac

# Read camelCase JSON from stdin (may be empty)
INPUT=$(cat 2>/dev/null || echo "")
[ -z "$INPUT" ] && INPUT="{}"

# Translate camelCase -> snake_case fields, inject hook_event_name + source.
# Field mapping is per-event because not all events carry the same fields.
echo "$INPUT" | jq \
  --arg event "$EVENT" \
  --arg sid_default "copilot-$$" \
  --arg cwd_default "$PWD" \
  '
  . as $in
  | {
      hook_event_name: $event,
      session_id:      ($in.sessionId // $sid_default),
      cwd:             ($in.cwd // $cwd_default),
      source:          "copilot"
    }
  + (
      if $event == "SessionStart" then
        (if $in.source         then {source: $in.source}                 else {} end)
        + (if $in.initialPrompt  then {initial_prompt: $in.initialPrompt}  else {} end)
      elif $event == "SessionEnd" then
        (if $in.reason then {reason: $in.reason} else {} end)
      elif $event == "UserPromptSubmit" then
        (if $in.prompt then {prompt: $in.prompt} else {} end)
      elif $event == "PreToolUse" then
        (if $in.toolName        then {tool_name: $in.toolName}  else {} end)
        + (if $in.toolArgs != null then {tool_input: $in.toolArgs} else {} end)
      elif $event == "PostToolUseFailure" then
        {
          tool_name: ($in.toolName // "unknown"),
          error:     ($in.error // "errorOccurred")
        }
        + (if $in.toolArgs != null then {tool_input: $in.toolArgs} else {} end)
      elif $event == "Stop" then
        (if $in.transcriptPath then {transcript_path: $in.transcriptPath} else {} end)
        + (if $in.stopReason   then {stop_reason: $in.stopReason}         else {} end)
      elif $event == "SubagentStart" then
        (if $in.transcriptPath then {transcript_path: $in.transcriptPath} else {} end)
        + (if $in.agentName    then {agent_name: $in.agentName}           else {} end)
      elif $event == "SubagentStop" then
        (if $in.transcriptPath then {transcript_path: $in.transcriptPath} else {} end)
      elif $event == "Notification" then
        (if $in.notificationType then {notification_type: $in.notificationType} else {} end)
        + (if $in.message          then {message: $in.message}                     else {} end)
      elif $event == "PermissionRequest" then
        (if $in.toolName        then {tool_name: $in.toolName}  else {} end)
        + (if $in.toolArgs != null then {tool_input: $in.toolArgs} else {} end)
      elif $event == "PreCompact" then
        (if $in.trigger then {trigger: $in.trigger} else {} end)
      else {} end
    )
  ' | bash "$PEON_SCRIPT"
