#!/bin/bash
# peon-ping: click-time focus helper for LOCAL tmux sessions (macOS).
#
# Usage:
#   local-focus.sh <tmux-socket> <tmux-pane> [fallback-bundle-id] [tmux-bin]
#       Click handler: raise the terminal that is showing this tmux session right
#       now, then switch that client to the agent's own window/pane.
#   local-focus.sh --print-context <tmux-socket> <tmux-pane> "" [tmux-bin]
#       Print "<bundle_id>|<client_tty>|<terminal_pid>" for the notifier to use at
#       notify time (empty fields when nothing is attached). No side effects.
#
# WHY the terminal is resolved at click time and not from the environment
#
# A hook only sees the environment its own process inherited, and a pane's
# environment is frozen when the pane is created. The identity vars peon reads
# (ITERM_SESSION_ID, GHOSTTY_RESOURCES_DIR, WARP_IS_LOCAL_SHELL_SESSION) therefore
# name the emulator the tmux session was FIRST attached from — forever:
#   - quit/restart the terminal, or attach the session from a different one, and
#     the stored identity points at an app that is not showing this session, so
#     the click raises the wrong window (or relaunches a quit app);
#   - kitty and alacritty export no such var at all, so the identity comes out
#     empty and the click raises nothing — the notification looks dead.
# tmux is never stale: it knows which client is attached at this instant. So ask
# tmux, then walk that client's process ancestry until an ancestor has a bundle
# id — that ancestor is the hosting terminal, whichever emulator it happens to
# be. Same discovery ssh-focus.sh does for relayed remote sessions.
#
# Constraints (mirrors ssh-focus.sh):
#   - The overlay's click handler blocks on this: return fast, never prompt.
#   - Runs under stock macOS /bin/bash 3.2 (BSD regex: interval upper bounds
#     above 255 are invalid and silently never match — use unbounded +).
#   - Only ever drive a tmux client that was positively identified.
#   - Always exits 0.
set -u

MODE="click"
if [ "${1:-}" = "--print-context" ]; then
  MODE="context"
  shift
fi

SOCK="${1:-}"
PANE="${2:-}"
FALLBACK_BUNDLE="${3:-}"
TMUX_BIN_ARG="${4:-}"

PEON_DIR="${PEON_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

_DBG_ON=""
_dbg() {
  if [ -z "$_DBG_ON" ]; then
    # PEON_DEBUG is not exported by the hook, so honour config.json's `debug`
    # too — otherwise the click path is undebuggable in normal use.
    if [ "${PEON_DEBUG:-0}" = "1" ] || grep -q '"debug"[[:space:]]*:[[:space:]]*true' "$PEON_DIR/config.json" 2>/dev/null; then
      _DBG_ON=1
    else
      _DBG_ON=0
    fi
  fi
  [ "$_DBG_ON" = "1" ] || return 0
  local d="$PEON_DIR/logs"
  mkdir -p "$d" 2>/dev/null || return 0
  printf '%s [local-focus] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" \
    >> "$d/peon-ping-$(date +%Y-%m-%d).log" 2>/dev/null || true
}

_bail() {
  # context mode must still print a (empty) record so callers can parse blindly
  [ "$MODE" = "context" ] && printf '||\n'
  exit 0
}

# --- Validate inputs (both modes) ---
[[ "$PANE" =~ ^%?[0-9]+$ ]] || { _dbg "bad pane=$PANE"; _bail; }
[[ "$SOCK" =~ ^/[A-Za-z0-9._/-]+$ ]] || { _dbg "bad socket=$SOCK"; _bail; }

# Which tmux to drive. The click runs under `bash -lc` from the overlay, whose
# login PATH is whatever ~/.bash_profile happens to set — not the hook's PATH. On
# a Mac that regularly means finding /usr/bin/tmux (3.5a) instead of the Homebrew
# build the server actually runs, and a version-mismatched client on a live socket
# just prints "lost server" and switches nothing. So the notifier pins the binary
# it resolved at notify time, and PATH lookup is only the fallback.
TMUX_BIN=""
if [[ "$TMUX_BIN_ARG" =~ ^/[A-Za-z0-9._/-]+$ ]] && [ -x "$TMUX_BIN_ARG" ]; then
  TMUX_BIN="$TMUX_BIN_ARG"
