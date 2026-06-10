#!/bin/bash
# peon-ping adapter for Pi (earendil-works/pi, badlogic/pi-mono)
# Installs the thin TypeScript extension that routes Pi lifecycle events
# through peon.sh (or peon.ps1 on Windows).
#
# Pi auto-discovers extensions from ~/.pi/agent/extensions/ and loads them via
# jiti (no build step). This installer drops peon-ping.ts there.
#
# Requires peon-ping installed first:
#   brew install PeonPing/tap/peon-ping
#   # or: curl -fsSL peonping.com/install | bash
#
# Install:
#   bash adapters/pi.sh
# Or directly:
#   curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/pi.sh | bash
# Uninstall:
#   bash adapters/pi.sh --uninstall

set -euo pipefail

EXTENSION_NAME="peon-ping.ts"
PLUGIN_URL="https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/pi/peon-ping.ts"
PI_EXTENSIONS_DIR="${PI_EXTENSIONS_DIR:-$HOME/.pi/agent/extensions}"
PEON_SH_CANDIDATES=(
  "$HOME/.claude/hooks/peon-ping/peon.sh"
  "$HOME/.openpeon/hooks/peon-ping/peon.sh"
  "$HOME/.openclaw/hooks/peon-ping/peon.sh"
)
# Resolve this script's own directory so a local install can copy the vendored
# extension instead of downloading it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_EXTENSION="$SCRIPT_DIR/pi/$EXTENSION_NAME"

BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'

info()  { printf "%s>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s!%s %s\n" "$YELLOW" "$RESET" "$*"; }
error() { printf "%sx%s %s\n" "$RED" "$RESET" "$*" >&2; }

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  info "Uninstalling peon-ping extension from Pi..."
  rm -f "$PI_EXTENSIONS_DIR/$EXTENSION_NAME"
  info "Extension removed."
  exit 0
fi

# --- Preflight: find peon.sh ---
PEON_SH=""
for candidate in "${PEON_SH_CANDIDATES[@]}"; do
  if [ -f "$candidate" ]; then
    PEON_SH="$candidate"
    break
  fi
done

if [ -z "$PEON_SH" ]; then
  error "peon.sh not found. Install peon-ping first:"
  error "  brew install PeonPing/tap/peon-ping"
  error "  # or: curl -fsSL peonping.com/install | bash"
  exit 1
fi

# --- Install extension ---
info "Installing peon-ping extension for Pi..."
mkdir -p "$PI_EXTENSIONS_DIR"
rm -f "$PI_EXTENSIONS_DIR/$EXTENSION_NAME"

if [ -f "$LOCAL_EXTENSION" ]; then
  cp "$LOCAL_EXTENSION" "$PI_EXTENSIONS_DIR/$EXTENSION_NAME"
  info "Extension copied from $LOCAL_EXTENSION"
elif command -v curl &>/dev/null; then
  info "Downloading extension..."
  curl -fsSL "$PLUGIN_URL" -o "$PI_EXTENSIONS_DIR/$EXTENSION_NAME"
else
  error "Neither a local copy nor curl is available to install the extension."
  exit 1
fi
info "Extension installed to $PI_EXTENSIONS_DIR/$EXTENSION_NAME"

# --- Done ---
echo ""
info "${BOLD}peon-ping extension installed for Pi!${RESET}"
echo ""
printf "  %sExtension:%s %s\n" "$DIM" "$RESET" "$PI_EXTENSIONS_DIR/$EXTENSION_NAME"
printf "  %speon.sh:%s %s\n" "$DIM" "$RESET" "$PEON_SH"
echo ""
info "Restart Pi (or run /reload) to activate. All peon-ping features now available."
info "Configure: peon config | peon trainer on | peon packs list"
