#!/bin/bash
# setup-icon.sh — Replace terminal-notifier's default icon with the peon icon
#
# Usage:
#   bash scripts/setup-icon.sh
#   bash <(curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/scripts/setup-icon.sh)
#
# Requires: terminal-notifier (brew install terminal-notifier)
# Uses: sips + iconutil (built-in macOS tools, no extra deps)
#
# Why: terminal-notifier's -appIcon flag uses a deprecated API that
# modern macOS ignores. Replacing Terminal.icns in the app bundle
# is the only reliable workaround.
#
# Future: when jamf/Notifier ships to Homebrew (jamf/Notifier#32),
# the adapter will migrate to it — Notifier has built-in --rebrand.

set -euo pipefail

# --- Find peon icon ---
ICON=""
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo "")"

for path in \
  "${BREW_PREFIX:+$BREW_PREFIX/lib/peon-ping/docs/peon-icon.png}" \
  "$HOME/.config/opencode/peon-ping/peon-icon.png" \
  "$HOME/.claude/hooks/peon-ping/docs/peon-icon.png" \
  "$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/docs/peon-icon.png"; do
  [ -n "$path" ] && [ -f "$path" ] && ICON="$path" && break
done

if [ -z "$ICON" ]; then
  echo "Error: peon-icon.png not found."
  echo "Install peon-ping first: brew install PeonPing/tap/peon-ping"
  exit 1
fi

echo "Using icon: $ICON"

# --- Check terminal-notifier ---
if ! command -v terminal-notifier >/dev/null 2>&1; then
  echo "Error: terminal-notifier not found."
  echo "Install it: brew install terminal-notifier"
  exit 1
fi

# --- Find app bundle ---
TN_PATH=$(command -v terminal-notifier)
TN_REAL=$(readlink -f "$TN_PATH" 2>/dev/null || realpath "$TN_PATH" 2>/dev/null || echo "")
APP=""

if [ -n "$TN_REAL" ]; then
  # Walk up from .../terminal-notifier.app/Contents/MacOS/terminal-notifier
  APP=$(echo "$TN_REAL" | sed 's|/Contents/MacOS/terminal-notifier$||')
  if [ ! -d "$APP/Contents/Resources" ]; then
    # Try Homebrew Cellar layout
    CELLAR_APP=$(dirname "$TN_REAL")/../terminal-notifier.app
    if [ -d "$CELLAR_APP/Contents/Resources" ]; then
      APP=$(cd "$CELLAR_APP" && pwd)
    else
      APP=""
    fi
  fi
fi

ICNS="${APP:+$APP/Contents/Resources/Terminal.icns}"

if [ -z "$ICNS" ] || [ ! -f "$ICNS" ]; then
  echo "Error: Could not find Terminal.icns in terminal-notifier app bundle."
  echo "Expected at: $APP/Contents/Resources/Terminal.icns"
  exit 1
fi

# --- Generate .icns from PNG ---
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/peon.iconset"

echo "Generating icon sizes..."
for s in 16 32 64 128 256 512; do
  sips -z $s $s "$ICON" --out "$TMPDIR/peon.iconset/icon_${s}x${s}.png" >/dev/null 2>&1
  sips -z $((s*2)) $((s*2)) "$ICON" --out "$TMPDIR/peon.iconset/icon_${s}x${s}@2x.png" >/dev/null 2>&1
done

if ! iconutil -c icns "$TMPDIR/peon.iconset" -o "$TMPDIR/peon.icns" 2>/dev/null; then
  echo "Error: iconutil failed to generate .icns"
  rm -rf "$TMPDIR"
  exit 1
fi

# --- Backup and replace ---
if [ ! -f "${ICNS}.backup" ]; then
  cp "$ICNS" "${ICNS}.backup"
  echo "Original icon backed up to ${ICNS}.backup"
else
  echo "Backup already exists, skipping."
fi

cp "$TMPDIR/peon.icns" "$ICNS"
touch "$APP"

# --- Clean up ---
rm -rf "$TMPDIR"

echo ""
echo "Peon icon applied to terminal-notifier!"
echo "Note: re-run this script after 'brew upgrade terminal-notifier'."
