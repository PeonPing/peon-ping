#!/bin/bash
# peon-ping adapter for Kimi Code CLI (MoonshotAI)
# Translates Kimi Code hook events into peon.sh stdin JSON.
#
# Kimi Code ships a native hook system: `[[hooks]]` entries in
# ~/.kimi-code/config.toml run a shell command and deliver the event as JSON on
# stdin. The payload keys are snake_case (`hook_event_name`, `session_id`,
# `cwd`, `tool_name`, `tool_input`), which is already the shape peon.sh reads,
# so this adapter only has to prefix the session id, tag the source, and drop
# the events that would be noise.
#
# Docs: https://moonshotai.github.io/kimi-code/en/customization/hooks
#
# Setup:
#   bash adapters/kimi.sh --install     Register hooks in Kimi's config.toml
#   bash adapters/kimi.sh --uninstall   Remove them again
#   bash adapters/kimi.sh --status      Show whether hooks are registered
#
# --install and --uninstall also reap the watcher daemon this adapter used to
# be, so updating from v2.37.0 or earlier does not leave it running.
#
# Kimi treats a hook exit code of 2 as "block this operation" on UserPromptSubmit,
# PreToolUse and Stop, so every path here exits 0 and peon.sh's stdout is
# discarded. Terminal tab titles still work: peon.sh writes those to /dev/tty.

set -uo pipefail

if [ -n "${CLAUDE_PEON_DIR:-}" ]; then
  PEON_DIR="$CLAUDE_PEON_DIR"
else
  # adapters/ sits inside the install root, so an adapter copied into a
  # non-default one (--local, --kimi, a custom CLAUDE_CONFIG_DIR) can resolve it
  # from its own path instead of guessing ~/.claude. kimi.ps1 does the same.
  _self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  if [ -n "$_self_dir" ] && [ -f "$_self_dir/../peon.sh" ]; then
    PEON_DIR="$(cd "$_self_dir/.." && pwd)"
  else
    PEON_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping"
  fi
fi
PEON_SH="$PEON_DIR/peon.sh"

# Kimi Code lives in ~/.kimi-code. ~/.kimi is the older kimi-cli; prefer the
# former and fall back so an existing kimi-cli install keeps working.
if [ -n "${KIMI_DIR:-}" ]; then
  :
elif [ -f "$HOME/.kimi-code/config.toml" ]; then
  KIMI_DIR="$HOME/.kimi-code"
elif [ -f "$HOME/.kimi/config.toml" ]; then
  KIMI_DIR="$HOME/.kimi"
elif [ ! -d "$HOME/.kimi-code" ] && [ -d "$HOME/.kimi" ]; then
  # Neither home holds a config yet. An existing kimi-cli one still beats
  # creating a Kimi Code config that nothing on this machine reads. Matches how
  # install.sh picks the install root.
  KIMI_DIR="$HOME/.kimi"
else
  KIMI_DIR="$HOME/.kimi-code"
fi
KIMI_CONFIG="${KIMI_CONFIG:-$KIMI_DIR/config.toml}"

BEGIN_MARKER="# peon-ping Kimi hooks begin"
END_MARKER="# peon-ping Kimi hooks end"

# Leftovers from the watcher daemon this adapter replaced. See
# stop_legacy_watcher below.
LEGACY_PIDFILE="$PEON_DIR/.kimi-adapter.pid"
LEGACY_LOGFILE="$PEON_DIR/.kimi-adapter.log"
LEGACY_LAUNCHD_LABEL="com.peonping.kimi-adapter"
LEGACY_LAUNCHD_PLIST="$HOME/Library/LaunchAgents/${LEGACY_LAUNCHD_LABEL}.plist"

# Events peon-ping registers, out of the sixteen in Kimi's HOOK_EVENT_TYPES.
# PreToolUse/PostToolUse fire on every tool call, PostCompact duplicates
# PreCompact, and Interrupt/Notification have no CESP category, so those five
# stay unregistered. PermissionResult is registered but silent: it maps to
# PreToolUse so the tab title stops saying "needs approval" once the prompt is
# answered.
HOOK_EVENTS=(
  SessionStart
  SessionEnd
  UserPromptSubmit
  Stop
  StopFailure
  PermissionRequest
  PermissionResult
  PostToolUseFailure
  SubagentStart
  SubagentStop
  PreCompact
)

BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'
info()  { printf "%s>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s!%s %s\n" "$YELLOW" "$RESET" "$*"; }
error() { printf "%sx%s %s\n" "$RED" "$RESET" "$*" >&2; }

