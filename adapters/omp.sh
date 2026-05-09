#!/bin/bash
# peon-ping adapter for oh-my-pi (omp)
# Installs the thin TypeScript adapter that routes events through peon.sh.
#
# Requires peon-ping installed first:
#   brew install PeonPing/tap/peon-ping
#   # or: curl -fsSL peonping.com/install | bash
#
# Install this adapter:
#   bash adapters/omp.sh
#
# Or directly:
#   curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/omp.sh | bash
#
# Uninstall:
#   bash adapters/omp.sh --uninstall

set -euo pipefail

ADAPTER_TS_URL="https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/omp/peon-ping.ts"
ADAPTER_PKG_URL="https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/omp/package.json"
OMP_EXT_DIR="$HOME/.omp/agent/extensions/peon-ping"
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
  if [ -d "$OMP_EXT_DIR" ]; then
    rm -rf "$OMP_EXT_DIR"
    info "Removed $OMP_EXT_DIR"
  else
    info "Nothing to uninstall (extension directory not present)."
  fi
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
  error "peon.sh not found at any of:"
  for candidate in "${PEON_SH_CANDIDATES[@]}"; do
    error "  $candidate"
  done
  error ""
  error "Install peon-ping first:"
  error "  brew install PeonPing/tap/peon-ping"
  error "  # or: curl -fsSL peonping.com/install | bash"
  exit 1
fi

# --- Install adapter ---
info "Installing peon-ping adapter for oh-my-pi (omp)..."

mkdir -p "$OMP_EXT_DIR"
# Defensive: if a stale symlink lives where peon-ping.ts should be, rm it
rm -f "$OMP_EXT_DIR/peon-ping.ts" "$OMP_EXT_DIR/package.json"

if [ -n "${PEON_PING_LOCAL_ADAPTER_DIR:-}" ]; then
  # Test-only path: copy from a local checkout instead of downloading
  info "Using local adapter dir: $PEON_PING_LOCAL_ADAPTER_DIR"
  cp "$PEON_PING_LOCAL_ADAPTER_DIR/peon-ping.ts" "$OMP_EXT_DIR/peon-ping.ts"
  cp "$PEON_PING_LOCAL_ADAPTER_DIR/package.json" "$OMP_EXT_DIR/package.json"
else
  if ! command -v curl &>/dev/null; then
    error "curl is required but not found on PATH."
    exit 1
  fi
  info "Downloading adapter..."
  curl -fsSL "$ADAPTER_TS_URL" -o "$OMP_EXT_DIR/peon-ping.ts"
  curl -fsSL "$ADAPTER_PKG_URL" -o "$OMP_EXT_DIR/package.json"
fi

info "Adapter installed to $OMP_EXT_DIR/"

# --- Done ---
echo ""
info "${BOLD}peon-ping adapter installed for oh-my-pi (omp)!${RESET}"
echo ""
printf "  %sExtension:%s %s\n" "$DIM" "$RESET" "$OMP_EXT_DIR/peon-ping.ts"
printf "  %sManifest:%s  %s\n" "$DIM" "$RESET" "$OMP_EXT_DIR/package.json"
printf "  %speon.sh:%s   %s\n" "$DIM" "$RESET" "$PEON_SH"
echo ""
info "Restart omp to activate. All peon-ping features now available."
info "Configure: peon config | peon trainer on | peon packs list"
