#!/usr/bin/env bash
# Hermes CESP Adapter installer
# Installs the peon-ping cesp-sounds plugin into Hermes Agent
#
# Usage:
#   bash adapters/hermes.sh          # install/update plugin
#   bash adapters/hermes.sh --uninstall  # remove plugin
#
# This adapter is a native Python plugin for Hermes Agent that maps
# Hermes lifecycle events to CESP sound categories.

set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
PLUGIN_DIR="$HERMES_HOME/plugins/cesp-sounds"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PEON_PING_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[peon-ping/hermes]${NC} $*"; }
warn()  { echo -e "${YELLOW}[peon-ping/hermes]${NC} $*"; }
error() { echo -e "${RED}[peon-ping/hermes]${NC} $*" >&2; }

uninstall_hermes() {
    if [ -d "$PLUGIN_DIR" ]; then
        info "Removing $PLUGIN_DIR"
        rm -rf "$PLUGIN_DIR"
        info "Hermes CESP sounds plugin uninstalled"
    else
        warn "Plugin directory not found: $PLUGIN_DIR"
    fi
    exit 0
}

install_hermes() {
    # Check if Hermes is installed
    if ! command -v hermes &>/dev/null && [ ! -d "$HERMES_HOME" ]; then
        error "Hermes not found. Install it first: https://github.com/NousResearch/hermes-agent"
        exit 1
    fi

    # Create plugin directory
    mkdir -p "$PLUGIN_DIR"

    # Copy __init__.py from source or use the one in this repo
    INIT_SRC="$PEON_PING_DIR/adapters/hermes/__init__.py"
    if [ -f "$INIT_SRC" ]; then
        cp "$INIT_SRC" "$PLUGIN_DIR/__init__.py"
    else
        error "Could not find __init__.py at $INIT_SRC"
        error "Run install.sh first to set up the peon-ping runtime, then re-run this script."
        exit 1
    fi

    # Copy plugin.yaml
    YAML_SRC="$PEON_PING_DIR/adapters/hermes/plugin.yaml"
    if [ -f "$YAML_SRC" ]; then
        cp "$YAML_SRC" "$PLUGIN_DIR/plugin.yaml"
    else
        error "Could not find plugin.yaml at $YAML_SRC"
        exit 1
    fi

    # Check for existing sound packs
    PACKS_DIR="$HOME/.claude/hooks/peon-ping/packs"
    OPENPEON_DIR="$HOME/.openpeon/packs"

    if [ -d "$PACKS_DIR" ]; then
        info "Found sound packs at $PACKS_DIR — plugin will use these automatically"
    elif [ -d "$OPENPEON_DIR" ]; then
        info "Found sound packs at $OPENPEON_DIR"
    else
        warn "No sound packs found. Install peon-ping first to get packs:"
        warn "  curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash"
    fi

    info "Hermes CESP sounds plugin installed to $PLUGIN_DIR"
    info "Restart Hermes to activate sound notifications"
    echo ""
    info "Configuration (environment variables):"
    info "  CESP_PACKS_DIR    = Sound pack directory (default: ~/.claude/hooks/peon-ping/packs)"
    info "  CESP_ACTIVE_PACK  = Specific pack name (default: most recently installed)"
    info "  CESP_VOLUME       = Master volume 0.0–1.0 (default: 0.5)"
    info "  CESP_DEBOUNCE     = Min seconds between sounds (default: 0.5)"
    info "  CESP_PLATFORMS    = Platforms to enable: cli,gateway,cron (default: cli)"
}

# Parse flags
case "${1:-}" in
    --uninstall|-u)
        uninstall_hermes
        ;;
    --help|-h)
        echo "Usage: bash adapters/hermes.sh [--uninstall]"
        echo "  Installs the peon-ping CESP sounds plugin for Hermes Agent"
        ;;
    *)
        install_hermes
        ;;
esac
