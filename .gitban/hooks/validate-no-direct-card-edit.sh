#!/bin/bash
# Blocks Write/Edit/Bash operations that CREATE or MODIFY .gitban/cards/ files.
# Agents must use MCP tools for card interactions instead.
# Allows: read-only commands, git staging (git add), and file deletion (rm, git rm)
# for cleanup of stale files.
# Uses grep instead of jq for portability (MSYS2/Git Bash lack jq).

INPUT=$(cat)

# Extract tool_name — match "tool_name": "VALUE"
TOOL_NAME=$(echo "$INPUT" | grep -oE '"tool_name"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')

# For Write/Edit: always block .gitban/cards/ paths
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
  if [ -n "$FILE_PATH" ] && echo "$FILE_PATH" | grep -qiE '\.gitban[/\\]cards[/\\]'; then
    echo "BLOCKED: Do not edit .gitban/cards/ files directly. Use gitban MCP tools (edit_card, append_card, create_card, etc.)." >&2
    exit 2
  fi
fi

# For Bash: block commands that CREATE or MODIFY .gitban/cards/ files
if [ "$TOOL_NAME" = "Bash" ]; then
  # Extract the command value from JSON. Use a regex that handles escaped quotes.
  # Falls back to truncated extraction if the pattern is too complex.
  COMMAND=$(echo "$INPUT" | grep -oE '"command"\s*:\s*"(\\.|[^"\\])*"' | head -1 | sed 's/^"command"\s*:\s*"//;s/"$//')

  # If extraction failed or is empty, try simpler pattern
  if [ -z "$COMMAND" ]; then
    COMMAND=$(echo "$INPUT" | grep -oE '"command"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
  fi

  if [ -n "$COMMAND" ] && echo "$COMMAND" | grep -qiE '\.gitban[/\\]cards[/\\]'; then
    # Block output redirects: look for > or >> followed by a path containing .gitban/cards/
    # Exclude stderr redirects (2>, 2>>) which are harmless
    if echo "$COMMAND" | grep -qE '[^2]>\s*\S*\.gitban[/\\]cards[/\\]' || \
       echo "$COMMAND" | grep -qE '^>\s*\S*\.gitban[/\\]cards[/\\]' || \
       echo "$COMMAND" | grep -qE '>>\s*\S*\.gitban[/\\]cards[/\\]'; then
      echo "BLOCKED: Do not modify .gitban/cards/ files via Bash. Use gitban MCP tools (create_card, edit_card, move_to_todo, complete_card, etc.)." >&2
      exit 2
    fi
    # Also catch redirects with space between > and path (e.g., echo "x" > .gitban/cards/f.md)
    if echo "$COMMAND" | grep -qE '>\s+\.gitban[/\\]cards[/\\]'; then
      echo "BLOCKED: Do not modify .gitban/cards/ files via Bash. Use gitban MCP tools (create_card, edit_card, move_to_todo, complete_card, etc.)." >&2
      exit 2
    fi
    # Block file-creating/modifying commands (cp, mv, mkdir, touch, tee, sed -i, chmod, chown)
    # Note: rm is ALLOWED for stale file cleanup
    if echo "$COMMAND" | grep -qE '\b(cp|mv|mkdir|touch|tee|chmod|chown)\b'; then
      echo "BLOCKED: Do not modify .gitban/cards/ files via Bash. Use gitban MCP tools (create_card, edit_card, move_to_todo, complete_card, etc.)." >&2
      exit 2
    fi
    if echo "$COMMAND" | grep -qE '\bsed\s+(-[a-zA-Z]*i|-i)\b'; then
      echo "BLOCKED: Do not modify .gitban/cards/ files via Bash. Use gitban MCP tools (create_card, edit_card, move_to_todo, complete_card, etc.)." >&2
      exit 2
    fi
  fi
fi

exit 0
