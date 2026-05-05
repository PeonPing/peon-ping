#!/bin/bash
# copyright (c) 2026 Atlassian US, Inc.
# peon-ping adapter for Rovo Dev CLI (Atlassian)
# Translates Rovo Dev event hook names into peon.sh stdin JSON
#
# Rovo Dev CLI fires shell commands on agent lifecycle events.
# The event name is passed as a CLI argument ($1), and the full JSON payload
# is piped to stdin (same pattern as Claude Code / Kiro hooks).
#
# Setup: Add to ~/.rovodev/config.yml:
#
#   eventHooks:
#     events:
#       - name: on_user_prompt
#         commands:
#           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_user_prompt
#       - name: on_tool_start
#         commands:
#           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_tool_start
#       - name: on_tool_end
#         commands:
#           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_tool_end
#       - name: on_complete
#         commands:
#           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_complete
#       - name: on_error
#         commands:
#           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_error
#       - name: on_tool_permission
#         commands:
#           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_tool_permission
#       - name: on_session_start
#         commands:
#           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_session_start
#       - name: on_session_end
#         commands:
#           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_session_end
#
# Note: Use absolute paths if ~ is not expanded in your environment.

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
[ -d "$PEON_DIR" ] || PEON_DIR="$HOME/.openpeon"

if [ ! -f "$PEON_DIR/peon.sh" ]; then
  echo "peon-ping not installed. Run: brew install PeonPing/tap/peon-ping" >&2
  exit 1
fi

# Read the JSON payload from stdin (provided by Rovo Dev CLI for all events).
# Note: contrary to the original adapter comment above, Rovo Dev DOES pipe the
# JSON payload to the hook command's stdin (confirmed by the on_complete payload shape).
[ "${PEON_DEBUG:-0}" = "1" ] && echo "[rovodev] script started event=${1:-?}" >&2
if command -v timeout >/dev/null 2>&1; then
  input=$(timeout 2 cat 2>/dev/null) || input=""
elif command -v gtimeout >/dev/null 2>&1; then
  input=$(gtimeout 2 cat 2>/dev/null) || input=""
else
  input=$(cat)
fi
[ "${PEON_DEBUG:-0}" = "1" ] && echo "[rovodev] input=${input:0:200}" >&2
# Dump hook payloads to timestamped files for debugging/replay.
# Enable by setting PEON_DUMP=1 in the hook command or environment.
# Files are written to PEON_DUMP_DIR (default: /tmp/rovodev-dumps).
if [ "${PEON_DUMP:-0}" = "1" ]; then
  _dump_dir="${PEON_DUMP_DIR:-/tmp/rovodev-dumps}"
  mkdir -p "$_dump_dir"
  _dump_ts="$(date +%Y%m%d-%H%M%S)-${1:-event}"
  printf '%s\n' "$input" > "$_dump_dir/$_dump_ts.json"
fi

# Eagerly read the transcript file before any other processing.
# Rovo Dev runs hooks in a fire-and-forget async process and deletes the
# transcript file as soon as the hook command exits — so we must read it
# immediately while it still exists, before doing event mapping or anything else.
_transcript_content=""
if command -v jq &>/dev/null; then
  _tp=$(echo "$input" | jq -r '.transcript_path // .attributes.transcript_path // empty' 2>/dev/null || true)
  [ "${PEON_DEBUG:-0}" = "1" ] && echo "[rovodev] transcript_path='$_tp' file_exists=$([ -f "$_tp" ] && echo yes || echo no)" >&2
  if [ -n "$_tp" ] && [ -f "$_tp" ]; then
    _transcript_content=$(cat "$_tp" 2>/dev/null || true)
    [ "${PEON_DEBUG:-0}" = "1" ] && echo "[rovodev] transcript read: ${#_transcript_content} bytes" >&2
    # Dump transcript content while it's still in memory
    if [ "${PEON_DUMP:-0}" = "1" ] && [ -n "$_transcript_content" ]; then
      _dump_dir="${PEON_DUMP_DIR:-/tmp/rovodev-dumps}"
      _dump_ts_t="$(date +%Y%m%d-%H%M%S)-${1:-event}"
      printf '%s\n' "$_transcript_content" > "$_dump_dir/$_dump_ts_t.transcript.json"
    fi
  fi
fi

RD_EVENT="${1:-on_complete}"

# Map Rovo Dev CLI event names to peon.sh hook events
case "$RD_EVENT" in
  on_user_prompt)
    EVENT="UserPromptSubmit"
    ;;
  on_tool_start)
    EVENT="PreToolUse"
    ;;
  on_tool_end)
    EVENT="PostToolUse"
    ;;
  on_complete)
    EVENT="Stop"
    ;;
  on_error)
    EVENT="PostToolUseFailure"
    ;;
  on_tool_permission|on_permission_request)
    EVENT="PermissionRequest"
    ;;
  on_session_start)
    EVENT="SessionStart"
    ;;
  on_session_end)
    EVENT="SessionEnd"
    ;;
  *)
    # Unknown event — exit silently
    exit 0
    ;;
esac

SESSION_ID="rovodev-${ROVODEV_SESSION_ID:-$$}"

