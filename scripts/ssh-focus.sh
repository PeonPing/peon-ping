#!/bin/bash
# peon-ping: click-time focus helper for relayed (remote SSH) notifications.
#
# Invoked by the notification overlay / terminal-notifier as `bash -lc <this>`
# with NO arguments. Every input arrives via PEON_FOCUS_* environment variables
# set by relay.sh — never on the command line — so untrusted remote strings can
# never break out into a shell command here.
#
# What it does, on click:
#   A. Find the local ssh client process hosting the remote agent's session.
#   B. Raise the terminal app (and, where scriptable, the exact tab) that ssh
#      runs in — whatever terminal emulator it is (discovered, not hardcoded).
#   C. Best-effort switch the *remote* tmux to the agent's own window/pane over
#      that same ssh, reusing a ControlMaster if one exists.
#
# Constraints (why the code looks the way it does):
#   - Must return fast (<1s): the overlay's click handler blocks on it.
#   - Must never prompt or hang → ssh uses BatchMode + ConnectTimeout, backgrounded.
#   - Must never switch a tmux it hasn't POSITIVELY matched to this agent.
#   - Must run under macOS's stock /bin/bash 3.2 (no assoc arrays, no ${x,,}).
#   - Always exits 0.
set -u

# Two modes:
#   (default) click: focus the tab + switch the remote tmux pane.
#   --prewarm       : just open/reuse the ssh master to the box, then exit. The
#                     relay fires this the moment the notification appears, so by
#                     the time the user clicks, the (slow, GSSAPI/Kerberos) ssh
#                     connection is already established and the pane switch is
#                     instant instead of paying a ~3s cold connect on click.
MODE="click"
[ "${1:-}" = "--prewarm" ] && MODE="prewarm"

PEON_DIR="${PEON_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Shared ssh options: a per-connection master (ControlMaster) kept alive for
# 10 min so repeated clicks — and the click after a prewarm — reuse one
# connection. ClearAllForwardings drops the config's RemoteForward (the relay
# tunnel) which would otherwise fail noisily on these extra connections.
_CM_DIR="$HOME/.ssh/peon-cm"
mkdir -p "$_CM_DIR" 2>/dev/null && chmod 700 "$_CM_DIR" 2>/dev/null
SSH_CM=(-o BatchMode=yes -o ClearAllForwardings=yes \
        -o ControlMaster=auto -o "ControlPath=$_CM_DIR/%C" -o ControlPersist=600)

_dbg() {
  [ "${PEON_DEBUG:-0}" = "1" ] || return 0
  local d="$PEON_DIR/logs"
  mkdir -p "$d" 2>/dev/null || return 0
  printf '%s [ssh-focus] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" \
    >> "$d/peon-ping-$(date +%Y-%m-%d).log" 2>/dev/null || true
}

# --- Focus context (defensively re-validated even though relay.sh validated) ---
F_TMUX_SOCKET="${PEON_FOCUS_TMUX_SOCKET:-}"
F_TMUX_PANE="${PEON_FOCUS_TMUX_PANE:-}"
F_TMUX_BIN="${PEON_FOCUS_TMUX_BIN:-}"
F_SERVER_IP="${PEON_FOCUS_SERVER_IP:-}"
F_HOST="${PEON_FOCUS_HOST:-}"
F_RELAY_PORT="${PEON_FOCUS_RELAY_PORT:-}"

TMUX_OK=1
[[ "$F_TMUX_PANE" =~ ^%?[0-9]{1,12}$ ]] || TMUX_OK=0
[[ "$F_TMUX_SOCKET" =~ ^/[A-Za-z0-9._/-]+$ ]] || TMUX_OK=0
[[ "$F_RELAY_PORT" =~ ^[0-9]{1,5}$ ]] || F_RELAY_PORT=""
[[ "$F_SERVER_IP" =~ ^[A-Za-z0-9.:_-]+$ ]] || F_SERVER_IP=""
# Remote tmux binary must be the server's own (a version-mismatched client just
# says "lost server"). Use the transmitted absolute path; fall back to `tmux`.
[[ "$F_TMUX_BIN" =~ ^/[A-Za-z0-9._/-]+$ ]] || F_TMUX_BIN=""
RTMUX="${F_TMUX_BIN:-tmux}"

_dbg "start pane=$F_TMUX_PANE socket=$F_TMUX_SOCKET tmux_bin=$RTMUX server_ip=$F_SERVER_IP relay_port=$F_RELAY_PORT tmux_ok=$TMUX_OK"

# --- Derive the bundle id of a running app by PID (macOS lsappinfo) ---
_bundle_from_pid() {
  local pid="$1"
  { [ -z "$pid" ] || [ "$pid" = "0" ]; } && return
  lsappinfo info -only bundleid -app pid:"$pid" 2>/dev/null \
    | sed -n 's/.*="\([^"]*\)".*/\1/p'
}

