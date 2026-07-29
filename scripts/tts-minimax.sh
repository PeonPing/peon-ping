#!/bin/bash
# peon-ping: MiniMax speech (T2A) TTS backend
#
# A cloud HTTP backend that synthesizes speech through the MiniMax
# text-to-audio (T2A v2) API, then plays the returned audio through the
# platform's audio player. Unlike scripts/tts-native.sh (which speaks
# directly to the OS engine), this backend produces an audio file over
# HTTP and plays it locally.
#
# Usage:
#   echo "text to speak" | tts-minimax.sh <voice> <rate> <volume>
#   tts-minimax.sh --list-voices
#
# Positional args:
#   voice   MiniMax voice_id (e.g. a configured voice) or "default" to let
#           the service pick its default voice (voice_id is omitted).
#   rate    float; 1.0 = normal speed. Mapped to voice_setting.speed and
#           clamped to the MiniMax-supported 0.5-2.0 range.
#   volume  float 0.0-1.0. Applied at the local player (not the API).
#
# Stdin:   one line of text to speak (read verbatim, no interpolation).
# Stdout:  empty.
# Stderr:  empty unless PEON_DEBUG=1, in which case diagnostics are
#          prefixed with `[tts-minimax]`.
# Exit:    always 0 — TTS failure must not fail the calling hook.
#
# Env vars:
#   PEON_DEBUG           "1" enables stderr diagnostics
#   PEON_DIR             peon-ping install dir (auto-resolved from $0)
#   MINIMAX_API_KEY      Bearer credential (required; absent → silent exit 0)
#   MINIMAX_GROUP_ID     optional; appended as ?GroupId=... when set
#   PEON_MINIMAX_REGION  "global_en" (default) → api.minimax.io
#                        "cn_zh"               → api.minimaxi.com
#   PEON_MINIMAX_MODEL   T2A model id (default "speech-2.8-hd"; other options
#                        include "speech-2.8-turbo")
#   PEON_MINIMAX_FORMAT  audio format: mp3 (default), wav, flac, pcm
#   PEON_TTS_DRY_RUN     "1" writes the resolved request to
#                        PEON_TTS_TRACE_FILE and skips the network call
#   PEON_TTS_TRACE_FILE  dry-run trace destination
#
# See docs/adr/ADR-001-tts-backend-architecture.md for the calling
# convention this backend implements.

set -uo pipefail

PEON_DEBUG="${PEON_DEBUG:-0}"

_debug() {
  [ "$PEON_DEBUG" = "1" ] && printf '[tts-minimax] %s\n' "$*" >&2
  return 0
}

# --- Resolve PEON_DIR ---
if [ -z "${PEON_DIR:-}" ]; then
  PEON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# --- Regional endpoint resolution ---
# The T2A v2 endpoint differs by region: the global service lives on
# api.minimax.io, the CN service on api.minimaxi.com. Any unrecognized
# region falls back to the global endpoint.
_endpoint_for_region() {
  case "$1" in
    cn_zh)     echo "https://api.minimaxi.com/v1/t2a_v2" ;;
    global_en) echo "https://api.minimax.io/v1/t2a_v2" ;;
    *)         echo "https://api.minimax.io/v1/t2a_v2" ;;
  esac
}

# --- Request body construction ---
# Built with python3 so arbitrary speech text (quotes, backslashes, newlines)
# is JSON-escaped safely and rate is parsed as data, never interpolated into
# a program string. Emits a single compact JSON object on stdout.
_build_request_json() {
  local text="$1" model="$2" voice="$3" rate="$4" fmt="$5"
  MM_TEXT="$text" MM_MODEL="$model" MM_VOICE="$voice" MM_RATE="$rate" MM_FMT="$fmt" \
    python3 - <<'PY'
import json, os
text = os.environ["MM_TEXT"]
model = os.environ["MM_MODEL"]
voice = os.environ["MM_VOICE"]
fmt = os.environ["MM_FMT"]
try:
    speed = float(os.environ["MM_RATE"])
except (ValueError, KeyError):
    speed = 1.0
# Clamp to the MiniMax-supported speed range.
speed = max(0.5, min(2.0, speed))
voice_setting = {"speed": speed}
# "default" means "let the service choose" — omit voice_id entirely.
if voice and voice != "default":
    voice_setting["voice_id"] = voice
body = {
    "model": model,
    "text": text,
    "stream": False,
    "voice_setting": voice_setting,
    "audio_setting": {"format": fmt},
}
print(json.dumps(body))
PY
}

