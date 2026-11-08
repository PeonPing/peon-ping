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
# Appended to the begin marker when --install had to terminate the config's last
# line before it could add the block, so --uninstall knows to take that newline
# back. Without it "a" and "a\n" install to the same bytes.
EOF_NOTE="(newline added at end of file)"

# Leftovers from the watcher daemon this adapter replaced. See
# stop_legacy_watcher below.
LEGACY_PIDFILE="$PEON_DIR/.kimi-adapter.pid"
LEGACY_LOGFILE="$PEON_DIR/.kimi-adapter.log"
LEGACY_LAUNCHD_LABEL="com.peonping.kimi-adapter"
LEGACY_LAUNCHD_PLIST="$HOME/Library/LaunchAgents/${LEGACY_LAUNCHD_LABEL}.plist"

# Events peon-ping registers, out of the sixteen in Kimi Code's
# HOOK_EVENT_TYPES. PreToolUse/PostToolUse fire on every tool call, PostCompact
# duplicates PreCompact, and Interrupt/Notification have no CESP category, so
# those five stay unregistered. PermissionResult is registered but silent: it
# maps to PreToolUse so the tab title stops saying "needs approval" once the
# prompt is answered.
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

# The older kimi-cli (~/.kimi) has hooks from 1.28.0 on, but its schema has
# thirteen events and none of these. It validates `event` against that list
# and refuses to load a config.toml naming any other, so registering them
# would stop kimi-cli from starting at all. Only Kimi Code's own home is known
# to take the full list; every other config gets the events both accept.
# Kimi Code can also be moved off ~/.kimi-code with KIMI_CODE_HOME.
KIMI_CODE_ONLY_EVENTS=(PermissionRequest PermissionResult)
KIMI_CONFIG_DIR="$(dirname "$KIMI_CONFIG")"
if [ "$(basename "$KIMI_CONFIG_DIR")" = .kimi-code ] ||
   { [ -n "${KIMI_CODE_HOME:-}" ] &&
     { [ "$KIMI_CONFIG_DIR" = "$KIMI_CODE_HOME" ] || [ "$KIMI_CONFIG_DIR" -ef "$KIMI_CODE_HOME" ]; }; }; then
  KIMI_TARGET="Kimi Code"
  REGISTER_EVENTS=("${HOOK_EVENTS[@]}")
else
  KIMI_TARGET="kimi-cli"
  REGISTER_EVENTS=()
  for ev in "${HOOK_EVENTS[@]}"; do
    case " ${KIMI_CODE_ONLY_EVENTS[*]} " in
      *" $ev "*) ;;
      *) REGISTER_EVENTS+=("$ev") ;;
    esac
  done
fi

BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'
info()  { printf "%s>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s!%s %s\n" "$YELLOW" "$RESET" "$*"; }
error() { printf "%sx%s %s\n" "$RED" "$RESET" "$*" >&2; }

is_watcher_script() {
  # Whether $1 names this install's adapter. -ef compares inodes, so symlinks
  # and ../ in either path still match.
  local candidate
  for candidate in "$PEON_DIR/adapters/kimi.sh" "$(self_path)"; do
    if [ "$1" = "$candidate" ] || [ "$1" -ef "$candidate" ]; then
      return 0
    fi
  done
  return 1
}