else
  TMUX_BIN="$(command -v tmux 2>/dev/null || true)"
  if [ -z "$TMUX_BIN" ]; then
    for _c in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux; do
      [ -x "$_c" ] && { TMUX_BIN="$_c"; break; }
    done
  fi
fi
[ -n "$TMUX_BIN" ] || { _dbg "no tmux binary found (arg=$TMUX_BIN_ARG)"; _bail; }

TM=("$TMUX_BIN" -S "$SOCK")

# --- Pick the client to focus ---
# Prefer a client attached to this pane's own session; among those the most
# recently active one is what the user is looking at (a session can carry several
# clients — a second window, a phone over ssh). A client on a *different* session
# is only a last resort: switch-client can still pull our session into it, but it
# means yanking that client away from what it was showing, so it must never beat
# a client that already has our session.
_pick_client() {
  local sess
  sess="$("${TM[@]}" display-message -p -t "$PANE" '#{session_name}' 2>/dev/null)" || sess=""
  "${TM[@]}" list-clients -F '#{client_activity}|#{client_pid}|#{client_tty}|#{client_session}' 2>/dev/null \
    | awk -F'|' -v s="$sess" '
        $2 == "" || $3 == "" { next }
        {
          # session name is the last field and may itself contain "|"
          ses = $4; for (i = 5; i <= NF; i++) ses = ses "|" $i
          if (s != "" && ses == s) {
            if ($1 + 0 > best) { best = $1 + 0; bpid = $2; btty = $3 }
          } else if ($1 + 0 > any) { any = $1 + 0; apid = $2; atty = $3 }
        }
        END {
          if (btty != "") print bpid "|" btty
          else if (atty != "") print apid "|" atty
        }'
}

CLIENT_PID=""
CLIENT_TTY=""
_pc="$(_pick_client)"
if [ -n "$_pc" ]; then
  CLIENT_PID="${_pc%%|*}"
  CLIENT_TTY="${_pc#*|}"
fi

# --- Derive the bundle id of a running app by PID (macOS lsappinfo) ---
_bundle_from_pid() {
  local pid="$1"
  { [ -z "$pid" ] || [ "$pid" = "0" ]; } && return
  lsappinfo info -only bundleid -app pid:"$pid" 2>/dev/null \
    | sed -n 's/.*="\([^"]*\)".*/\1/p'
}

# Climb from the tmux client until an ancestor has a bundle id — that ancestor is
# the terminal app (the client, shells and helper servers have none).
TERM_PID=""
TERM_BUNDLE=""
if [ -n "$CLIENT_PID" ] && [ "$(uname -s)" = "Darwin" ]; then
  p="$CLIENT_PID"
  for _i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    { [ -z "$p" ] || [ "$p" = "0" ] || [ "$p" = "1" ]; } && break
    b="$(_bundle_from_pid "$p")"
    if [ -n "$b" ]; then TERM_PID="$p"; TERM_BUNDLE="$b"; break; fi
  done
fi

# The ancestry can dead-end at launchd: iTerm2 keeps its ptys in a detachable
# iTermServer, and after iTerm2 restarts and re-adopts it that server's parent is
# pid 1, not the new app. The notify-time guess is right in exactly that case
# (same app, restarted), so fall back to it rather than raising nothing.
if [ -z "$TERM_BUNDLE" ] && [ -n "$FALLBACK_BUNDLE" ]; then
  TERM_BUNDLE="$FALLBACK_BUNDLE"
  _dbg "ancestry gave no bundle; using fallback=$TERM_BUNDLE"
fi

_dbg "$MODE pane=$PANE tmux=$TMUX_BIN client_pid=$CLIENT_PID client_tty=$CLIENT_TTY term_pid=$TERM_PID bundle=$TERM_BUNDLE"