# --- Extract the [user@]host destination from an ssh command line (best-effort) ---
# Walks argv, skipping options and their arguments, and returns the first bare
# operand. Handles both "-p 22" and glued "-p22"/"-oFoo=bar" forms.
_ssh_dest() {
  local -a toks
  toks=($1)
  local n="${#toks[@]}" i=1 tok c
  local with_arg="bcDEeFIiJLlmOopQRSWw"
  while [ "$i" -lt "$n" ]; do
    tok="${toks[$i]}"
    case "$tok" in
      --)
        i=$((i + 1)); [ "$i" -lt "$n" ] && printf '%s' "${toks[$i]}"; return ;;
      -*)
        c="${tok:1:1}"
        if [ "${#tok}" -gt 2 ] && [ -n "$c" ] && [ "${with_arg#*"$c"}" != "$with_arg" ]; then
          : # option with glued argument — consume just this token
        elif [ "${#tok}" -eq 2 ] && [ "${with_arg#*"$c"}" != "$with_arg" ]; then
          i=$((i + 1)) # option takes the next token as its argument
        fi ;;
      *)
        printf '%s' "$tok"; return ;;
    esac
    i=$((i + 1))
  done
}

# --- Step A: collect local ssh candidates attached to a real terminal (ttys*) ---
CAND_PID=()
CAND_CMD=()
while IFS=$'\t' read -r cpid ccmd; do
  [ -n "$cpid" ] || continue
  CAND_PID+=("$cpid")
  CAND_CMD+=("$ccmd")
done < <(ps -Ao pid=,tty=,command= 2>/dev/null \
  | awk '$2 != "??" && $3 ~ /(^|\/)ssh$/ { pid=$1; $1=""; $2=""; sub(/^ +/, ""); print pid "\t" $0 }')

NCAND="${#CAND_PID[@]}"
_dbg "ssh candidates=$NCAND"

SSHPID=""
# Cascade — first match wins; every match here is a POSITIVE identification, so
# it is safe to also switch the remote tmux. If none match we focus nothing and
# never touch tmux (better than jumping to the wrong box).
if [ "$NCAND" -eq 1 ]; then
  SSHPID="${CAND_PID[0]}"
  _dbg "A1 single-candidate pid=$SSHPID"
fi

# A2: reverse-forward owner — the ssh that tunnels the relay port back to the
# Mac IS this tab, regardless of any bastion in between. The forward may be a
# CLI `-R <port>` OR a `RemoteForward` in ssh_config (invisible in argv), so
# check both: the command line, then the effective config via `ssh -G`.
if [ -z "$SSHPID" ] && [ -n "$F_RELAY_PORT" ]; then
  for idx in "${!CAND_PID[@]}"; do
    cmd="${CAND_CMD[$idx]}"
    case "$cmd" in
      *-R*"$F_RELAY_PORT"*) SSHPID="${CAND_PID[$idx]}"; _dbg "A2 reverse-forward(cli) pid=$SSHPID"; break ;;
    esac
    d="$(_ssh_dest "$cmd")"
    if [ -n "$d" ] && ssh -G "$d" 2>/dev/null \
        | awk 'tolower($1)=="remoteforward"{print $2}' \
        | grep -Eq "(^|:)${F_RELAY_PORT}\$"; then
      SSHPID="${CAND_PID[$idx]}"; _dbg "A2 reverse-forward(config) pid=$SSHPID"; break
    fi
  done
fi

# A3: remote endpoint IP equals the box's server_ip (direct connections only;
# breaks behind a bastion, hence last).
if [ -z "$SSHPID" ] && [ -n "$F_SERVER_IP" ] && command -v lsof >/dev/null 2>&1; then
  for idx in "${!CAND_PID[@]}"; do
    if lsof -nP -p "${CAND_PID[$idx]}" -iTCP -sTCP:ESTABLISHED 2>/dev/null \
        | grep -q -- "->$F_SERVER_IP:"; then
      SSHPID="${CAND_PID[$idx]}"; _dbg "A3 endpoint pid=$SSHPID"; break
    fi
  done
fi

if [ -z "$SSHPID" ]; then
  _dbg "no positive ssh match; giving up"
  exit 0
fi

# Resolve the ssh destination once (used by prewarm and the pane switch).
sshcmd="$(ps -ww -o command= -p "$SSHPID" 2>/dev/null)"
dest="$(_ssh_dest "$sshcmd")"

# --- Prewarm mode: just open/join the ssh master, then exit fast. ---
if [ "$MODE" = "prewarm" ]; then
  if [ -n "$dest" ]; then
    _dbg "prewarm dest=$dest"
    nohup ssh "${SSH_CM[@]}" -o ConnectTimeout=8 "$dest" true >/dev/null 2>&1 &
  fi
  exit 0
fi