# --- Response handling ---
# Reads the T2A JSON response on stdin, verifies base_resp.status_code == 0,
# then hex-decodes data.audio into the file named by $1. Exits non-zero on any
# failure so the caller can skip playback.
_decode_response_to_file() {
  local outfile="$1"
  # `python3 -c` (not `python3 - <<heredoc`) so the response JSON piped on
  # stdin reaches the program instead of being shadowed by the here-doc.
  MM_OUT="$outfile" python3 -c '
import json, os, sys
raw = sys.stdin.read()
try:
    payload = json.loads(raw)
except Exception:
    sys.exit(1)
base = payload.get("base_resp") or {}
if base.get("status_code", -1) != 0:
    sys.stderr.write("base_resp.status_code=%s\n" % base.get("status_code"))
    sys.exit(2)
data = payload.get("data") or {}
audio_hex = data.get("audio")
if not audio_hex:
    sys.exit(3)
try:
    audio_bytes = bytes.fromhex(audio_hex)
except Exception:
    sys.exit(4)
with open(os.environ["MM_OUT"], "wb") as fh:
    fh.write(audio_bytes)
'
}

# --- Local playback (mirrors platform conventions in peon.sh play_sound) ---
_play_linux() {
  local file="$1" volume="$2" vint
  if command -v pw-play >/dev/null 2>&1; then
    pw-play --volume "$volume" "$file" 2>/dev/null || _debug "pw-play failed"
  elif command -v ffplay >/dev/null 2>&1; then
    vint=$(awk -v v="$volume" 'BEGIN { printf "%d", v * 100 }')
    ffplay -nodisp -autoexit -volume "$vint" "$file" 2>/dev/null || _debug "ffplay failed"
  elif command -v mpv >/dev/null 2>&1; then
    vint=$(awk -v v="$volume" 'BEGIN { printf "%d", v * 100 }')
    mpv --no-video --volume="$vint" "$file" 2>/dev/null || _debug "mpv failed"
  elif command -v play >/dev/null 2>&1; then
    play -v "$volume" "$file" 2>/dev/null || _debug "play failed"
  elif command -v paplay >/dev/null 2>&1; then
    paplay "$file" 2>/dev/null || _debug "paplay failed"
  elif command -v aplay >/dev/null 2>&1; then
    aplay -q "$file" 2>/dev/null || _debug "aplay failed"
  else
    _debug "no audio player found on Linux"
  fi
}

_play_windows() {
  local file="$1" volume="$2"
  local ps_script="$PEON_DIR/scripts/win-play.ps1"
  if [ ! -f "$ps_script" ]; then
    _debug "win-play.ps1 not found at $ps_script"
    return 0
  fi
  local winpath="$file"
  command -v cygpath >/dev/null 2>&1 && winpath="$(cygpath -w "$file")"
  powershell.exe -NoProfile -File "$ps_script" -path "$winpath" -vol "$volume" 2>/dev/null \
    || _debug "win-play.ps1 failed"
}

_play_file() {
  local file="$1" volume="$2"
  case "$(uname -s)" in
    Darwin)       afplay -v "$volume" "$file" 2>/dev/null || _debug "afplay failed" ;;
    Linux)        _play_linux "$file" "$volume" ;;
    MINGW*|MSYS*) _play_windows "$file" "$volume" ;;
    *)            _debug "unsupported platform for playback: $(uname -s)" ;;
  esac
}

# --- Entry point ---

# MiniMax voices are documented voice_id strings rather than a locally
# enumerable list, so --list-voices is a no-op that exits cleanly (keeps the
# `peon tts voices` command working when this backend is active).
if [ "${1:-}" = "--list-voices" ]; then
  _debug "voice enumeration not supported for the MiniMax backend"
  exit 0
fi