is_legacy_watcher() {
  # The watcher was started as `nohup bash "$0"` with no arguments, $0 being
  # the adapter path its --install was run with. So its argv is exactly
  # ("bash", <path>), and <path> has to be this install's adapter: a process
  # that merely mentions kimi or bash -- another script, an editor, a shell
  # job, a program handed "bash <adapter>" as arguments -- does not qualify.
  local pid="$1" arg script cwd args comm
  local -a argv=()

  if [ -r "/proc/$pid/cmdline" ]; then
    # Linux: read argv as the kernel holds it, NUL-separated, instead of the
    # space-joined text ps prints, where argument boundaries are lost.
    while IFS= read -r -d '' arg; do
      argv+=("$arg")
    done < "/proc/$pid/cmdline"
    [ "${#argv[@]}" -eq 2 ] || return 1
    [ "$(basename -- "${argv[0]}")" = bash ] || return 1
    # argv[0] is whatever the parent chose; the executable is not.
    [ "$(basename -- "$(readlink "/proc/$pid/exe" 2>/dev/null)")" = bash ] || return 1
    script="${argv[1]}"
    case "$script" in
      /*) ;;
      # Started from a relative path: resolve it against the watcher's own
      # working directory.
      *) cwd="$(readlink "/proc/$pid/cwd" 2>/dev/null)" || return 1
         script="$cwd/$script" ;;
    esac
    is_watcher_script "$script"
    return
  fi

  # Elsewhere (macOS) there is no /proc, and ps only has the joined text. Ask
  # ps for the executable separately, then demand the joined text be exactly
  # "<argv0> <adapter path>" for an absolute adapter path. A relative path
  # cannot be resolved without the process's cwd, so it stays unverified.
  comm="$(ps -p "$pid" -o comm= 2>/dev/null)" || return 1
  [ "$(basename -- "$comm")" = bash ] || return 1
  args="$(ps -p "$pid" -o args= 2>/dev/null)" || return 1
  case "$args" in
    *" /"*) ;;
    *) return 1 ;;
  esac
  arg="${args%% /*}"            # argv[0]: everything before the first " /"
  case "$arg" in
    bash|*/bash) ;;
    *) return 1 ;;
  esac
  [ "$arg" != "${arg#* }" ] && return 1   # argv[0] itself never had a space
  is_watcher_script "${args#"$arg" }"
}

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
    local pid
    pid="$(tr -dc '0-9' < "$LEGACY_PIDFILE" 2>/dev/null)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      # A pid outlives the process that wrote it, so only kill the watcher
      # itself, never whatever inherited the number.
      if is_legacy_watcher "$pid"; then
        pkill -P "$pid" 2>/dev/null || true
        kill "$pid" 2>/dev/null || true
        found=1
      elif ps -p "$pid" -o args= 2>/dev/null | grep -q 'kimi\.sh'; then
        warn "PID $pid may be the old Kimi watcher, but its script path could not be verified; left it running."
        warn "If it is, stop it with: kill $pid"
      fi
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

locate_block() {
  # Print "<begin> <end> <sep> <eof> <crlf>" for the managed block: the marker
  # line numbers, whether the line ahead of the begin marker is the blank
  # separator --install writes, whether the begin marker carries EOF_NOTE, and
  # whether the block was written with CRLF. "none" if there is no block, "open"
  # if the begin marker has no end marker after it.
  awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" -v n="$EOF_NOTE" '
    !begin && index($0, b) == 1 {
      begin = NR
      sep = (NR > 1 && (prev == "" || prev == "\r"))
      eof = (index($0, n) > 0)
      crlf = (substr($0, length($0)) == "\r")
      next
    }
    begin && index($0, e) == 1 { print begin, NR, sep, eof, crlf; found = 1; exit }
    { prev = $0 }
    END { if (!found) print (begin ? "open" : "none") }
  ' "$1"
}

count_unmanaged_hooks() {
  # Count lines outside the managed block that run this adapter. Kimi Code's
  # kimi-cli migration copies [[hooks]] from ~/.kimi/config.toml into its own
  # config by re-serializing them, which drops our markers, so a block from a
  # kimi-cli install can come back unmarked next to the one --install writes.
  # Only the marked block is ours to edit; these are reported, not touched.
  awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
    index($0, b) == 1 { skip = 1; next }
    index($0, e) == 1 { skip = 0; next }
    skip || /^[[:space:]]*#/ { next }
    /adapters[\/\\]+kimi\.(sh|ps1)/ { n++ }
    END { print n + 0 }
  ' "$1"
}