if [ "$MODE" = "context" ]; then
  printf '%s|%s|%s\n' "$TERM_BUNDLE" "$CLIENT_TTY" "$TERM_PID"
  exit 0
fi

# --- Step 1: raise the terminal app ---
# By PID when we have it (unambiguous, and works for any emulator); otherwise by
# bundle id, matching a RUNNING app only — never `open -b`, which would launch a
# terminal the user has quit and pop an empty window.
if [ -n "$TERM_PID" ] || [ -n "$TERM_BUNDLE" ]; then
  /usr/bin/osascript -l JavaScript -e '
    function run(argv) {
      ObjC.import("Cocoa");
      var pid = parseInt(argv[0], 10);
      if (pid > 0) {
        var app = $.NSRunningApplication.runningApplicationWithProcessIdentifier(pid);
        if (app && !app.isNil()) {
          app.activateWithOptions($.NSApplicationActivateIgnoringOtherApps);
          return;
        }
      }
      var bid = argv[1];
      if (!bid) return;
      var apps = $.NSWorkspace.sharedWorkspace.runningApplications;
      for (var i = 0; i < apps.count; i++) {
        var a = apps.objectAtIndex(i);
        var b = a.bundleIdentifier;
        if (!b.isNil() && b.js === bid) {
          a.activateWithOptions($.NSApplicationActivateIgnoringOtherApps);
          return;
        }
      }
    }' "${TERM_PID:-0}" "$TERM_BUNDLE" >/dev/null 2>&1 || true
fi

# --- Step 2: iTerm2 only — raise the exact window/tab hosting this client ---
# Activating the app lands on its frontmost window, which may be a different tab.
if [ "$TERM_BUNDLE" = "com.googlecode.iterm2" ] && [ -n "$CLIENT_TTY" ]; then
  /usr/bin/osascript -l JavaScript -e '
    function run(argv) {
      var tty = argv[0];
      var iTerm = Application("iTerm2");
      var ws = iTerm.windows();
      for (var w = 0; w < ws.length; w++) {
        var ts = ws[w].tabs();
        for (var t = 0; t < ts.length; t++) {
          var ss = ts[t].sessions();
          for (var s = 0; s < ss.length; s++) {
            try {
              if (ss[s].tty() !== tty) continue;
              ts[t].select();
              ss[s].select();
              ws[w].index = 1;
              iTerm.activate();
              // AXRaise last, in its own guard: it needs Accessibility rights
              // this process may not have, and a throw here must not cost us the
              // activate above (which is what actually fronts the tab).
              try {
                var wn = ws[w].name();
                var sw = Application("System Events").processes["iTerm2"].windows();
                for (var i = 0; i < sw.length; i++) {
                  if (sw[i].name() === wn) { sw[i].actions["AXRaise"].perform(); break; }
                }
              } catch (e2) {}
              return;
            } catch (e) {}
          }
        }
      }
    }' "$CLIENT_TTY" >/dev/null 2>&1 || true
fi

# --- Step 3: switch tmux to the agent's own window/pane ---
# Target the client we identified (-c) instead of letting tmux guess: with more
# than one client attached, an untargeted switch-client can move the wrong one.
# One chained invocation so the three commands cannot interleave with a resize.
if [ -n "$CLIENT_TTY" ]; then
  "${TM[@]}" switch-client -c "$CLIENT_TTY" -t "$PANE" \; \
             select-window -t "$PANE" \; \
             select-pane -t "$PANE" >/dev/null 2>&1 \
    || "${TM[@]}" select-window -t "$PANE" \; select-pane -t "$PANE" >/dev/null 2>&1 \
    || _dbg "tmux switch failed pane=$PANE client=$CLIENT_TTY"
else
  # Nothing attached — there is no screen to switch. Selecting the window anyway
  # would silently rearrange a detached session behind the user's back.
  _dbg "no attached client; skipped tmux switch"
fi

exit 0