# --- Step B: focus the hosting terminal (terminal-agnostic) ---
sshtty="$(ps -o tty= -p "$SSHPID" 2>/dev/null | tr -d ' ')"
case "$sshtty" in
  tty*) ttydev="/dev/$sshtty" ;;
  ""|'?'*) ttydev="" ;;
  *) ttydev="/dev/$sshtty" ;;
esac

# Climb the process tree until an ancestor has a bundle id — that ancestor is
# the terminal app (shells and ssh have none).
term_pid=""
term_bundle=""
p="$SSHPID"
for _i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
  { [ -z "$p" ] || [ "$p" = "0" ] || [ "$p" = "1" ]; } && break
  b="$(_bundle_from_pid "$p")"
  if [ -n "$b" ]; then term_pid="$p"; term_bundle="$b"; break; fi
done
_dbg "sshpid=$SSHPID tty=$ttydev term_pid=$term_pid term_bundle=$term_bundle"

# Baseline: activate the terminal app by PID — works for any emulator.
if [ -n "$term_pid" ]; then
  /usr/bin/osascript -l JavaScript -e '
    function run(argv){
      ObjC.import("Cocoa");
      var app=$.NSRunningApplication.runningApplicationWithProcessIdentifier(parseInt(argv[0],10));
      if(app && !app.isNil()){ app.activateWithOptions($.NSApplicationActivateIgnoringOtherApps); }
    }' "$term_pid" >/dev/null 2>&1 || true
fi

# Enhancement: iTerm2 can raise the exact tab whose tty matches the ssh session.
if [ "$term_bundle" = "com.googlecode.iterm2" ] && [ -n "$ttydev" ]; then
  /usr/bin/osascript -l JavaScript -e '
    function run(argv){var tty=argv[0];var iTerm=Application("iTerm2");var ws=iTerm.windows();
    for(var w=0;w<ws.length;w++){var ts=ws[w].tabs();
    for(var t=0;t<ts.length;t++){var ss=ts[t].sessions();
    for(var s=0;s<ss.length;s++){try{if(ss[s].tty()===tty){ts[t].select();ss[s].select();ws[w].index=1;iTerm.activate();return}}catch(e){}}}}}' \
    "$ttydev" >/dev/null 2>&1 || true
fi

# --- Step C: switch the remote tmux to the agent's pane (best-effort) ---
if [ "$TMUX_OK" = "1" ] && [ -n "$dest" ]; then
  _dbg "remote-switch dest=$dest"
  switched=0

  # Fast path: the main ssh connection can forward the remote tmux control
  # socket to a local one (LocalForward in ssh config). If it did, drive the
  # remote tmux with the LOCAL client over that socket — a single round-trip,
  # no new ssh connection and no remote shell spawn (big win on high-RTT /
  # GSSAPI links). Discover the socket from `ssh -G` by matching the forward
  # whose remote end is this session's tmux socket; require the local socket to
  # exist (main connection up) and the local tmux to speak the server's
  # protocol (else the command fails fast and we fall back below).
  if command -v tmux >/dev/null 2>&1; then
    localsock="$(ssh -G "$dest" 2>/dev/null \
      | awk -v r="$F_TMUX_SOCKET" 'tolower($1)=="localforward" && $3==r {print $2; exit}')"
    if [ -n "$localsock" ] && [ -S "$localsock" ]; then
      # F_TMUX_PANE is regex-validated. One chained invocation = one round-trip.
      if tmux -S "$localsock" switch-client -t "$F_TMUX_PANE" \; \
              select-window -t "$F_TMUX_PANE" \; \
              select-pane -t "$F_TMUX_PANE" >/dev/null 2>&1; then
        switched=1
        _dbg "switched via forwarded socket=$localsock"
      else
        _dbg "forwarded socket present but tmux failed (version mismatch?) socket=$localsock"
      fi
    fi
  fi

  # Fallback: run tmux ON the remote over ssh, reusing the (possibly prewarmed)
  # ControlMaster. Used when there's no tunnel (main connection down / not
  # configured) or the local/remote tmux versions differ.
  if [ "$switched" = "0" ]; then
    # F_TMUX_SOCKET / F_TMUX_PANE / RTMUX are regex-validated. Separate tmux
    # invocations (not tmux's `;`) so each survives the remote shell.
    remote_cmd="$RTMUX -S $F_TMUX_SOCKET switch-client -t $F_TMUX_PANE 2>/dev/null; $RTMUX -S $F_TMUX_SOCKET select-window -t $F_TMUX_PANE 2>/dev/null; $RTMUX -S $F_TMUX_SOCKET select-pane -t $F_TMUX_PANE 2>/dev/null"
    TO=""
    if command -v timeout >/dev/null 2>&1; then TO="timeout 8"
    elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout 8"; fi
    nohup $TO ssh "${SSH_CM[@]}" -o ConnectTimeout=8 "$dest" "$remote_cmd" \
      >/dev/null 2>&1 &
  fi
fi

exit 0