# Build JSON and pipe to peon.sh
# peon.sh reads tool_name/error at the top level, so they must not be nested
TOOL_NAME=""
ERROR_MSG=""
TRANSCRIPT_SUMMARY=""
[ "$EVENT" = "PostToolUseFailure" ] && TOOL_NAME="Bash" && ERROR_MSG="Agent error"

# For permission requests, extract tool_name and args from the stdin payload.
# Rovo Dev nests them under attributes.tool_input.
# Build a short description from the args to use as transcript_summary so the
# notification body shows something useful (e.g. "command: ls -la") rather than
# the generic "Requires permissions" fallback.
# For permission requests, use Python (not jq) to parse the payload since bash
# commands may contain raw newlines that make the JSON invalid for jq.
# Extracts tool_name + builds a human-readable summary from the args.
if [ "$EVENT" = "PermissionRequest" ] && command -v python3 &>/dev/null; then
  _perm_result=$(echo "$input" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    ti = d.get('attributes', {}).get('tool_input', {}) or {}
    tool = ti.get('tool_name') or 'bash'
    args = ti.get('args', {}) or {}
    if tool.lower() == 'bash':
        cmd = (args.get('command') or args.get('cmd') or args.get('input') or '').replace('\n', '; ').strip()
        if cmd:
            detail = 'Permission requested (' + cmd + ')'
        else:
            intent = args.get('_intent', '')
            detail = 'Permission requested (bash)' + (' \u2014 ' + intent if intent else '')
    else:
        intent = args.get('_intent', '')
        detail = 'Permission requested (' + tool + ')'
        if intent:
            detail += ' \u2014 ' + intent
    # Output tool_name on first line, detail on second line
    print(tool)
    print(detail)
except Exception:
    pass
" 2>/dev/null || true)
  if [ -n "$_perm_result" ]; then
    _perm_tool=$(printf '%s' "$_perm_result" | head -1)
    _perm_detail=$(printf '%s' "$_perm_result" | tail -n +2)
    [ -n "$_perm_tool" ] && TOOL_NAME="$_perm_tool"
    if [ -n "$_perm_detail" ]; then
      TRANSCRIPT_SUMMARY=$(printf '%s' "$_perm_detail" | tr -s ' \n' ' ' | cut -c1-120)
      TRANSCRIPT_SUMMARY="${TRANSCRIPT_SUMMARY%"${TRANSCRIPT_SUMMARY##*[![:space:]]}"}"
    fi
  fi
fi

# For on_complete, extract the last agent response text from the in-memory
# transcript content (eagerly read above before the file could be deleted),
# strip markdown, and truncate to 120 chars. Permission requests keep their
# permission-specific summary so notifications show the requested action.
if [ "$EVENT" = "Stop" ] && [ -n "$_transcript_content" ] && command -v jq &>/dev/null; then
  raw_response=$(echo "$_transcript_content" | jq -r '
    .message_history
    | map(select(.kind == "response"))
    | last
    | .parts
    | map(select(.part_kind == "text"))
    | last
    | .content
  ' 2>/dev/null || true)
  # Treat jq "null" output as empty
  [ "$raw_response" = "null" ] && raw_response=""
  [ "${PEON_DEBUG:-0}" = "1" ] && echo "[rovodev] raw_response='${raw_response:0:80}'" >&2
  if [ -n "$raw_response" ]; then
    # Strip common markdown: headers, bold/italic, inline code, links, images
    TRANSCRIPT_SUMMARY=$(printf '%s' "$raw_response" \
      | sed -E \
          -e 's/^[[:space:]]*#{1,6}[[:space:]]*//' \
          -e 's/!\[[^]]*\]\([^)]*\)//g' \
          -e 's/\[[^]]*\]\([^)]*\)//g' \
          -e 's/`([^`]*)`/\1/g' \
          -e 's/\*\*([^*]*)\*\*/\1/g' \
          -e 's/__([^_]*)__/\1/g' \
          -e 's/\*([^*]*)\*/\1/g' \
          -e 's/_([^_]*)_/\1/g' \
          -e 's/^[[:space:]]*[-*+][[:space:]]*//' \
          -e 's/^[[:space:]]*//' \
      | tr -s ' \n' ' ' \
      | cut -c1-120)
    TRANSCRIPT_SUMMARY="${TRANSCRIPT_SUMMARY%"${TRANSCRIPT_SUMMARY##*[![:space:]]}"}"
  fi
fi

if command -v jq &>/dev/null; then
  jq -nc \
    --arg hook "$EVENT" \
    --arg cwd "$PWD" \
    --arg sid "$SESSION_ID" \
    --arg tn "$TOOL_NAME" \
    --arg err "$ERROR_MSG" \
    --arg summary "$TRANSCRIPT_SUMMARY" \
    '{hook_event_name:$hook, cwd:$cwd, session_id:$sid, permission_mode:"", source:"rovodev", tool_name:$tn, error:$err, transcript_summary:$summary}'
else
  printf '{"hook_event_name":"%s","cwd":"%s","session_id":"%s","permission_mode":"","source":"rovodev","tool_name":"%s","error":"%s","transcript_summary":"%s"}\n' \
    "$EVENT" "$PWD" "$SESSION_ID" "$TOOL_NAME" "$ERROR_MSG" "$TRANSCRIPT_SUMMARY"
fi | bash "$PEON_DIR/peon.sh"
