#!/bin/bash
# peon-ping adapter for OpenCode
# Installs the peon-ping CESP v1.0 TypeScript plugin for OpenCode
#
# OpenCode uses a TypeScript plugin system (not shell hooks), so this
# adapter is an install script rather than a runtime event translator.
#
# Install:
#   bash adapters/opencode.sh
#
# Or directly:
#   curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode.sh | bash
#
# Uninstall:
#   bash adapters/opencode.sh --uninstall

set -euo pipefail

# --- Config ---
PLUGIN_URL="https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode/peon-ping.ts"
REGISTRY_URL="https://peonping.github.io/registry/index.json"
DEFAULT_PACK="peon"

OPENCODE_PLUGINS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/plugins"
PEON_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/peon-ping"
PACKS_DIR="$HOME/.openpeon/packs"

# --- Colors ---
BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'

info()  { printf "%s>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s!%s %s\n" "$YELLOW" "$RESET" "$*"; }
error() { printf "%sx%s %s\n" "$RED" "$RESET" "$*" >&2; }

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  info "Uninstalling peon-ping from OpenCode..."
  rm -f "$OPENCODE_PLUGINS_DIR/peon-ping.ts"
  rm -rf "$PEON_CONFIG_DIR"
  info "Plugin and config removed."
  info "Sound packs in $PACKS_DIR were preserved (shared with other adapters)."
  info "To remove packs too: rm -rf $PACKS_DIR"
  exit 0
fi

# --- Preflight ---
info "Installing peon-ping for OpenCode..."

if ! command -v curl &>/dev/null; then
  error "curl is required but not found."
  exit 1
fi

# Check for afplay (macOS), paplay (Linux), or powershell (WSL)
PLATFORM="unknown"
case "$(uname -s)" in
  Darwin) PLATFORM="mac" ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      PLATFORM="wsl"
    else
      PLATFORM="linux"
    fi ;;
esac

case "$PLATFORM" in
  mac)
    command -v afplay &>/dev/null || warn "afplay not found — sounds may not play" ;;
  wsl)
    command -v powershell.exe &>/dev/null || warn "powershell.exe not found — sounds may not play" ;;
  linux)
    if ! command -v paplay &>/dev/null && ! command -v aplay &>/dev/null; then
      warn "No audio player found (paplay/aplay) — sounds may not play"
    fi ;;
esac

# --- Install plugin ---
mkdir -p "$OPENCODE_PLUGINS_DIR"

info "Downloading peon-ping.ts plugin..."
curl -fsSL "$PLUGIN_URL" -o "$OPENCODE_PLUGINS_DIR/peon-ping.ts"
info "Plugin installed to $OPENCODE_PLUGINS_DIR/peon-ping.ts"

# --- Create default config ---
mkdir -p "$PEON_CONFIG_DIR"

if [ ! -f "$PEON_CONFIG_DIR/config.json" ]; then
  cat > "$PEON_CONFIG_DIR/config.json" << 'CONFIGEOF'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "session.start": true,
    "session.end": true,
    "task.acknowledge": true,
    "task.complete": true,
    "task.error": true,
    "task.progress": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  },
  "spam_threshold": 3,
  "spam_window_seconds": 10,
  "pack_rotation": [],
  "debounce_ms": 500
}
CONFIGEOF
  info "Config created at $PEON_CONFIG_DIR/config.json"
else
  info "Config already exists, preserved."
fi

# --- Install default sound pack from registry ---
mkdir -p "$PACKS_DIR"

if [ ! -d "$PACKS_DIR/$DEFAULT_PACK" ]; then
  info "Installing default sound pack '$DEFAULT_PACK' from registry..."

  PACK_INFO=$(curl -fsSL "$REGISTRY_URL" 2>/dev/null \
    | python3 -c "
import sys, json
reg = json.load(sys.stdin)
for p in reg.get('packs', []):
    if p.get('name') == '$DEFAULT_PACK':
        print(p.get('source_repo', ''))
        print(p.get('source_ref', ''))
        print(p.get('source_path', ''))
        break
" 2>/dev/null || echo "")

  SOURCE_REPO=$(echo "$PACK_INFO" | sed -n '1p')
  SOURCE_REF=$(echo "$PACK_INFO" | sed -n '2p')
  SOURCE_PATH=$(echo "$PACK_INFO" | sed -n '3p')

  if [ -n "$SOURCE_REPO" ] && [ -n "$SOURCE_REF" ]; then
    TMPDIR_PACK=$(mktemp -d)
    TARBALL_URL="https://github.com/${SOURCE_REPO}/archive/refs/tags/${SOURCE_REF}.tar.gz"
    if curl -fsSL "$TARBALL_URL" -o "$TMPDIR_PACK/pack.tar.gz" 2>/dev/null; then
      tar xzf "$TMPDIR_PACK/pack.tar.gz" -C "$TMPDIR_PACK" 2>/dev/null
      EXTRACTED=$(find "$TMPDIR_PACK" -maxdepth 1 -type d ! -path "$TMPDIR_PACK" | head -1)
      if [ -n "$EXTRACTED" ] && [ -d "$EXTRACTED/${SOURCE_PATH}" ]; then
        mkdir -p "$PACKS_DIR/$DEFAULT_PACK"
        cp -r "$EXTRACTED/${SOURCE_PATH}/"* "$PACKS_DIR/$DEFAULT_PACK/"
        info "Pack '$DEFAULT_PACK' installed to $PACKS_DIR/$DEFAULT_PACK"
      else
        warn "Could not find pack in downloaded archive."
      fi
    else
      warn "Could not download pack from registry. You can install packs manually later."
    fi
    rm -rf "$TMPDIR_PACK"
  else
    warn "Could not find '$DEFAULT_PACK' in registry. You can install packs manually later."
  fi
else
  info "Pack '$DEFAULT_PACK' already installed."
fi

# --- Done ---
echo ""
info "${BOLD}peon-ping installed for OpenCode!${RESET}"
echo ""
printf "  %sPlugin:%s  %s\n" "$DIM" "$RESET" "$OPENCODE_PLUGINS_DIR/peon-ping.ts"
printf "  %sConfig:%s  %s\n" "$DIM" "$RESET" "$PEON_CONFIG_DIR/config.json"
printf "  %sPacks:%s   %s\n" "$DIM" "$RESET" "$PACKS_DIR/"
echo ""
info "Restart OpenCode to activate. Your Peon awaits."
info "Install more packs: https://openpeon.com/packs"
