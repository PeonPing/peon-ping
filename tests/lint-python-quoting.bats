#!/usr/bin/env bats

# Regression tests for bash double-quoting hazards in python3 -c blocks.
# Prevents reintroduction of the bug class fixed in card dsmh31, where
# patterns like data["key"] or d.get("key") inside python3 -c "..." strings
# cause bash to prematurely close the double-quoted argument.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LINT_SCRIPT="$REPO_ROOT/scripts/lint-python-quoting.sh"

@test "lint-python-quoting.sh exists and is executable" {
  [ -f "$LINT_SCRIPT" ]
  [ -x "$LINT_SCRIPT" ]
}

@test "peon.sh has no python3 -c bash quoting hazards" {
  run bash "$LINT_SCRIPT" "$REPO_ROOT/peon.sh"
  [ "$status" -eq 0 ]
}

@test "lint detects dict subscript quoting hazard: data[\"key\"]" {
  local tmpfile="$BATS_TMPDIR/bad-subscript.sh"
  cat > "$tmpfile" << 'BADEOF'
#!/usr/bin/env bash
result=$(python3 -c "import json; d=json.loads('{}'); print(d["a"])")
BADEOF
  run bash "$LINT_SCRIPT" "$tmpfile"
  [ "$status" -eq 1 ]
  [[ "$output" == *'["'* ]]
}

@test "lint detects .get() quoting hazard: d.get(\"key\")" {
  local tmpfile="$BATS_TMPDIR/bad-get.sh"
  cat > "$tmpfile" << 'BADEOF'
#!/usr/bin/env bash
result=$(python3 -c "import json; d=json.loads('{}'); print(d.get("a", 0))")
BADEOF
  run bash "$LINT_SCRIPT" "$tmpfile"
  [ "$status" -eq 1 ]
  [[ "$output" == *'.get("'* ]]
}

@test "lint detects multi-line quoting hazard" {
  local tmpfile="$BATS_TMPDIR/bad-multiline.sh"
  cat > "$tmpfile" << 'BADEOF'
#!/usr/bin/env bash
result=$(python3 -c "
import json
data = json.loads('{}')
print(data.get("default", 0))
" 2>/dev/null)
BADEOF
  run bash "$LINT_SCRIPT" "$tmpfile"
  [ "$status" -eq 1 ]
}

@test "lint passes when python3 -c uses single quotes inside block" {
  local tmpfile="$BATS_TMPDIR/safe-single-quotes.sh"
  cat > "$tmpfile" << 'SAFEEOF'
#!/usr/bin/env bash
result=$(python3 -c "import json; d=json.loads('{}'); print(d['a'])")
result2=$(python3 -c "import json; d=json.loads('{}'); print(d.get('a', 0))")
SAFEEOF
  run bash "$LINT_SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
}

@test "lint passes when python3 -c uses env vars instead of inline data" {
  local tmpfile="$BATS_TMPDIR/safe-envvar.sh"
  cat > "$tmpfile" << 'SAFEEOF'
#!/usr/bin/env bash
result=$(PEON_ENV_DATA="$data" python3 -c "
import json, os
d = json.loads(os.environ.get('PEON_ENV_DATA', '{}'))
print(d.get('key', 0))
")
SAFEEOF
  run bash "$LINT_SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
}

@test "lint passes when python3 -c uses sys.argv" {
  local tmpfile="$BATS_TMPDIR/safe-sysargv.sh"
  cat > "$tmpfile" << 'SAFEEOF'
#!/usr/bin/env bash
result=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$title")
SAFEEOF
  run bash "$LINT_SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
}

@test "lint passes on files with no python3 -c blocks" {
  local tmpfile="$BATS_TMPDIR/no-python.sh"
  cat > "$tmpfile" << 'NOPYEOF'
#!/usr/bin/env bash
echo "hello world"
NOPYEOF
  run bash "$LINT_SCRIPT" "$tmpfile"
  [ "$status" -eq 0 ]
}

@test "all shell scripts have no python3 -c bash quoting hazards" {
  # Scan every .sh file that contains python3 -c blocks
  local files=()
  while IFS= read -r f; do
    files+=("$f")
  done < <(grep -rl 'python3 -c' "$REPO_ROOT" --include='*.sh' --exclude-dir=tests --exclude-dir=node_modules --exclude-dir=.git | grep -v 'lint-python-quoting.sh')

  [ "${#files[@]}" -gt 0 ]  # sanity: at least peon.sh should match
  run bash "$LINT_SCRIPT" "${files[@]}"
  [ "$status" -eq 0 ]
}

@test "lint reports all hazards in a single python3 -c block" {
  local tmpfile="$BATS_TMPDIR/multi-hazard.sh"
  cat > "$tmpfile" << 'BADEOF'
#!/usr/bin/env bash
result=$(python3 -c "import json; d=json.loads('{}'); print(d["a"], d.get("b", 0))")
BADEOF
  run bash "$LINT_SCRIPT" "$tmpfile"
  [ "$status" -eq 1 ]
  # Should report both the [" and .get(" hazards
  [[ "$output" == *'["'* ]]
  [[ "$output" == *'.get("'* ]]
}

@test "lint handles missing file gracefully" {
  run bash "$LINT_SCRIPT" "/tmp/nonexistent-file-$RANDOM.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
}
