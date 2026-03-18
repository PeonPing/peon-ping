#!/usr/bin/env bash
#
# lint-python-quoting.sh — Detect bash double-quoting hazards in python3 -c blocks
#
# Scans shell scripts for python3 -c "..." blocks that contain patterns which
# would break bash double-quote parsing:
#   - ["   (dict subscript with double quote, e.g. data["key"])
#   - .get(" (dict .get() with double quote, e.g. data.get("key"))
#
# These patterns cause bash to interpret the inner " as closing the python3 -c
# argument string, silently breaking the embedded Python code.
#
# Safe alternatives:
#   - Use single quotes inside the Python code: data['key'], data.get('key')
#   - Pass values via environment variables: os.environ.get('VAR')
#   - Pass values via sys.argv: sys.argv[1]
#
# Usage:
#   ./scripts/lint-python-quoting.sh [file...]
#   If no files given, defaults to peon.sh
#
# Exit codes:
#   0 — No hazards found
#   1 — Hazards detected (prints details to stderr)

set -euo pipefail

files=("${@:-peon.sh}")
exit_code=0

for file in "${files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "WARN: $file not found, skipping" >&2
    continue
  fi

  hazards=$(python3 -c '
import re, sys

filename = sys.argv[1]
with open(filename, encoding="utf-8", errors="replace") as f:
    content = f.read()

# Find python3 -c " blocks. For each, simulate bash double-quote parsing:
# walk forward from the opening " until we find an unescaped " (which bash
# treats as the closing quote). If that closing " is preceded by [ or .get(
# then someone wrote a hazardous pattern like data["key"] or d.get("key")
# where the " breaks the bash string.

pattern = re.compile(r"python3\s+-c\s+\"")
hazards = []

for m in pattern.finditer(content):
    line_num = content[:m.start()].count("\n") + 1
    start = m.end()

    # Walk to find each unescaped " (potential bash string boundary)
    i = start
    while i < len(content):
        ch = content[i]
        if ch == "\\" and i + 1 < len(content):
            i += 2  # skip escaped char
            continue
        if ch == "\"":
            # This unescaped " closes the bash double-quoted string.
            # Check if the content just before it indicates a quoting hazard.
            before = content[start:i]
            close_line = content[:i].count("\n") + 1

            # Track whether this " is a hazard site
            is_hazard = False

            # Hazard: block ends at [" — means someone wrote data["key"]
            if before.rstrip().endswith("["):
                hazards.append(
                    "  line {}: python3 -c block broken by [\" (dict subscript with double quote)".format(close_line)
                )
                is_hazard = True

            # Hazard: block ends at .get(" — means someone wrote d.get("key")
            if before.rstrip().endswith(".get("):
                hazards.append(
                    "  line {}: python3 -c block broken by .get(\" (method call with double quote)".format(close_line)
                )
                is_hazard = True

            # Also check: after this closing ", does the rest of the line
            # suggest more Python code that should have been inside the block?
            # This catches multi-fragment patterns like: data["key"]["val"]
            # where the first " closes the string and the rest is garbled.
            rest_of_line = ""
            j = i + 1
            while j < len(content) and content[j] != "\n":
                rest_of_line += content[j]
                j += 1

            # If closing " is followed by ] or ) then pattern like ["key"]
            if rest_of_line and rest_of_line.lstrip().startswith("]"):
                if before.rstrip().endswith("["):
                    pass  # already caught above
                else:
                    hazards.append(
                        "  line {}: python3 -c block has suspicious \"]  after close quote".format(close_line)
                    )
                    is_hazard = True

            if is_hazard:
                # Continue scanning for more hazards in this block
                start = i + 1
            else:
                # Clean closing " — end of python3 -c block
                break
        i += 1

if hazards:
    print("\n".join(hazards))
    sys.exit(1)
' "$file" 2>&1) || {
    echo "FAIL: $file — python3 -c bash quoting hazards detected:" >&2
    echo "$hazards" >&2
    exit_code=1
    continue
  }
done

exit $exit_code