warn_unmanaged_hooks() {
  local n
  [ -f "$KIMI_CONFIG" ] || return 0
  n="$(count_unmanaged_hooks "$KIMI_CONFIG")"
  [ "$n" -gt 0 ] || return 0
  # stderr: uninstall.sh discards the adapter's stdout.
  {
    warn "$KIMI_CONFIG has $n hook command(s) outside the peon-ping block that run the Kimi adapter."
    warn "Kimi Code's migration from kimi-cli copies hooks without the block markers, so these"
    warn "were likely carried over from ~/.kimi. Alongside the block they can make events fire"
    warn "twice, and uninstalling peon-ping leaves them behind. Remove those [[hooks]] entries by hand."
  } >&2
}

strip_block() {
  # Print the config with the managed block removed, along with the separator
  # and EOF newline --install added for it, and every other byte untouched.
  # awk only locates the block; head/tail copy the rest, because re-printing
  # lines through awk loses whitespace-only lines, CRs and a missing final
  # newline. Fails on an unterminated block rather than guess where it ends.
  local file="$1" loc begin end sep eof crlf keep size
  [ -f "$file" ] || return 0
  # An unreadable config must not pass for an empty one: --install would then
  # write the block over everything the user had.
  if ! loc="$(locate_block "$file")"; then
    error "Cannot read Kimi config: $file"
    return 1
  fi
  case "$loc" in
    none) cat "$file"; return 0 ;;
    open) error "$file has \"$BEGIN_MARKER\" without \"$END_MARKER\"; fix it by hand."; return 1 ;;
  esac
  read -r begin end sep eof crlf <<< "$loc"
  keep=$((begin - 1 - sep))

  # Only take the EOF newline back if the block is still last in the file:
  # anything appended after it needs that newline to stay on its own line.
  if [ "$eof" = 1 ] && [ "$keep" -gt 0 ] && [ "$(tail -n "+$((end + 1))" "$file" | wc -c)" -eq 0 ]; then
    size=$(head -n "$keep" "$file" | wc -c)
    head -n "$keep" "$file" | head -c $((size - 1 - crlf))
    return 0
  fi
  # BSD head rejects -n 0.
  [ "$keep" -gt 0 ] && head -n "$keep" "$file"
  tail -n "+$((end + 1))" "$file"
  return 0
}

case "${1:-}" in
  --help|-h)
    cat <<EOF
Usage: bash kimi.sh [--install|--uninstall|--status|--stop-watcher]

  --install      Register peon-ping hooks in $KIMI_CONFIG
  --uninstall    Remove them
  --status       Report whether they are registered
  --stop-watcher Only stop the watcher daemon this adapter used to be
  (no args)      Hook mode: read one Kimi event as JSON on stdin and forward it
