#!/bin/bash
# peon-ping adapter for OpenCode
# Installs the thin TypeScript adapter that routes events through peon.sh.
#
# Requires peon-ping installed first:
#   brew install PeonPing/tap/peon-ping
#   # or: curl -fsSL peonping.com/install | bash
#
# Install this adapter:
#   bash adapters/opencode.sh
#
# Or directly:
#   curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode.sh | bash
#
# Uninstall:
#   bash adapters/opencode.sh --uninstall

set -euo pipefail

PLUGIN_URL="https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode/peon-ping.ts"
OPENCODE_PLUGINS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/plugins"
PEON_SH_CANDIDATES=(
  "$HOME/.claude/hooks/peon-ping/peon.sh"
  "$HOME/.openclaw/hooks/peon-ping/peon.sh"
)

BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'

info()  { printf "%s>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s!%s %s\n" "$YELLOW" "$RESET" "$*"; }
error() { printf "%sx%s %s\n" "$RED" "$RESET" "$*" >&2; }

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  info "Uninstalling peon-ping adapter from OpenCode..."
  rm -f "$OPENCODE_PLUGINS_DIR/peon-ping.ts"
  info "Adapter removed."
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

if ! command -v curl &>/dev/null; then
  error "curl is required but not found."
  exit 1
fi

# --- Install adapter ---
info "Installing peon-ping adapter for OpenCode..."

mkdir -p "$OPENCODE_PLUGINS_DIR"
rm -f "$OPENCODE_PLUGINS_DIR/peon-ping.ts"

info "Downloading adapter..."
curl -fsSL "$PLUGIN_URL" -o "$OPENCODE_PLUGINS_DIR/peon-ping.ts"
info "Adapter installed to $OPENCODE_PLUGINS_DIR/peon-ping.ts"

# --- Done ---
echo ""
info "${BOLD}peon-ping adapter installed for OpenCode!${RESET}"
echo ""
printf "  %sAdapter:%s %s\n" "$DIM" "$RESET" "$OPENCODE_PLUGINS_DIR/peon-ping.ts"
printf "  %speon.sh:%s %s\n" "$DIM" "$RESET" "$PEON_SH"
echo ""
info "Restart OpenCode to activate. All peon-ping features now available."
info "Configure: peon config | peon trainer on | peon packs list"
