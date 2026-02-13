#!/bin/bash
# peon-ping adapter for Kilo CLI
# Installs the peon-ping CESP v1.0 TypeScript plugin for Kilo CLI
#
# Kilo CLI is a fork of OpenCode and uses the same TypeScript plugin system.
# This installer downloads the OpenCode plugin and patches the import path
# and config directories for Kilo.
#
# Install:
#   bash adapters/kilo.sh
#
# Or directly:
#   curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/kilo.sh | bash
#
# Uninstall:
#   bash adapters/kilo.sh --uninstall

set -euo pipefail

# --- Config ---
PLUGIN_URL="https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode/peon-ping.ts"
REGISTRY_URL="https://peonping.github.io/registry/index.json"
DEFAULT_PACK="peon"

KILO_PLUGINS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kilo/plugins"
PEON_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kilo/peon-ping"
PACKS_DIR="$HOME/.openpeon/packs"

is_safe_source_repo() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]
}

is_safe_source_ref() {
  [[ "$1" =~ ^[A-Za-z0-9._/-]+$ ]] && [[ "$1" != *".."* ]] && [[ "$1" != /* ]]
}

is_safe_source_path() {
  [[ "$1" =~ ^[A-Za-z0-9._/-]+$ ]] && [[ "$1" != *".."* ]] && [[ "$1" != /* ]]
}

# --- Colors ---
BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'

info()  { printf "%s>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s!%s %s\n" "$YELLOW" "$RESET" "$*"; }
error() { printf "%sx%s %s\n" "$RED" "$RESET" "$*" >&2; }

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  info "Uninstalling peon-ping from Kilo CLI..."
  rm -f "$KILO_PLUGINS_DIR/peon-ping.ts"
  rm -rf "$PEON_CONFIG_DIR"
  info "Plugin and config removed."
  info "Sound packs in $PACKS_DIR were preserved (shared with other adapters)."
  info "To remove packs too: rm -rf $PACKS_DIR"
  exit 0
fi

# --- Preflight ---
info "Installing peon-ping for Kilo CLI..."

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
mkdir -p "$KILO_PLUGINS_DIR"

info "Downloading OpenCode plugin and patching for Kilo CLI..."
curl -fsSL "$PLUGIN_URL" \
  | sed \
    -e 's|"@opencode-ai/plugin"|"@kilocode/plugin"|g' \
    -e 's|".config", "opencode", "peon-ping"|".config", "kilo", "peon-ping"|g' \
    -e 's|`oc-\${Date.now()}`|`kilo-${Date.now()}`|g' \
    -e 's|) || "opencode"|) || "kilo"|g' \
    -e 's|peon-ping for OpenCode|peon-ping for Kilo CLI|g' \
    -e 's|A CESP.*player for OpenCode\.|A CESP (Coding Event Sound Pack Specification) player for Kilo CLI.|g' \
    -e 's|Maps OpenCode events|Maps Kilo events|g' \
    -e 's|~/.config/opencode/plugins/peon-ping.ts|~/.config/kilo/plugins/peon-ping.ts|g' \
    -e 's|Restart OpenCode|Restart Kilo CLI|g' \
    -e 's|OpenCode Event|Kilo Event|g' \
    -e 's|OpenCode -> CESP|Kilo CLI -> CESP|g' \
    -e 's|Return OpenCode event hooks|Return Kilo event hooks|g' \
  > "$KILO_PLUGINS_DIR/peon-ping.ts"
info "Plugin installed to $KILO_PLUGINS_DIR/peon-ping.ts"

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

  REGISTRY_JSON=$(curl -fsSL "$REGISTRY_URL" 2>/dev/null || true)
  PACK_INFO=$(PACK_NAME="$DEFAULT_PACK" python3 -c "
import sys, json
reg = json.load(sys.stdin)
for p in reg.get('packs', []):
    if p.get('name') == __import__('os').environ.get('PACK_NAME'):
        print(p.get('source_repo', ''))
        print(p.get('source_ref', ''))
        print(p.get('source_path', ''))
        break
" <<< "$REGISTRY_JSON" 2>/dev/null || echo "")

  SOURCE_REPO=$(echo "$PACK_INFO" | sed -n '1p')
  SOURCE_REF=$(echo "$PACK_INFO" | sed -n '2p')
  SOURCE_PATH=$(echo "$PACK_INFO" | sed -n '3p')

  if is_safe_source_repo "$SOURCE_REPO" && is_safe_source_ref "$SOURCE_REF" && is_safe_source_path "$SOURCE_PATH"; then
    TMPDIR_PACK=$(mktemp -d)
    TARBALL_URL="https://github.com/${SOURCE_REPO}/archive/refs/tags/${SOURCE_REF}.tar.gz"
    if curl -fsSL "$TARBALL_URL" -o "$TMPDIR_PACK/pack.tar.gz" 2>/dev/null; then
      if tar tzf "$TMPDIR_PACK/pack.tar.gz" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
        warn "Pack archive contains unsafe paths; skipping extraction."
      else
        tar xzf "$TMPDIR_PACK/pack.tar.gz" -C "$TMPDIR_PACK" 2>/dev/null
        EXTRACTED=$(find "$TMPDIR_PACK" -maxdepth 1 -type d ! -path "$TMPDIR_PACK" | head -1)
        if [ -n "$EXTRACTED" ] && [ -d "$EXTRACTED/${SOURCE_PATH}" ]; then
          mkdir -p "$PACKS_DIR/$DEFAULT_PACK"
          cp -r "$EXTRACTED/${SOURCE_PATH}/"* "$PACKS_DIR/$DEFAULT_PACK/"
          info "Pack '$DEFAULT_PACK' installed to $PACKS_DIR/$DEFAULT_PACK"
        else
          warn "Could not find pack in downloaded archive."
        fi
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
info "${BOLD}peon-ping installed for Kilo CLI!${RESET}"
echo ""
printf "  %sPlugin:%s  %s\n" "$DIM" "$RESET" "$KILO_PLUGINS_DIR/peon-ping.ts"
printf "  %sConfig:%s  %s\n" "$DIM" "$RESET" "$PEON_CONFIG_DIR/config.json"
printf "  %sPacks:%s   %s\n" "$DIM" "$RESET" "$PACKS_DIR/"
echo ""
info "Restart Kilo CLI to activate. Your Peon awaits."
info "Install more packs: https://openpeon.com/packs"