voice="${1:-default}"
rate="${2:-1.0}"
volume="${3:-0.5}"

region="${PEON_MINIMAX_REGION:-global_en}"
model="${PEON_MINIMAX_MODEL:-speech-2.8-hd}"
fmt="${PEON_MINIMAX_FORMAT:-mp3}"
url="$(_endpoint_for_region "$region")"
if [ -n "${MINIMAX_GROUP_ID:-}" ]; then
  url="${url}?GroupId=${MINIMAX_GROUP_ID}"
fi

# Read one line of text from stdin. Empty / whitespace-only input exits
# silently — the hook pipeline sometimes invokes speak() with empty text.
IFS= read -r text || text=""
stripped="${text//[[:space:]]/}"
if [ -z "$stripped" ]; then
  _debug "empty input text"
  exit 0
fi

# python3 is required for safe request/response handling.
if ! command -v python3 >/dev/null 2>&1; then
  _debug "python3 not found — cannot build request"
  exit 0
fi

# Dry-run: record the resolved request (never the credential itself) and stop
# before any network call. Powers the test harness.
if [ "${PEON_TTS_DRY_RUN:-0}" = "1" ]; then
  if [ -n "${PEON_TTS_TRACE_FILE:-}" ]; then
    request_json="$(_build_request_json "$text" "$model" "$voice" "$rate" "$fmt")"
    MM_TRACE="$PEON_TTS_TRACE_FILE" MM_URL="$url" MM_REGION="$region" \
    MM_MODEL="$model" MM_FMT="$fmt" MM_VOICE="$voice" MM_RATE="$rate" \
    MM_HAS_KEY="$([ -n "${MINIMAX_API_KEY:-}" ] && echo 1 || echo 0)" \
    MM_HAS_GROUP="$([ -n "${MINIMAX_GROUP_ID:-}" ] && echo 1 || echo 0)" \
    MM_REQ="$request_json" python3 - <<'PY'
import json, os
trace = {
    "url": os.environ["MM_URL"],
    "region": os.environ["MM_REGION"],
    "model": os.environ["MM_MODEL"],
    "format": os.environ["MM_FMT"],
    "voice": os.environ["MM_VOICE"],
    "rate": os.environ["MM_RATE"],
    "has_api_key": os.environ["MM_HAS_KEY"] == "1",
    "has_group_id": os.environ["MM_HAS_GROUP"] == "1",
    "request": json.loads(os.environ["MM_REQ"]),
}
with open(os.environ["MM_TRACE"], "w") as fh:
    json.dump(trace, fh)
PY
  fi
  exit 0
fi

# Credential and curl are required for a live request.
api_key="${MINIMAX_API_KEY:-}"
if [ -z "$api_key" ]; then
  _debug "MINIMAX_API_KEY not set — skipping synthesis"
  exit 0
fi
if ! command -v curl >/dev/null 2>&1; then
  _debug "curl not found — cannot reach the MiniMax API"
  exit 0
fi

request_json="$(_build_request_json "$text" "$model" "$voice" "$rate" "$fmt")" || {
  _debug "failed to build request body"
  exit 0
}

# The Authorization header carries the Bearer credential; it is passed via an
# argument to curl and never written to stdout, stderr, or the trace file.
response="$(curl -sS --max-time 30 -X POST \
  -H "Authorization: Bearer $api_key" \
  -H "Content-Type: application/json" \
  -d "$request_json" \
  "$url" 2>/dev/null)" || {
  _debug "curl request failed"
  exit 0
}

tmpbase="$(mktemp "${TMPDIR:-/tmp}/peon-tts-minimax.XXXXXX")" || {
  _debug "mktemp failed"
  exit 0
}
tmpfile="${tmpbase}.${fmt}"
mv "$tmpbase" "$tmpfile" 2>/dev/null || tmpfile="$tmpbase"

if printf '%s' "$response" | _decode_response_to_file "$tmpfile"; then
  _play_file "$tmpfile" "$volume"
else
  _debug "response decode failed — nothing to play"
fi
rm -f "$tmpfile" 2>/dev/null

# Always exit 0 — TTS failure must never propagate to the caller.
exit 0
