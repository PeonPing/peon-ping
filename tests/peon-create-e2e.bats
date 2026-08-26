#!/usr/bin/env bats
# End-to-end: create -> draft on disk -> eval server serves it -> approve finalizes.

setup() {
  TMP="$(mktemp -d)"; export HOME="$TMP"
  cat > "$TMP/fake-claude" <<EOF
#!/usr/bin/env bash
# stands in for 'claude -p <create prompt>': author a 1-category draft via the real renderer in mock mode
D="\$HOME/.peon-ping/drafts/calmtest"
mkdir -p "\$D/sounds"
cat > "\$D/openpeon.json" <<'EOJ'
{"cesp_version":"1.0","name":"calmtest","version":"0.0.1","x_openpeon_draft":true,
 "categories":{"task.complete":{"sounds":[{"file":"sounds/task_complete_0.wav","label":"Done"}]}}}
EOJ
cat > "\$D/prompts.json" <<'EOJ'
{"sounds/task_complete_0.wav":{"type":"sfx","prompt":"two gentle bells"}}
EOJ
echo '{"type":"sfx","prompt":"two gentle bells","out":"'"\$D"'/sounds/task_complete_0.wav"}' > "\$D/j.json"
python3 "$BATS_TEST_DIRNAME/../scripts/pack-render.py" --job "\$D/j.json" --mock
EOF
  chmod +x "$TMP/fake-claude"
}
teardown() {
  # Defensive: if a test failed before reaping its eval-server, don't leave it
  # running (it holds this process's stdout/stderr open, which can hang a
  # `bats ... | something` pipeline indefinitely).
  [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null || true
  rm -rf "$TMP"
}

@test "create -> eval -> approve pipeline (all mock, no network)" {
  PEON_CLAUDE_BIN="$TMP/fake-claude" PEON_EVAL_NO_OPEN=1 PEON_EVAL_DRY_RUN=1 \
    run bash "$BATS_TEST_DIRNAME/../peon.sh" create --name calmtest --flavor sfx --vibe "calm bells"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.peon-ping/drafts/calmtest/sounds/task_complete_0.wav" ]
  grep -q x_openpeon_draft "$HOME/.peon-ping/drafts/calmtest/openpeon.json"

  # R8: `create` must actually HAND OFF to the eval code path, not merely claim
  # success. Proven regression: swapping `exec "$0" eval "$CREATE_NAME"` for
  # `exit 0` kept this test green before this assertion existed. The dry-run
  # command line printed by the eval path must be the real eval-server
  # invocation targeting THIS draft.
  # NOTE: uses `grep -q`, not a bare `[[ ... ]]` — this machine's bash (3.2,
  # macOS system bash)'s ERR trap does not fire for a failing bare `[[ ]]`.
  # A bare `[[ "$output" == *pat* ]]` here is NOT the last statement in this
  # test body, so a failing one would silently never gate the test (bats only
  # catches a non-final bare `[[ ]]` failure when it's the body's last
  # statement). Verified empirically: mutating this to a failing non-final
  # bare-`[[ ]]` condition still reports `ok`. `grep -q` is a real
  # external/simple command, so its failure correctly fails the test in
  # either position.
  printf '%s' "$output" | grep -q "eval-server.py"
  printf '%s' "$output" | grep -q "drafts/calmtest"

  # now really serve it and approve
  PEON_APPROVED_DIR="$HOME/.peon-ping/packs" python3 "$BATS_TEST_DIRNAME/../scripts/eval-server.py" \
    --draft "$HOME/.peon-ping/drafts/calmtest" --no-open --print-port --claude-bin /usr/bin/true > "$TMP/port.txt" 2> "$TMP/server.err" &
  SERVER_PID=$!
  # Same wait budget and diagnostics as tests/eval-server.bats: wait on the
  # lockfile as well as the port line, and report a stalled startup instead of
  # letting it surface as a missing .eval-server.json further down.
  for _ in $(seq 1 300); do
    grep -q PORT= "$TMP/port.txt" 2>/dev/null && [ -f "$HOME/.peon-ping/drafts/calmtest/.eval-server.json" ] && break
    sleep 0.1
  done
  if ! grep -q PORT= "$TMP/port.txt" 2>/dev/null; then
    echo "eval-server did not come up within 30s" >&2
    cat "$TMP/port.txt" "$TMP/server.err" >&2
    return 1
  fi
  PORT="$(sed -n 's/^PORT=//p' "$TMP/port.txt")"
  TOKEN="$(python3 -c "import json; print(json.load(open('$HOME/.peon-ping/drafts/calmtest/.eval-server.json'))['token'])")"
  run curl -sf -X POST -H "X-Eval-Token: $TOKEN" -H "content-type: application/json" \
      -d '{"install":false}' "http://127.0.0.1:$PORT/api/approve"
  [ -f "$HOME/.peon-ping/packs/calmtest/openpeon.json" ]
  ! grep -q x_openpeon_draft "$HOME/.peon-ping/packs/calmtest/openpeon.json"
  wait "$SERVER_PID" 2>/dev/null || true
}