stop_legacy_watcher() {
  # Up to v2.37.0 this adapter was a filesystem watcher daemon. An update only
  # replaces the script on disk, so the old daemon survives it and keeps piping
  # its own events to peon.sh -- every sound twice once the hooks are live. The
  # macOS LaunchAgent is worse: it has KeepAlive=true and runs this script with
  # no arguments, which is now hook mode, so it reads an empty stdin, exits 0,
  # and launchd restarts it every ten seconds forever. Reap both.
  local found=0

  if [ -f "$LEGACY_LAUNCHD_PLIST" ]; then
    if command -v launchctl >/dev/null 2>&1; then
      launchctl unload "$LEGACY_LAUNCHD_PLIST" 2>/dev/null || true
    fi
    rm -f "$LEGACY_LAUNCHD_PLIST"
    found=1
  fi

  if [ -f "$LEGACY_PIDFILE" ]; then
    local pid args
    pid="$(tr -dc '0-9' < "$LEGACY_PIDFILE" 2>/dev/null)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      # A pid outlives the process that wrote it, so only kill one that still
      # looks like the watcher rather than whatever inherited the number.
      args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
      case "$args" in
        *kimi*)
          pkill -P "$pid" 2>/dev/null || true
          kill "$pid" 2>/dev/null || true
          found=1
          ;;
      esac
    fi
    rm -f "$LEGACY_PIDFILE"
  fi

  rm -f "$LEGACY_LOGFILE"

  if [ "$found" = 1 ]; then
    info "Stopped the old Kimi watcher daemon (native hooks replace it)"
  fi
  return 0
}

self_path() {
  local src="${BASH_SOURCE[0]}"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$src" 2>/dev/null && return
  fi
  (cd "$(dirname "$src")" 2>/dev/null && printf '%s/%s\n' "$PWD" "$(basename "$src")")
}

sh_quote() {
  # Kimi spawns the hook with Node's `shell: true`, i.e. `sh -c "<command>"`, so
  # a path with a space in it has to reach the shell already quoted.
  local escaped="${1//\'/\'\\\'\'}"
  printf "'%s'" "$escaped"
}

toml_basic() {
  local escaped="${1//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  printf '"%s"' "$escaped"
}

strip_block() {
  # Remove a previously installed block, marker lines included. --install writes
  # exactly one blank separator line ahead of the marker, so take that one back
  # too -- and only that one, or --uninstall would eat a blank line the config
  # already had. Blank lines are therefore buffered rather than printed as seen.
  local file="$1"
  [ -f "$file" ] || return 0
  awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
    index($0, b) == 1 {
      if (blanks > 0) blanks--
      for (i = 0; i < blanks; i++) print ""
      blanks = 0
      skip = 1
      next
    }
    index($0, e) == 1 { skip = 0; next }
    skip { next }
    /^[[:space:]]*$/ { blanks++; next }
    { for (i = 0; i < blanks; i++) print ""; blanks = 0; print }
    END { for (i = 0; i < blanks; i++) print "" }
  ' "$file"
}

case "${1:-}" in
  --help|-h)
    cat <<EOF
Usage: bash kimi.sh [--install|--uninstall|--status]

  --install      Register peon-ping hooks in $KIMI_CONFIG
  --uninstall    Remove them
  --status       Report whether they are registered
  (no args)      Hook mode: read one Kimi event as JSON on stdin and forward it
EOF
    exit 0
    ;;

  --status)
    if [ -f "$KIMI_CONFIG" ] && grep -qF "$BEGIN_MARKER" "$KIMI_CONFIG"; then
      count=$(awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
        index($0, b) == 1 { inblock = 1; next }
        index($0, e) == 1 { inblock = 0; next }
        inblock && /^event = / { n++ }
        END { print n + 0 }
      ' "$KIMI_CONFIG")
      info "peon-ping hooks registered in $KIMI_CONFIG ($count events)"
      exit 0
    fi
    warn "peon-ping hooks not registered in $KIMI_CONFIG"
    exit 1
    ;;

  --uninstall)
    stop_legacy_watcher
    if [ ! -f "$KIMI_CONFIG" ]; then
      info "Nothing to remove ($KIMI_CONFIG does not exist)."
      exit 0
    fi
    if ! grep -qF "$BEGIN_MARKER" "$KIMI_CONFIG"; then
      info "Nothing to remove (no peon-ping block found)."
      exit 0
    fi
    tmp="$(mktemp)"
    strip_block "$KIMI_CONFIG" > "$tmp" && mv "$tmp" "$KIMI_CONFIG"
    info "Removed peon-ping hooks from $KIMI_CONFIG"
    exit 0
    ;;

  --install)
    [ -f "$PEON_SH" ] || { error "peon.sh not found at $PEON_SH"; exit 1; }
    stop_legacy_watcher
    mkdir -p "$KIMI_DIR"
    [ -f "$KIMI_CONFIG" ] || : > "$KIMI_CONFIG"

    ADAPTER="$(self_path)"
    HOOK_COMMAND="CLAUDE_PEON_DIR=$(sh_quote "$PEON_DIR") bash $(sh_quote "$ADAPTER")"
    tmp="$(mktemp)"
    # Rewriting from scratch keeps --install idempotent.
    strip_block "$KIMI_CONFIG" > "$tmp"
    {
      # Separate the block from existing content, but do not open an empty
      # config with a blank line.
      [ -s "$tmp" ] && printf '\n'
      printf '%s\n' "$BEGIN_MARKER"
      printf '# install_dir = %s\n' "$PEON_DIR"
      for ev in "${HOOK_EVENTS[@]}"; do
        printf '\n[[hooks]]\n'
        printf 'event = "%s"\n' "$ev"
        printf 'command = %s\n' "$(toml_basic "$HOOK_COMMAND")"
        printf 'timeout = 10\n'
      done
      printf '\n%s\n' "$END_MARKER"
    } >> "$tmp"
    mv "$tmp" "$KIMI_CONFIG"

    info "${BOLD}peon-ping hooks registered for Kimi Code${RESET}"
    printf "  %sconfig:%s  %s\n" "$DIM" "$RESET" "$KIMI_CONFIG"
    printf "  %sadapter:%s %s\n" "$DIM" "$RESET" "$ADAPTER"
    printf "  %sevents:%s  %s\n" "$DIM" "$RESET" "${HOOK_EVENTS[*]}"
    echo ""
    info "Run 'kimi doctor' to validate, then restart Kimi Code."
    exit 0
    ;;

  "")
    ;;

  *)
    error "Unknown option: $1"
    exit 1
    ;;