EOF
    exit 0
    ;;

  --status)
    if [ -f "$KIMI_CONFIG" ]; then
      grep -qF "$BEGIN_MARKER" "$KIMI_CONFIG"
      rc=$?
      if [ "$rc" -gt 1 ]; then
        error "Cannot read Kimi config: $KIMI_CONFIG"
        exit 1
      fi
    else
      rc=1
    fi
    if [ "$rc" -eq 0 ]; then
      count=$(awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
        index($0, b) == 1 { inblock = 1; next }
        index($0, e) == 1 { inblock = 0; next }
        inblock && /^event = / { n++ }
        END { print n + 0 }
      ' "$KIMI_CONFIG")
      info "peon-ping hooks registered in $KIMI_CONFIG ($count events)"
      warn_unmanaged_hooks
      exit 0
    fi
    warn "peon-ping hooks not registered in $KIMI_CONFIG"
    warn_unmanaged_hooks
    exit 1
    ;;

  --stop-watcher)
    # For uninstall.sh, which handles each config itself but still has to reap
    # a daemon left by an install that never registered hooks.
    stop_legacy_watcher
    exit 0
    ;;

  --uninstall)
    stop_legacy_watcher
    if [ ! -f "$KIMI_CONFIG" ]; then
      info "Nothing to remove ($KIMI_CONFIG does not exist)."
      exit 0
    fi
    # grep exits 1 for "read it, no marker" and 2 when it could not read the
    # file. Only the first means there is nothing to remove; taking the second
    # for it would let uninstall.sh delete the adapter the hooks still run.
    if grep -qF "$BEGIN_MARKER" "$KIMI_CONFIG"; then
      :
    else
      rc=$?
      if [ "$rc" -eq 1 ]; then
        info "Nothing to remove (no peon-ping block found)."
        warn_unmanaged_hooks
        exit 0
      fi
      error "Cannot read Kimi config: $KIMI_CONFIG"
      exit 1
    fi
    tmp="$(mktemp)"
    if ! strip_block "$KIMI_CONFIG" > "$tmp"; then
      rm -f "$tmp"
      exit 1
    fi
    # Write through the existing file rather than mv over it, so its mode,
    # owner and any symlink survive. A failed write has to fail the command:
    # uninstall.sh deletes the adapter next, and the hooks would point at it.
    if ! cat "$tmp" > "$KIMI_CONFIG"; then
      rm -f "$tmp"
      error "Could not write $KIMI_CONFIG; peon-ping hooks were not removed."
      exit 1
    fi
    rm -f "$tmp"
    info "Removed peon-ping hooks from $KIMI_CONFIG"
    warn_unmanaged_hooks
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
    if ! strip_block "$KIMI_CONFIG" > "$tmp"; then
      rm -f "$tmp"
      exit 1
    fi
    # Match the config's line endings so a CRLF file stays CRLF.
    nl=$'\n'
    LC_ALL=C grep -q $'\r$' "$tmp" && nl=$'\r\n'
    begin_line="$BEGIN_MARKER"
    {
      # Separate the block from existing content with one blank line, but do
      # not open an empty config with one. A last line without a newline has to
      # be terminated first; EOF_NOTE records that for --uninstall.
      if [ -s "$tmp" ]; then
        if [ -n "$(tail -c 1 "$tmp")" ]; then
          printf '%s' "$nl"
          begin_line="$BEGIN_MARKER $EOF_NOTE"
        fi
        printf '%s' "$nl"
      fi
      printf '%s%s' "$begin_line" "$nl"
      printf '# install_dir = %s%s' "$PEON_DIR" "$nl"
      for ev in "${REGISTER_EVENTS[@]}"; do
        printf '%s[[hooks]]%s' "$nl" "$nl"
        printf 'event = "%s"%s' "$ev" "$nl"
        printf 'command = %s%s' "$(toml_basic "$HOOK_COMMAND")" "$nl"
        printf 'timeout = 10%s' "$nl"
      done
      printf '%s%s%s' "$nl" "$END_MARKER" "$nl"
    } >> "$tmp"
    if ! cat "$tmp" > "$KIMI_CONFIG"; then
      rm -f "$tmp"
      error "Could not write $KIMI_CONFIG; peon-ping hooks were not registered."
      exit 1
    fi
    rm -f "$tmp"

    info "${BOLD}peon-ping hooks registered for $KIMI_TARGET${RESET}"
    printf "  %sconfig:%s  %s\n" "$DIM" "$RESET" "$KIMI_CONFIG"
    printf "  %sadapter:%s %s\n" "$DIM" "$RESET" "$ADAPTER"
    printf "  %sevents:%s  %s\n" "$DIM" "$RESET" "${REGISTER_EVENTS[*]}"
    if [ "${#REGISTER_EVENTS[@]}" -lt "${#HOOK_EVENTS[@]}" ]; then
      warn "Left out ${KIMI_CODE_ONLY_EVENTS[*]}: only Kimi Code (~/.kimi-code) has them,"
      warn "and the older kimi-cli refuses to start with a config that names them."
      warn "Approval prompts stay silent until you move to Kimi Code."
    fi
    warn_unmanaged_hooks
    echo ""
    if [ "$KIMI_TARGET" = "Kimi Code" ]; then
      info "Run 'kimi doctor' to validate, then restart Kimi Code."
    else
      info "Restart kimi-cli (1.28.0 or later; earlier versions have no hooks)."
    fi
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
