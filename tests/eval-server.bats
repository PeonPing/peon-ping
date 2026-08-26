#!/usr/bin/env bats
# NOTE on assertion style: this machine's bash (3.2, macOS system bash, which
# `env bash` resolves to and which bats-core therefore runs tests under) has
# an ERR trap that does NOT fire for a failing bare `[[ ... ]]` compound
# command — verified empirically. A failing bare `[[ ... ]]` DOES still fail
# the test when it is the LAST statement in the test body (bats checks the
# body's own exit status there), but a failing bare `[[ ... ]]` ANYWHERE ELSE
# in the body silently does NOT gate the test — it reports `ok` regardless.
# `[ ... ]` (single bracket, a POSIX simple command), `grep -q`, and `false`
# DO correctly fail the test in BOTH positions. Every load-bearing assertion
# below therefore uses `[ ]` or `grep -q` when it is not the final statement,
# never a non-final bare `[[ ]]` as the only guard for something that must be
# caught.

setup() {
  TMP="$(mktemp -d)"
  DRAFT="$TMP/draft"
  mkdir -p "$DRAFT/sounds"
  cat > "$DRAFT/openpeon.json" <<'EOF'
{"cesp_version":"1.0","name":"testpack","display_name":"Test Pack","version":"0.0.1","x_openpeon_draft":true,
 "categories":{"task.complete":{"sounds":[{"file":"sounds/done.wav","label":"Done"}]}}}
EOF
  python3 - "$DRAFT/sounds/done.wav" <<'PY'
import sys, wave, struct, math
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(44100)
    w.writeframes(b"".join(struct.pack("<h", int(9000*math.sin(i/20.0))) for i in range(44100)))
PY
  cat > "$TMP/fake-claude" <<'EOF'
#!/usr/bin/env bash
# fake claude -p: succeed if FAKE_CLAUDE_FAIL unset; a real success touches every
# wav under ./sounds (cwd is DRAFT, per the B3 fix) so the server's before/after
# change-detection sees a genuine change and reports "done" rather than "failed".
[ -n "$FAKE_CLAUDE_FAIL" ] && { echo "boom" >&2; exit 1; }
# Block while the hold file exists, so a test that needs the server observably
# busy can hold the job open instead of racing it. Without this, a job finishes
# in the time it takes to append one byte per wav, and "is it busy" depends on
# whether curl happened to flush the SSE stream first. Bounded at 30s so a test
# that forgets to release cannot wedge the suite.
if [ -n "$PEON_TEST_HOLD" ] && [ -f "$PEON_TEST_HOLD" ]; then
  for _ in $(seq 1 300); do [ -f "$PEON_TEST_HOLD" ] || break; sleep 0.1; done
fi
for f in sounds/*.wav; do
  [ -f "$f" ] && printf '\0' >> "$f"
done
exit 0
EOF
  chmod +x "$TMP/fake-claude"
  export PEON_TEST_HOLD="$TMP/claude-hold"
  PEON_TEST_HOLD="$PEON_TEST_HOLD" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/port.txt" 2> "$TMP/server.err" &
  SERVER_PID=$!
  # Wait on BOTH the port line and the lockfile: the tests need both, and the
  # lockfile is what a stalled bind actually withholds. The old 5s budget was
  # tight enough that a slow runner read as a dead server, so every test in this
  # file failed with an unexplained FileNotFoundError. Give it room, then say
  # exactly what happened instead of failing on a missing file three lines later.
  for _ in $(seq 1 300); do
    grep -q PORT= "$TMP/port.txt" 2>/dev/null && [ -f "$DRAFT/.eval-server.json" ] && break
    sleep 0.1
  done
  if ! grep -q PORT= "$TMP/port.txt" 2>/dev/null || [ ! -f "$DRAFT/.eval-server.json" ]; then
    echo "eval-server did not come up within 30s" >&2
    echo "--- server stdout ---" >&2; cat "$TMP/port.txt" >&2
    echo "--- server stderr ---" >&2; cat "$TMP/server.err" >&2
    ps -p "$SERVER_PID" >&2 || echo "server pid $SERVER_PID is no longer running" >&2
    return 1
  fi
  PORT="$(sed -n 's/^PORT=//p' "$TMP/port.txt")"
  TOKEN="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
}

# Wait for the server to report a job in flight. /api/pack's "busy" is the exact
# state the 409s below are asserting on, so poll that rather than inferring it
# from the SSE stream's arrival order.
wait_until_busy() {
  local port="$1" token="$2"
  for _ in $(seq 1 100); do
    curl -sf -H "X-Eval-Token: $token" "http://127.0.0.1:$port/api/pack" 2>/dev/null \
      | grep -q '"busy": true' && return 0
    sleep 0.1
  done
  echo "server never reported busy on port $port" >&2
  return 1
}

teardown() { rm -f "$TMP/claude-hold" 2>/dev/null || true; kill "$SERVER_PID" 2>/dev/null || true; pkill -9 -f "eval-server.py --draft $DRAFT " 2>/dev/null || true; rm -rf "$TMP"; }

@test "GET / serves the eval UI" {
  run curl -sf "http://127.0.0.1:$PORT/"
  printf '%s' "$output" | grep -q "Reroll whole pack"
  printf '%s' "$output" | grep -q "Approve pack"
}

@test "GET /api/pack returns manifest summary" {
  run curl -sf -H "X-Eval-Token: $TOKEN" "http://127.0.0.1:$PORT/api/pack"
  [ "$status" -eq 0 ]
  printf '%s' "$output" | grep -q '"name": "testpack"'
  printf '%s' "$output" | grep -q '"draft": true'
  printf '%s' "$output" | grep -q 'task.complete'
  printf '%s' "$output" | grep -q '"prompts_present"'
}

@test "GET /sounds serves wav bytes" {
  run curl -sf -o "$TMP/got.wav" "http://127.0.0.1:$PORT/sounds/done.wav"
  [ "$status" -eq 0 ]
  head -c4 "$TMP/got.wav" | grep -q RIFF
}

@test "GET /sounds blocks path traversal (B6, path-as-is so the request actually reaches the handler)" {
  # curl silently collapses `../` client-side before ever sending the request
  # unless told not to, which is why the ORIGINAL version of this test never
  # exercised the server's own ".." guard at all (mutation-proof below).
  run curl -s --path-as-is -o "$TMP/traversal.out" -w "%{http_code}" \
      "http://127.0.0.1:$PORT/sounds/../openpeon.json"
  [ "$output" = "404" ]
  # Confirm the manifest (which contains the draft stamp) never made it out.
  ! grep -q x_openpeon_draft "$TMP/traversal.out" 2>/dev/null
}

@test "lockfile records port, pid, and a token" {
  run cat "$DRAFT/.eval-server.json"
  printf '%s' "$output" | grep -q "\"port\": $PORT"
  printf '%s' "$output" | grep -q '"token"'
}

@test "GET /sounds strips cache-busting query string" {
  run curl -sf -o "$TMP/got-q.wav" "http://127.0.0.1:$PORT/sounds/done.wav?t=123"
  [ "$status" -eq 0 ]
  head -c4 "$TMP/got-q.wav" | grep -q RIFF
}

@test "GET /sounds blocks symlink escape to a file that actually exists outside sounds/ (B6)" {
  # The ORIGINAL version of this test symlinked to a target that was never
  # created, so the 404 it observed came from a plain isfile() miss, not from
  # the realpath-containment guard actually firing (mutation-proof below).
  echo "top secret outside content" > "$TMP/outside-secret.txt"
  ln -s "$TMP/outside-secret.txt" "$DRAFT/sounds/escape.wav"
  run curl -s -o "$TMP/escape.out" -w "%{http_code}" "http://127.0.0.1:$PORT/sounds/escape.wav"
  [ "$output" = "404" ]
  ! grep -q "top secret" "$TMP/escape.out" 2>/dev/null
}

@test "GET /sounds serves a legitimate symlink INSIDE sounds/ (B6 positive case)" {
  # The containment guard must not over-block a symlink that stays inside
  # sounds/ — only escapes should 404.
  cp "$DRAFT/sounds/done.wav" "$DRAFT/sounds/real.wav"
  ln -s "$DRAFT/sounds/real.wav" "$DRAFT/sounds/alias.wav"
  run curl -sf -o "$TMP/alias.wav" "http://127.0.0.1:$PORT/sounds/alias.wav"
  [ "$status" -eq 0 ]
  head -c4 "$TMP/alias.wav" | grep -q RIFF
}

@test "lockfile is removed on SIGTERM" {
  kill -TERM "$SERVER_PID"
  sleep 0.5
  [ ! -f "$DRAFT/.eval-server.json" ]
}

# ---- B1: token/origin/host defense -----------------------------------------

@test "B1: GET /api/pack with no token is 403" {
  run curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/api/pack"
  [ "$output" = "403" ]
}

@test "B1: GET /api/pack with a wrong token is 403" {
  run curl -s -o /dev/null -w "%{http_code}" -H "X-Eval-Token: not-the-real-token" "http://127.0.0.1:$PORT/api/pack"
  [ "$output" = "403" ]
}

@test "B1: GET /api/pack with the token as a query param succeeds (EventSource bootstrap path)" {
  run curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/api/pack?t=$TOKEN"
  [ "$output" = "200" ]
}

@test "B1: POST /api/approve with the exact proven exploit (wrong content-type + cross-origin, but a valid token) is still 403" {
  # Proven live: POST /api/approve -H "content-type: text/plain" -H "Origin:
  # https://evil.example" used to return 200 and approve+install the pack.
  run curl -s -o /dev/null -w "%{http_code}" -X POST \
      -H "X-Eval-Token: $TOKEN" -H "content-type: text/plain" -H "Origin: https://evil.example" \
      -d '{"install":true}' "http://127.0.0.1:$PORT/api/approve"
  [ "$output" = "403" ]
  # The draft must still be sitting right where it was — never approved.
  [ -d "$DRAFT" ]
  grep -q x_openpeon_draft "$DRAFT/openpeon.json"
}

@test "B1: GET /api/pack with a forged Host header (DNS rebinding) is 403" {
  run curl -s -o /dev/null -w "%{http_code}" -H "Host: evil.example" -H "X-Eval-Token: $TOKEN" \
      "http://127.0.0.1:$PORT/api/pack"
  [ "$output" = "403" ]
}

@test "B1: POST /api/reroll with correct token/content-type/same-origin succeeds (202)" {
  run curl -s -o /dev/null -w "%{http_code}" -X POST -H "X-Eval-Token: $TOKEN" -H "content-type: application/json" \
      -d '{"scope":"pack","caption":"x"}' "http://127.0.0.1:$PORT/api/reroll"
  [ "$output" = "202" ]
}

# ---- B2: manifest `name` is not a trusted write path -----------------------

@test "B2: approve with name=../victim/pwned (path traversal) never relocates the pack outside the approved root" {
  # Proven live: this exact name relocated the pack OUTSIDE the approved root
  # (200 OK). Fix behavior: an invalid name falls back to the draft dir's own
  # (re-validated) basename rather than being trusted verbatim, so approve can
  # still legitimately succeed — just never at/under the attacker-chosen path.
  APPROVED="$TMP/approved"
  python3 -c "
import json
p = '$DRAFT/openpeon.json'
m = json.load(open(p))
m['name'] = '../victim/pwned'
json.dump(m, open(p, 'w'))
"
  PEON_APPROVED_DIR="$APPROVED" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/portB2a.txt" &
  SVB2A=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/portB2a.txt" 2>/dev/null && break; sleep 0.1; done
  PB2A="$(sed -n 's/^PORT=//p' "$TMP/portB2a.txt")"
  TB2A="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  run curl -s -o "$TMP/b2a.out" -w "%{http_code}" -X POST -H "X-Eval-Token: $TB2A" -H "content-type: application/json" \
      -d '{"install":false}' "http://127.0.0.1:$PB2A/api/approve"
  # The proven exploit: a pack landing OUTSIDE the approved root entirely.
  [ ! -d "$TMP/victim" ]
  [ ! -e "$(dirname "$APPROVED")/victim" ]
  # Whatever the response, any path it reports as "approved" must resolve
  # inside the approved root — never a sibling/parent escape.
  if [ "$output" = "200" ]; then
    approved_path="$(python3 -c "import json; print(json.load(open('$TMP/b2a.out'))['approved'])")"
    case "$approved_path" in
      "$APPROVED"/*) : ;;
      *) return 1 ;;
    esac
  else
    [ "$output" != "200" ]
  fi
  kill "$SVB2A" 2>/dev/null || true
}

@test "B2: approve with name=../victim/pwned normalizes the manifest's own name field too, not just the write path" {
  # Proven live: the write path was safely re-derived from the draft dir's
  # basename, but the manifest written to openpeon.json still carried the
  # attacker's original '../victim/pwned' name — directory identity and
  # manifest identity diverged. Fix: the manifest's name field must equal
  # the same normalized value used for the path.
  APPROVED="$TMP/approved"
  python3 -c "
import json
p = '$DRAFT/openpeon.json'
m = json.load(open(p))
m['name'] = '../victim/pwned'
json.dump(m, open(p, 'w'))
"
  PEON_APPROVED_DIR="$APPROVED" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/portB2m.txt" &
  SVB2M=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/portB2m.txt" 2>/dev/null && break; sleep 0.1; done
  PB2M="$(sed -n 's/^PORT=//p' "$TMP/portB2m.txt")"
  TB2M="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  run curl -s -o "$TMP/b2m.out" -w "%{http_code}" -X POST -H "X-Eval-Token: $TB2M" -H "content-type: application/json" \
      -d '{"install":false}' "http://127.0.0.1:$PB2M/api/approve"
  [ "$output" = "200" ]
  approved_path="$(python3 -c "import json; print(json.load(open('$TMP/b2m.out'))['approved'])")"
  manifest_name="$(python3 -c "import json; print(json.load(open('$approved_path/openpeon.json'))['name'])")"
  [ "$manifest_name" != "../victim/pwned" ]
  [ "$manifest_name" = "draft" ]
  kill "$SVB2M" 2>/dev/null || true
}

@test "B2: approve with name=/abs/path/ESCAPE (absolute path) never relocates the pack to that absolute path" {
  APPROVED="$TMP/approved"
  python3 -c "
import json
p = '$DRAFT/openpeon.json'
m = json.load(open(p))
m['name'] = '/abs/path/ESCAPE'
json.dump(m, open(p, 'w'))
"
  PEON_APPROVED_DIR="$APPROVED" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/portB2b.txt" &
  SVB2B=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/portB2b.txt" 2>/dev/null && break; sleep 0.1; done
  PB2B="$(sed -n 's/^PORT=//p' "$TMP/portB2b.txt")"
  TB2B="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  run curl -s -o "$TMP/b2b.out" -w "%{http_code}" -X POST -H "X-Eval-Token: $TB2B" -H "content-type: application/json" \
      -d '{"install":false}' "http://127.0.0.1:$PB2B/api/approve"
  [ ! -e "/abs/path/ESCAPE" ]
  if [ "$output" = "200" ]; then
    approved_path="$(python3 -c "import json; print(json.load(open('$TMP/b2b.out'))['approved'])")"
    case "$approved_path" in
      "$APPROVED"/*) : ;;
      *) return 1 ;;
    esac
  else
    [ "$output" != "200" ]
  fi
  kill "$SVB2B" 2>/dev/null || true
}

@test "B2: a legitimate name still approves normally" {
  APPROVED="$TMP/approved"
  PEON_APPROVED_DIR="$APPROVED" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/portB2c.txt" &
  SVB2C=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/portB2c.txt" 2>/dev/null && break; sleep 0.1; done
  PB2C="$(sed -n 's/^PORT=//p' "$TMP/portB2c.txt")"
  TB2C="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  run curl -s -o "$TMP/b2c.out" -w "%{http_code}" -X POST -H "X-Eval-Token: $TB2C" -H "content-type: application/json" \
      -d '{"install":false}' "http://127.0.0.1:$PB2C/api/approve"
  [ "$output" = "200" ]
  [ -f "$APPROVED/testpack/openpeon.json" ]
  kill "$SVB2C" 2>/dev/null || true
}

# ---- B5: approve refuses anything that isn't stamped as a draft ------------

@test "B5: approve on a manifest with no x_openpeon_draft stamp is 409 not-a-draft, and nothing moves" {
  APPROVED="$TMP/approved"
  python3 -c "
import json
p = '$DRAFT/openpeon.json'
m = json.load(open(p))
m.pop('x_openpeon_draft', None)
json.dump(m, open(p, 'w'))
"
  PEON_APPROVED_DIR="$APPROVED" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/portB5.txt" &
  SVB5=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/portB5.txt" 2>/dev/null && break; sleep 0.1; done
  PB5="$(sed -n 's/^PORT=//p' "$TMP/portB5.txt")"
  TB5="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  run curl -s -o "$TMP/b5.out" -w "%{http_code}" -X POST -H "X-Eval-Token: $TB5" -H "content-type: application/json" \
      -d '{"install":false}' "http://127.0.0.1:$PB5/api/approve"
  [ "$output" = "409" ]
  grep -q "not a draft" "$TMP/b5.out"
  [ -d "$DRAFT" ]
  [ ! -d "$APPROVED" ] || [ ! -e "$APPROVED/testpack" ]
  kill "$SVB5" 2>/dev/null || true
}

@test "reroll spawns claude, writes job file, emits done" {
  curl -sf -N "http://127.0.0.1:$PORT/api/events?t=$TOKEN" > "$TMP/sse.txt" &
  SSE_PID=$!
  sleep 0.2
  run curl -sf -X POST -H "X-Eval-Token: $TOKEN" -H "content-type: application/json" \
      -d '{"scope":"sound","category":"task.complete","index":0,"caption":"warmer"}' \
      "http://127.0.0.1:$PORT/api/reroll"
  printf '%s' "$output" | grep -q '"job"'
  for _ in $(seq 1 50); do grep -q '"done"' "$TMP/sse.txt" 2>/dev/null && break; sleep 0.1; done
  kill "$SSE_PID" 2>/dev/null || true
  grep -q '"started"' "$TMP/sse.txt"
  grep -q '"done"' "$TMP/sse.txt"
  ls "$DRAFT/jobs/" | grep -q '.json'
  grep -q '"caption": "warmer"' "$DRAFT"/jobs/*.json
}

@test "reroll requires known category and in-range index for scope=sound" {
  run curl -s -o /dev/null -w "%{http_code}" -X POST -H "X-Eval-Token: $TOKEN" -H "content-type: application/json" \
      -d '{"scope":"sound","category":"no.such.category","index":0,"caption":"x"}' \
      "http://127.0.0.1:$PORT/api/reroll"
  [ "$output" = "400" ]
  run curl -s -o /dev/null -w "%{http_code}" -X POST -H "X-Eval-Token: $TOKEN" -H "content-type: application/json" \
      -d '{"scope":"sound","category":"task.complete","index":99,"caption":"x"}' \
      "http://127.0.0.1:$PORT/api/reroll"
  [ "$output" = "400" ]
}

@test "reroll returns 409 while a job is busy" {
  # Hold the job open, then wait on the server's own busy flag. Waiting on the
  # SSE "started" line instead made this a race: curl buffers the stream when
  # its stdout is a file, so "started" could surface only once "done" pushed it
  # through, by which point the job was over and the second POST got 202.
  touch "$TMP/claude-hold"
  curl -sf -N "http://127.0.0.1:$PORT/api/events?t=$TOKEN" > "$TMP/sse.txt" &
  SSE_PID=$!
  sleep 0.2
  run curl -sf -X POST -H "X-Eval-Token: $TOKEN" -H "content-type: application/json" \
      -d '{"scope":"pack","caption":"softer"}' "http://127.0.0.1:$PORT/api/reroll"
  printf '%s' "$output" | grep -q '"job"'
  wait_until_busy "$PORT" "$TOKEN"
  run curl -s -o /dev/null -w "%{http_code}" -X POST -H "X-Eval-Token: $TOKEN" -H "content-type: application/json" \
      -d '{"scope":"pack","caption":"softer again"}' "http://127.0.0.1:$PORT/api/reroll"
  rm -f "$TMP/claude-hold"
  [ "$output" = "409" ]
  for _ in $(seq 1 100); do grep -q '"done"' "$TMP/sse.txt" 2>/dev/null && break; sleep 0.1; done
  kill "$SSE_PID" 2>/dev/null || true
}

@test "failed claude run emits failed with detail" {
  FAKE_CLAUDE_FAIL=1 python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/port2.txt" &
  SERVER_PID2=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/port2.txt" 2>/dev/null && break; sleep 0.1; done
  PORT2="$(sed -n 's/^PORT=//p' "$TMP/port2.txt")"
  TOKEN2="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  curl -sf -N "http://127.0.0.1:$PORT2/api/events?t=$TOKEN2" > "$TMP/sse2.txt" &
  SSE_PID2=$!
  sleep 0.2
  run curl -sf -X POST -H "X-Eval-Token: $TOKEN2" -H "content-type: application/json" \
      -d '{"scope":"pack","caption":"all softer"}' "http://127.0.0.1:$PORT2/api/reroll"
  printf '%s' "$output" | grep -q '"job"'
  for _ in $(seq 1 50); do grep -q '"failed"' "$TMP/sse2.txt" 2>/dev/null && break; sleep 0.1; done
  kill "$SSE_PID2" 2>/dev/null || true
  kill "$SERVER_PID2" 2>/dev/null || true
  grep -q '"failed"' "$TMP/sse2.txt"
  grep -q 'boom' "$TMP/sse2.txt"
}

@test "B3: a reroll whose claude exits 0 but writes nothing reports failed, not done" {
  cat > "$TMP/noop-claude" <<'EOF'
#!/usr/bin/env bash
# Simulates the proven bug: a `claude -p` under a restrictive permission mode
# that refuses every write, but still exits 0.
exit 0
EOF
  chmod +x "$TMP/noop-claude"
  python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/noop-claude" --no-open --print-port > "$TMP/port3b.txt" &
  SERVER_PID3B=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/port3b.txt" 2>/dev/null && break; sleep 0.1; done
  PORT3B="$(sed -n 's/^PORT=//p' "$TMP/port3b.txt")"
  TOKEN3B="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  curl -sf -N "http://127.0.0.1:$PORT3B/api/events?t=$TOKEN3B" > "$TMP/sse3b.txt" &
  SSE_PID3B=$!
  sleep 0.2
  BEFORE_SIZE="$(wc -c < "$DRAFT/sounds/done.wav")"
  run curl -sf -X POST -H "X-Eval-Token: $TOKEN3B" -H "content-type: application/json" \
      -d '{"scope":"sound","category":"task.complete","index":0,"caption":"warmer"}' \
      "http://127.0.0.1:$PORT3B/api/reroll"
  printf '%s' "$output" | grep -q '"job"'
  for _ in $(seq 1 50); do grep -q '"failed"' "$TMP/sse3b.txt" 2>/dev/null && break; sleep 0.1; done
  kill "$SSE_PID3B" 2>/dev/null || true
  kill "$SERVER_PID3B" 2>/dev/null || true
  grep -q '"failed"' "$TMP/sse3b.txt"
  ! grep -q '"done"' "$TMP/sse3b.txt"
  grep -q "lacked write permission" "$TMP/sse3b.txt"
  AFTER_SIZE="$(wc -c < "$DRAFT/sounds/done.wav")"
  [ "$BEFORE_SIZE" -eq "$AFTER_SIZE" ]
}

@test "B3(a): reroll spawns claude with cwd=DRAFT and --add-dir for DRAFT and PEON_DIR" {
  mkdir -p "$TMP/peondir"
  PEON_DIR_REAL="$(cd "$TMP/peondir" && pwd -P)"
  DRAFT_REAL="$(cd "$DRAFT" && pwd -P)"
  cat > "$TMP/argv-claude" <<'PYEOF'
#!/usr/bin/env python3
import os, sys
with open(os.environ["ARGV_LOG"], "w") as f:
    f.write("PWD=" + os.getcwd() + "\n")
    f.write("ARGS=" + " ".join(sys.argv[1:]) + "\n")
sys.exit(0)
PYEOF
  chmod +x "$TMP/argv-claude"
  ARGV_LOG="$TMP/argv.log" PEON_DIR="$TMP/peondir" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/argv-claude" --no-open --print-port > "$TMP/port3a.txt" &
  SERVER_PID3A=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/port3a.txt" 2>/dev/null && break; sleep 0.1; done
  PORT3A="$(sed -n 's/^PORT=//p' "$TMP/port3a.txt")"
  TOKEN3A="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  curl -sf -N "http://127.0.0.1:$PORT3A/api/events?t=$TOKEN3A" > "$TMP/sse3a.txt" &
  SSE_PID3A=$!
  sleep 0.2
  run curl -sf -X POST -H "X-Eval-Token: $TOKEN3A" -H "content-type: application/json" \
      -d '{"scope":"pack","caption":"x"}' "http://127.0.0.1:$PORT3A/api/reroll"
  for _ in $(seq 1 50); do [ -s "$TMP/argv.log" ] && break; sleep 0.1; done
  kill "$SSE_PID3A" 2>/dev/null || true
  kill "$SERVER_PID3A" 2>/dev/null || true
  grep -q "PWD=$DRAFT_REAL" "$TMP/argv.log"
  grep -q -- "--add-dir $DRAFT" "$TMP/argv.log"
  grep -q -- "--add-dir $TMP/peondir" "$TMP/argv.log"
}

@test "concurrent reroll POSTs: exactly one 202, rest 409, one job file" {
  # Hold the accepted job open for the duration of the race. Ten curls do not
  # land simultaneously: each is a process spawn, and on a loaded runner the
  # last can arrive after a job that finishes in the time it takes to append one
  # byte per wav. The server is then idle again and hands out a second 202,
  # which is correct behaviour and a failed assertion. Holding the job makes
  # "exactly one wins" the thing actually under test.
  touch "$TMP/claude-hold"

  # NOTE: wait on the explicit PIDs, not a bare `wait` — a bare `wait` blocks on
  # every background job in this shell, including setup()'s long-lived SERVER_PID
  # (eval-server.py runs serve_forever() until SIGTERM), which would hang forever.
  pids=()
  for i in $(seq 1 10); do
    curl -s -o "$TMP/body_$i.txt" -w "%{http_code}" -X POST -H "X-Eval-Token: $TOKEN" -H "content-type: application/json" \
        -d '{"scope":"pack","caption":"softer"}' \
        "http://127.0.0.1:$PORT/api/reroll" > "$TMP/code_$i.txt" &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do wait "$pid"; done
  rm -f "$TMP/claude-hold"
  count_202=0
  count_409=0
  for i in $(seq 1 10); do
    code="$(cat "$TMP/code_$i.txt")"
    [ "$code" = "202" ] && count_202=$((count_202 + 1))
    [ "$code" = "409" ] && count_409=$((count_409 + 1))
  done
  [ "$count_202" -eq 1 ]
  [ "$count_409" -eq 9 ]
  for _ in $(seq 1 50); do [ -d "$DRAFT/jobs" ] && [ -n "$(ls -A "$DRAFT/jobs" 2>/dev/null)" ] && break; sleep 0.1; done
  job_count="$(ls "$DRAFT/jobs" | grep -c '\.json$')"
  [ "$job_count" -eq 1 ]
}

@test "SIGTERM during a job terminates the running claude process tree" {
  cat > "$TMP/slow-claude" <<'EOF'
#!/usr/bin/env bash
echo $$ > "$SLOW_PID_FILE"
sleep 30
EOF
  chmod +x "$TMP/slow-claude"
  SLOW_PID_FILE="$TMP/slow.pid" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/slow-claude" --no-open --print-port > "$TMP/port3.txt" &
  SERVER_PID3=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/port3.txt" 2>/dev/null && break; sleep 0.1; done
  PORT3="$(sed -n 's/^PORT=//p' "$TMP/port3.txt")"
  TOKEN3="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  run curl -sf -X POST -H "X-Eval-Token: $TOKEN3" -H "content-type: application/json" \
      -d '{"scope":"pack","caption":"x"}' "http://127.0.0.1:$PORT3/api/reroll"
  printf '%s' "$output" | grep -q '"job"'
  for _ in $(seq 1 50); do [ -f "$TMP/slow.pid" ] && break; sleep 0.1; done
  SLOW_PID="$(cat "$TMP/slow.pid")"
  kill -0 "$SLOW_PID"   # sanity: it's actually running
  kill -TERM "$SERVER_PID3"
  for _ in $(seq 1 20); do kill -0 "$SLOW_PID" 2>/dev/null || break; sleep 0.1; done
  run kill -0 "$SLOW_PID"
  [ "$status" -ne 0 ]
  kill "$SERVER_PID3" 2>/dev/null || true
}

@test "approve strips stamp, moves pack, shuts down" {
  APPROVED="$TMP/approved"
  echo '[{"job":"seed"}]' > "$DRAFT/eval-log.json"
  # PEON_APPROVED_DIR must be in the SERVER's env, not just the test's — start a
  # dedicated server instance, following the pattern the failed-claude test uses.
  PEON_APPROVED_DIR="$APPROVED" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/port4.txt" &
  SERVER_PID4=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/port4.txt" 2>/dev/null && break; sleep 0.1; done
  PORT4="$(sed -n 's/^PORT=//p' "$TMP/port4.txt")"
  TOKEN4="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  run curl -sf -X POST -H "X-Eval-Token: $TOKEN4" -H "content-type: application/json" \
      -d '{"install":false}' "http://127.0.0.1:$PORT4/api/approve"
  printf '%s' "$output" | grep -q '"approved"'
  printf '%s' "$output" | grep -q '"installed": false'
  [ -f "$APPROVED/testpack/openpeon.json" ]
  ! grep -q x_openpeon_draft "$APPROVED/testpack/openpeon.json"
  [ ! -d "$APPROVED/testpack/jobs" ]
  [ ! -f "$APPROVED/testpack/.eval-server.json" ]
  [ -f "$APPROVED/testpack/eval-log.json" ]
  grep -q '"job":"seed"' "$APPROVED/testpack/eval-log.json"
  [ ! -d "$DRAFT" ] || [ ! -f "$DRAFT/openpeon.json" ]
  sleep 1.5
  run curl -s -o /dev/null -w "%{http_code}" --max-time 2 -H "X-Eval-Token: $TOKEN4" "http://127.0.0.1:$PORT4/api/pack"
  [ "$output" != "200" ]
  kill "$SERVER_PID4" 2>/dev/null || true
}

@test "R13: approve prunes stray render-job-*.json scratch files at the draft root" {
  # A pack created before the create-pack/remix skills moved their render
  # inputs under jobs/ can still have junk at the draft root; approve must
  # prune it so approved packs don't ship it.
  echo '{"type":"sfx","prompt":"x","out":"x.wav"}' > "$DRAFT/render-job-task_complete_0.json"
  echo '{"type":"sfx","prompt":"y","out":"y.wav"}' > "$DRAFT/render-job.json"
  APPROVED="$TMP/approved"
  PEON_APPROVED_DIR="$APPROVED" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/portR13.txt" &
  SVR13=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/portR13.txt" 2>/dev/null && break; sleep 0.1; done
  PR13="$(sed -n 's/^PORT=//p' "$TMP/portR13.txt")"
  TR13="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  run curl -sf -X POST -H "X-Eval-Token: $TR13" -H "content-type: application/json" \
      -d '{"install":false}' "http://127.0.0.1:$PR13/api/approve"
  [ -f "$APPROVED/testpack/openpeon.json" ]
  [ ! -f "$APPROVED/testpack/render-job-task_complete_0.json" ]
  [ ! -f "$APPROVED/testpack/render-job.json" ]
  kill "$SVR13" 2>/dev/null || true
}

@test "approve with install:true copies the pack into PEON_DIR" {
  APPROVED="$TMP/approved"
  INSTALLED="$TMP/installed"
  PEON_APPROVED_DIR="$APPROVED" PEON_DIR="$INSTALLED" \
      python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/port5.txt" &
  SERVER_PID5=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/port5.txt" 2>/dev/null && break; sleep 0.1; done
  PORT5="$(sed -n 's/^PORT=//p' "$TMP/port5.txt")"
  TOKEN5="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  run curl -sf -X POST -H "X-Eval-Token: $TOKEN5" -H "content-type: application/json" \
      -d '{"install":true}' "http://127.0.0.1:$PORT5/api/approve"
  printf '%s' "$output" | grep -q '"approved"'
  printf '%s' "$output" | grep -q '"installed": true'
  [ -f "$APPROVED/testpack/openpeon.json" ]
  [ -f "$INSTALLED/packs/testpack/openpeon.json" ]
  ! grep -q x_openpeon_draft "$INSTALLED/packs/testpack/openpeon.json"
  kill "$SERVER_PID5" 2>/dev/null || true
}

@test "R11: a failed install does not strand the request — approve still responds and shuts down" {
  APPROVED="$TMP/approved"
  # PEON_DIR points at a plain FILE, not a directory, so the install
  # copytree's target creation is guaranteed to raise.
  BROKEN_PEON_DIR="$TMP/not-a-dir"
  echo "not a directory" > "$BROKEN_PEON_DIR"
  PEON_APPROVED_DIR="$APPROVED" PEON_DIR="$BROKEN_PEON_DIR" \
      python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/portR11.txt" &
  SVR11=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/portR11.txt" 2>/dev/null && break; sleep 0.1; done
  PR11="$(sed -n 's/^PORT=//p' "$TMP/portR11.txt")"
  TR11="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  run curl -sf -o "$TMP/r11.out" -w "%{http_code}" -X POST -H "X-Eval-Token: $TR11" -H "content-type: application/json" \
      -d '{"install":true}' "http://127.0.0.1:$PR11/api/approve"
  # The move must have succeeded (draft gone, pack in the approved root) even
  # though the install failed — and a real HTTP response must have been sent.
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
  grep -q '"approved"' "$TMP/r11.out"
  grep -q '"installed": false' "$TMP/r11.out"
  grep -q '"install_error"' "$TMP/r11.out"
  [ -f "$APPROVED/testpack/openpeon.json" ]
  [ ! -d "$DRAFT" ]
  # Server must still self-shut-down normally (not left hanging on a crash).
  sleep 1.5
  run curl -s -o /dev/null -w "%{http_code}" --max-time 2 -H "X-Eval-Token: $TR11" "http://127.0.0.1:$PR11/api/pack"
  [ "$output" != "200" ]
  kill "$SVR11" 2>/dev/null || true
}

@test "approve returns 409 exists when the target already exists" {
  APPROVED="$TMP/approved"
  mkdir -p "$APPROVED/testpack"
  PEON_APPROVED_DIR="$APPROVED" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/port6.txt" &
  SERVER_PID6=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/port6.txt" 2>/dev/null && break; sleep 0.1; done
  PORT6="$(sed -n 's/^PORT=//p' "$TMP/port6.txt")"
  TOKEN6="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  run curl -s -o "$TMP/approve-exists.json" -w "%{http_code}" -X POST -H "X-Eval-Token: $TOKEN6" -H "content-type: application/json" \
      -d '{"install":false}' "http://127.0.0.1:$PORT6/api/approve"
  [ "$output" = "409" ]
  grep -q '"error": "exists"' "$TMP/approve-exists.json"
  [ -d "$DRAFT" ]
  # short-circuited before any mutation — draft's manifest and lockfile are untouched
  grep -q x_openpeon_draft "$DRAFT/openpeon.json"
  [ -f "$DRAFT/.eval-server.json" ]
  # server is still alive (not the shutdown path) — a normal GET still works
  run curl -s -o /dev/null -w "%{http_code}" -H "X-Eval-Token: $TOKEN6" "http://127.0.0.1:$PORT6/api/pack"
  [ "$output" = "200" ]
  kill "$SERVER_PID6" 2>/dev/null || true
}

@test "approve returns 409 busy while a reroll job is in flight" {
  APPROVED="$TMP/approved"
  touch "$TMP/claude-hold"
  PEON_APPROVED_DIR="$APPROVED" PEON_TEST_HOLD="$TMP/claude-hold" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
      --draft "$DRAFT" --claude-bin "$TMP/fake-claude" --no-open --print-port > "$TMP/port7.txt" &
  SERVER_PID7=$!
  for _ in $(seq 1 50); do grep -q PORT= "$TMP/port7.txt" 2>/dev/null && break; sleep 0.1; done
  PORT7="$(sed -n 's/^PORT=//p' "$TMP/port7.txt")"
  TOKEN7="$(python3 -c "import json; print(json.load(open('$DRAFT/.eval-server.json'))['token'])")"
  curl -sf -N "http://127.0.0.1:$PORT7/api/events?t=$TOKEN7" > "$TMP/sse7.txt" &
  SSE_PID7=$!
  sleep 0.2
  run curl -sf -X POST -H "X-Eval-Token: $TOKEN7" -H "content-type: application/json" \
      -d '{"scope":"pack","caption":"softer"}' "http://127.0.0.1:$PORT7/api/reroll"
  printf '%s' "$output" | grep -q '"job"'
  wait_until_busy "$PORT7" "$TOKEN7"
  run curl -s -o /dev/null -w "%{http_code}" -X POST -H "X-Eval-Token: $TOKEN7" -H "content-type: application/json" \
      -d '{"install":false}' "http://127.0.0.1:$PORT7/api/approve"
  rm -f "$TMP/claude-hold"
  [ "$output" = "409" ]
  [ -d "$DRAFT" ]
  for _ in $(seq 1 100); do grep -q '"done"' "$TMP/sse7.txt" 2>/dev/null && break; sleep 0.1; done
  kill "$SSE_PID7" 2>/dev/null || true
  kill "$SERVER_PID7" 2>/dev/null || true
}