esac

# --- Hook mode ---------------------------------------------------------------

[ -f "$PEON_SH" ] || exit 0
[ -t 0 ] && exit 0

KIMI_STDIN="$(cat)"

MAPPED_JSON="$(_KIMI_STDIN="$KIMI_STDIN" python3 - <<'PY'
import json
import os
import re
import sys

raw = os.environ.get("_KIMI_STDIN", "").strip()
if not raw:
    sys.exit(0)
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)

event = str(data.get("hook_event_name", "")).strip()

# The five events --install leaves out. Dropped here too, in case someone wired
# them by hand.
DROP = {
    "PreToolUse",
    "PostToolUse",
    "PostCompact",
    "Interrupt",
    "Notification",
}
PASS = {
    "SessionStart",
    "SessionEnd",
    "UserPromptSubmit",
    "Stop",
    "PermissionRequest",
    "PostToolUseFailure",
    "SubagentStart",
    "SubagentStop",
    "PreCompact",
}

if event in DROP or not event:
    sys.exit(0)
elif event in PASS:
    mapped = event
elif event == "StopFailure":
    # The turn itself failed. peon.sh has no separate category, so borrow the
    # tool-failure path, which sounds task.error.
    mapped = "PostToolUseFailure"
elif event == "PermissionResult":
    # Silent in peon.sh: only clears the "needs approval" tab title.
    mapped = "PreToolUse"
else:
    sys.exit(0)

raw_session = str(data.get("session_id", "") or "")
# Kimi ids look like "session_<uuid>"; peon.sh infers the IDE from the
# session_id prefix, so it has to start with "kimi-".
raw_session = re.sub(r"^session[_-]", "", raw_session)
safe_session = re.sub(r"[^A-Za-z0-9._:-]", "-", raw_session).strip("-")
if not safe_session:
    safe_session = str(os.getpid())

payload = {
    "hook_event_name": mapped,
    "notification_type": "",
    "cwd": str(data.get("cwd", "") or os.environ.get("PWD", "") or "/"),
    "session_id": "kimi-" + safe_session,
    "permission_mode": str(data.get("permission_mode", "") or ""),
    "source": "kimi",
}

def error_text(value):
    # PostToolUseFailure carries `error` as an object -- Kimi 0.41 sends
    # { code, message, retryable } -- so pull the message out rather than
    # stringifying the whole dict. The text reaches a notification and a tab
    # title, so collapse its whitespace.
    if value is None:
        return ""
    if isinstance(value, dict):
        value = value.get("message", "")
    return " ".join(str(value).split())


tool_name = str(data.get("tool_name", "") or "")
if tool_name:
    payload["tool_name"] = tool_name[:64]

if mapped == "PostToolUseFailure":
    # peon.sh only sounds task.error for a Bash failure carrying error text.
    # StopFailure has no tool at all and is attributed to Bash the way codex.sh
    # does it.
    if not payload.get("tool_name"):
        payload["tool_name"] = "Bash"
    err = error_text(data.get("error")) or error_text(data.get("message"))
    if not err:
        err = "%s failed" % (payload["tool_name"] if event != "StopFailure" else "turn")
    payload["error"] = err[:180]

title = str(data.get("session_title", "") or "")
if title:
    payload["transcript_summary"] = title[:120]

print(json.dumps(payload))
PY
)" || MAPPED_JSON=""

if [ -n "$MAPPED_JSON" ]; then
  # stdout is swallowed: Kimi parses a hook's stdout as a decision document.
  printf '%s' "$MAPPED_JSON" | bash "$PEON_SH" >/dev/null 2>&1 || true
fi

exit 0
