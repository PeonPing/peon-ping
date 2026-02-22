#!/bin/bash
# peon-ping installer
# Works both via `curl | bash` (downloads from GitHub) and local clone
# Re-running updates core files; sounds are version-controlled in the repo
set -euo pipefail

LOCAL_MODE=false
INIT_LOCAL_CONFIG=false
INSTALL_ALL=false
CUSTOM_PACKS=""
OPENCLAW_MODE=false
NO_RC=false
for arg in "$@"; do
  case "$arg" in
    --global) LOCAL_MODE=false ;;
    --local) LOCAL_MODE=true ;;
    --openclaw) OPENCLAW_MODE=true ;;
    --init-local-config) INIT_LOCAL_CONFIG=true ;;
    --all) INSTALL_ALL=true ;;
    --no-rc) NO_RC=true ;;
    --packs=*) CUSTOM_PACKS="${arg#--packs=}" ;;
    --help|-h)
      cat <<'HELPEOF'
Usage: install.sh [OPTIONS]

Options:
  --global             Install globally (default)
  --local              Install in current project (.claude)
  --openclaw           Install as OpenClaw skill (~/.openclaw/skills)
  --init-local-config  Create local config only, then exit
  --all                Install all packs
  --no-rc              Skip .bashrc/.zshrc/fish config modifications
  --packs=<a,b,c>      Install specific packs
HELPEOF
      exit 0
      ;;
  esac
done

GLOBAL_BASE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
LOCAL_BASE="$PWD/.claude"
OPENCLAW_BASE="$HOME/.openclaw"

# Respect no_rc from config.json if --no-rc wasn't passed on CLI
if [ "$NO_RC" = false ]; then
  for _cfg in "$GLOBAL_BASE/hooks/peon-ping/config.json" "$LOCAL_BASE/hooks/peon-ping/config.json"; do
    if [ -f "$_cfg" ]; then
      _cfg_py="$_cfg"; command -v cygpath &>/dev/null && _cfg_py="$(cygpath -m "$_cfg")"
      _no_rc=$(python3 -c "import json; print(json.load(open('$_cfg_py')).get('no_rc', False))" 2>/dev/null)
      if [ "$_no_rc" = "True" ]; then
        NO_RC=true
      fi
      break
    fi
  done
fi

# Auto-detect OpenClaw if present and Claude Code is not
if [ "$OPENCLAW_MODE" = false ] && [ "$LOCAL_MODE" = false ]; then
  if [ -d "$OPENCLAW_BASE" ] && [ ! -d "$GLOBAL_BASE" ]; then
    OPENCLAW_MODE=true
    echo "Auto-detected OpenClaw installation (no Claude Code found)."
  fi
fi

if [ "$OPENCLAW_MODE" = true ]; then
  BASE_DIR="$OPENCLAW_BASE"
  INSTALL_DIR="$BASE_DIR/hooks/peon-ping"
  SETTINGS=""  # OpenClaw doesn't use settings.json for hooks
elif [ "$LOCAL_MODE" = true ]; then
  BASE_DIR="$LOCAL_BASE"
else
  BASE_DIR="$GLOBAL_BASE"
fi
if [ "$OPENCLAW_MODE" = false ]; then
  INSTALL_DIR="$BASE_DIR/hooks/peon-ping"
  SETTINGS="$BASE_DIR/settings.json"
fi
REPO_BASE="https://raw.githubusercontent.com/PeonPing/peon-ping/main"
REGISTRY_URL="https://peonping.github.io/registry/index.json"

if [ "$INIT_LOCAL_CONFIG" = true ]; then
  LOCAL_CONFIG_DIR="$LOCAL_BASE/hooks/peon-ping"
  LOCAL_CONFIG_FILE="$LOCAL_CONFIG_DIR/config.json"
  mkdir -p "$LOCAL_CONFIG_DIR"
  if [ -f "$LOCAL_CONFIG_FILE" ]; then
    echo "Local config already exists: $LOCAL_CONFIG_FILE"
    exit 0
  fi
  if [ -f "$GLOBAL_BASE/hooks/peon-ping/config.json" ]; then
    cp "$GLOBAL_BASE/hooks/peon-ping/config.json" "$LOCAL_CONFIG_FILE"
  elif [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
    CANDIDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    if [ -f "$CANDIDATE/config.json" ]; then
      cp "$CANDIDATE/config.json" "$LOCAL_CONFIG_FILE"
    else
      curl -fsSL "$REPO_BASE/config.json" -o "$LOCAL_CONFIG_FILE"
    fi
  else
    curl -fsSL "$REPO_BASE/config.json" -o "$LOCAL_CONFIG_FILE"
  fi
  echo "Created local config: $LOCAL_CONFIG_FILE"
  exit 0
fi

# Default packs (curated English set installed by default)
DEFAULT_PACKS="peon peasant sc_kerrigan sc_battlecruiser glados"


# --- Platform detection ---
detect_platform() {
  case "$(uname -s)" in
    Darwin)
      if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ]; then
        echo "ssh"
      else
        echo "mac"
      fi ;;
    Linux)
      # Check for devcontainer/Docker BEFORE checking for WSL
      # (devcontainers on WSL2 have both indicators)
      if [ "${REMOTE_CONTAINERS:-}" = "true" ] || [ "${CODESPACES:-}" = "true" ] || [ -f /.dockerenv ]; then
        echo "devcontainer"
      elif grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      elif [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ]; then
        echo "ssh"
      else
        echo "linux"
      fi ;;
    MSYS_NT*|MINGW*) echo "msys2" ;;
    *) echo "unknown" ;;
  esac
}
PLATFORM=$(detect_platform)

# MSYS2/MinGW: Windows Python can't read /c/... paths — convert to C:/... via cygpath
py_path() {
  if [ "$PLATFORM" = "msys2" ]; then
    cygpath -m "$1"
  else
    printf '%s' "$1"
  fi
}

# --- Detect update vs fresh install ---
UPDATING=false
if [ -f "$INSTALL_DIR/peon.sh" ]; then
  UPDATING=true
fi

if [ "$UPDATING" = true ]; then
  echo "=== peon-ping updater ==="
  echo ""
  echo "Existing install found. Updating..."
else
  echo "=== peon-ping installer ==="
  echo ""
fi

# --- Prerequisites ---
if [ "$PLATFORM" != "mac" ] && [ "$PLATFORM" != "wsl" ] && [ "$PLATFORM" != "linux" ] && [ "$PLATFORM" != "devcontainer" ] && [ "$PLATFORM" != "ssh" ] && [ "$PLATFORM" != "msys2" ]; then
  echo "Error: peon-ping requires macOS, Linux, WSL, MSYS2, SSH, or a devcontainer"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required"
  exit 1
fi

if [ "$PLATFORM" = "mac" ]; then
  if ! command -v afplay &>/dev/null; then
    echo "Error: afplay is required (should be built into macOS)"
    exit 1
  fi
elif [ "$PLATFORM" = "wsl" ]; then
  if ! command -v powershell.exe &>/dev/null; then
    echo "Error: powershell.exe is required (should be available in WSL)"
    exit 1
  fi
  if ! command -v wslpath &>/dev/null; then
    echo "Error: wslpath is required (should be built into WSL)"
    exit 1
  fi
elif [ "$PLATFORM" = "devcontainer" ]; then
  echo "Devcontainer detected. Audio will play through the relay on your host."
  echo "Run 'peon relay' on your host machine after installation."
  if ! command -v curl &>/dev/null; then
    echo "Warning: curl not found. Install curl for relay audio playback."
  fi
elif [ "$PLATFORM" = "ssh" ]; then
  echo "SSH session detected. Audio will play through the relay on your local machine."
  echo "After install:"
  echo "  1. On your LOCAL machine, run: peon relay --daemon"
  echo "  2. Reconnect with: ssh -R 19998:localhost:19998 <host>"
  if ! command -v curl &>/dev/null; then
    echo "Warning: curl not found. Install curl for relay audio playback."
  fi
elif [ "$PLATFORM" = "linux" ]; then
  LINUX_PLAYER=""
  for cmd in pw-play paplay ffplay mpv aplay; do
    if command -v "$cmd" &>/dev/null; then
      LINUX_PLAYER="$cmd"
      break
    fi
  done
  if [ -z "$LINUX_PLAYER" ]; then
    echo "Error: no supported audio player found."
    echo "Install one of: pw-play (pipewire-audio) paplay (pulseaudio-utils), ffplay (ffmpeg), mpv, aplay (alsa-utils)"
    exit 1
  fi
  echo "Audio player: $LINUX_PLAYER"
  if command -v notify-send &>/dev/null; then
    echo "Desktop notifications: notify-send"
  else
    echo "Warning: notify-send not found (libnotify-bin). Desktop notifications will be disabled."
  fi
elif [ "$PLATFORM" = "msys2" ]; then
  if ! command -v python3 &>/dev/null; then
    echo "Error: python3 is required"
    exit 1
  fi
  if ! command -v cygpath &>/dev/null; then
    echo "Error: cygpath is required (should be built into MSYS2/Git Bash)"
    exit 1
  fi
  MSYS2_PLAYER=""
  for cmd in ffplay mpv play; do
    if command -v "$cmd" &>/dev/null; then
      MSYS2_PLAYER="$cmd"
      break
    fi
  done
  if [ -n "$MSYS2_PLAYER" ]; then
    echo "Audio player: $MSYS2_PLAYER"
  else
    echo "Audio: PowerShell MediaPlayer fallback (native players like ffplay/mpv preferred for lower latency)"
  fi
fi

if [ ! -d "$BASE_DIR" ]; then
  if [ "$LOCAL_MODE" = true ]; then
    echo "Error: .claude/ not found in current directory. Is this a Claude Code project?"
    exit 1
  else
    # ~/.claude doesn't exist yet — create it so peon-ping has a home.
    # This is normal when using peon-ping with non-Claude-Code editors
    # (e.g. GitHub Copilot, Cursor) where ~/.claude was never created.
    echo "Creating $BASE_DIR..."
    mkdir -p "$BASE_DIR"
  fi
fi

remove_existing_install() {
  local target_base="$1"
  local target_type="$2"
  local target_install="$target_base/hooks/peon-ping"
  local target_settings="$target_base/settings.json"

  rm -rf "$target_install"
  if [ -f "$target_settings" ]; then
    python3 -c "
import json
import os

path = '$(py_path "$target_settings")'
try:
    with open(path) as f:
        settings = json.load(f)
except Exception:
    settings = {}

hooks = settings.get('hooks', {})
changed = False
for event, entries in list(hooks.items()):
    filtered = []
    for entry in entries:
        subhooks = entry.get('hooks', [])
        keep = True
        for h in subhooks:
            cmd = h.get('command', '')
            if 'peon-ping/peon.sh' in cmd:
                keep = False
                break
        if keep:
            filtered.append(entry)
    if len(filtered) != len(entries):
        hooks[event] = filtered
        changed = True

if changed:
    settings['hooks'] = hooks
    with open(path, 'w') as f:
        json.dump(settings, f, indent=2)
        f.write('\n')
" 2>/dev/null || true
  fi
  echo "Removed $target_type installation."
}

if [ "$LOCAL_MODE" = true ] && [ "$GLOBAL_BASE" != "$LOCAL_BASE" ] && [ -f "$GLOBAL_BASE/hooks/peon-ping/peon.sh" ]; then
  echo ""
  echo "Global installation already exists at $GLOBAL_BASE/hooks/peon-ping"
  if [ -t 0 ]; then
    read -p "Remove global installation and continue local install? (y/N): " -n 1 -r
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      remove_existing_install "$GLOBAL_BASE" "global"
    else
      echo "Aborted."
      exit 0
    fi
  else
    echo "Non-interactive session detected; keeping existing global installation."
  fi
fi

if [ "$LOCAL_MODE" = false ] && [ "$GLOBAL_BASE" != "$LOCAL_BASE" ] && [ -f "$LOCAL_BASE/hooks/peon-ping/peon.sh" ]; then
  echo ""
  echo "Local installation already exists at $LOCAL_BASE/hooks/peon-ping"
  if [ -t 0 ]; then
    read -p "Remove local installation and continue global install? (y/N): " -n 1 -r
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      remove_existing_install "$LOCAL_BASE" "local"
    else
      echo "Aborted."
      exit 0
    fi
  else
    echo "Non-interactive session detected; keeping existing local installation."
  fi
fi

# --- Detect if running from local clone or curl|bash ---
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
  CANDIDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  if [ -f "$CANDIDATE/peon.sh" ]; then
    SCRIPT_DIR="$CANDIDATE"
  fi
fi

# --- Python-safe path variants (MSYS2 Windows Python needs C:/... not /c/...) ---
INSTALL_DIR_PY="$(py_path "$INSTALL_DIR")"
GLOBAL_BASE_PY="$(py_path "$GLOBAL_BASE")"
LOCAL_BASE_PY="$(py_path "$LOCAL_BASE")"

# --- Install/update core tool files ---
mkdir -p "$INSTALL_DIR"

if [ -n "$SCRIPT_DIR" ]; then
  # Local clone — copy core tool files
  cp "$SCRIPT_DIR/peon.sh" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/relay.sh" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/completions.bash" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/completions.fish" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/VERSION" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"
  if [ -d "$SCRIPT_DIR/adapters" ]; then
    mkdir -p "$INSTALL_DIR/adapters"
    cp "$SCRIPT_DIR/adapters/"*.sh "$INSTALL_DIR/adapters/" 2>/dev/null || true
  fi
  if [ -d "$SCRIPT_DIR/scripts" ]; then
    mkdir -p "$INSTALL_DIR/scripts"
    cp "$SCRIPT_DIR/scripts/"*.sh "$INSTALL_DIR/scripts/" 2>/dev/null || true
    cp "$SCRIPT_DIR/scripts/"*.ps1 "$INSTALL_DIR/scripts/" 2>/dev/null || true
    cp "$SCRIPT_DIR/scripts/"*.swift "$INSTALL_DIR/scripts/" 2>/dev/null || true
    cp "$SCRIPT_DIR/scripts/"*.js "$INSTALL_DIR/scripts/" 2>/dev/null || true
  fi
  if [ -f "$SCRIPT_DIR/docs/peon-icon.png" ]; then
    mkdir -p "$INSTALL_DIR/docs"
    cp "$SCRIPT_DIR/docs/peon-icon.png" "$INSTALL_DIR/docs/"
  fi
  if [ "$UPDATING" = false ]; then
    cp "$SCRIPT_DIR/config.json" "$INSTALL_DIR/"
  fi
else
  # curl|bash — download core tool files from GitHub
  echo "Downloading from GitHub..."
  curl -fsSL "$REPO_BASE/peon.sh" -o "$INSTALL_DIR/peon.sh"
  curl -fsSL "$REPO_BASE/relay.sh" -o "$INSTALL_DIR/relay.sh"
  curl -fsSL "$REPO_BASE/completions.bash" -o "$INSTALL_DIR/completions.bash"
  curl -fsSL "$REPO_BASE/completions.fish" -o "$INSTALL_DIR/completions.fish"
  curl -fsSL "$REPO_BASE/VERSION" -o "$INSTALL_DIR/VERSION"
  curl -fsSL "$REPO_BASE/uninstall.sh" -o "$INSTALL_DIR/uninstall.sh"
  mkdir -p "$INSTALL_DIR/adapters"
  curl -fsSL "$REPO_BASE/adapters/codex.sh" -o "$INSTALL_DIR/adapters/codex.sh" 2>/dev/null || true
  curl -fsSL "$REPO_BASE/adapters/cursor.sh" -o "$INSTALL_DIR/adapters/cursor.sh" 2>/dev/null || true
  curl -fsSL "$REPO_BASE/adapters/kiro.sh" -o "$INSTALL_DIR/adapters/kiro.sh" 2>/dev/null || true
  curl -fsSL "$REPO_BASE/adapters/antigravity.sh" -o "$INSTALL_DIR/adapters/antigravity.sh" 2>/dev/null || true
  curl -fsSL "$REPO_BASE/adapters/gemini.sh" -o "$INSTALL_DIR/adapters/gemini.sh" 2>/dev/null || true
  curl -fsSL "$REPO_BASE/adapters/openclaw.sh" -o "$INSTALL_DIR/adapters/openclaw.sh" 2>/dev/null || true
  curl -fsSL "$REPO_BASE/adapters/opencode.sh" -o "$INSTALL_DIR/adapters/opencode.sh" 2>/dev/null || true
  curl -fsSL "$REPO_BASE/adapters/windsurf.sh" -o "$INSTALL_DIR/adapters/windsurf.sh" 2>/dev/null || true
  mkdir -p "$INSTALL_DIR/scripts"
  curl -fsSL "$REPO_BASE/scripts/hook-handle-use.sh" -o "$INSTALL_DIR/scripts/hook-handle-use.sh" 2>/dev/null || true
  curl -fsSL "$REPO_BASE/scripts/hook-handle-use.ps1" -o "$INSTALL_DIR/scripts/hook-handle-use.ps1" 2>/dev/null || true
  curl -fsSL "$REPO_BASE/scripts/pack-download.sh" -o "$INSTALL_DIR/scripts/pack-download.sh" 2>/dev/null || true
  curl -fsSL "$REPO_BASE/scripts/mac-overlay.js" -o "$INSTALL_DIR/scripts/mac-overlay.js" 2>/dev/null || true
  curl -fsSL "$REPO_BASE/scripts/notify.sh" -o "$INSTALL_DIR/scripts/notify.sh" 2>/dev/null || true
  mkdir -p "$INSTALL_DIR/docs"
  curl -fsSL "$REPO_BASE/docs/peon-icon.png" -o "$INSTALL_DIR/docs/peon-icon.png" 2>/dev/null || true
  if [ "$UPDATING" = false ]; then
    curl -fsSL "$REPO_BASE/config.json" -o "$INSTALL_DIR/config.json"
  fi
fi

# --- Backfill new config keys on update ---
# Merge any new keys from the default config template into the user's
# existing config without overwriting their values.
if [ "$UPDATING" = true ] && [ -f "$INSTALL_DIR/config.json" ]; then
  # Determine the source of default config
  if [ -n "$SCRIPT_DIR" ]; then
    DEFAULT_CFG="$SCRIPT_DIR/config.json"
  else
    DEFAULT_CFG=$(mktemp)
    curl -fsSL "$REPO_BASE/config.json" -o "$DEFAULT_CFG" 2>/dev/null || true
  fi
  if [ -f "$DEFAULT_CFG" ]; then
    python3 -c "
import json, sys

try:
    with open('$(py_path "$DEFAULT_CFG")') as f:
        defaults = json.load(f)
    with open('$INSTALL_DIR_PY/config.json') as f:
        user_cfg = json.load(f)
except Exception:
    sys.exit(0)

changed = False
for key, value in defaults.items():
    if key not in user_cfg:
        user_cfg[key] = value
        changed = True

if changed:
    with open('$INSTALL_DIR/config.json', 'w') as f:
        json.dump(user_cfg, f, indent=2)
        f.write('\n')
    print('Config updated with new defaults')
" 2>/dev/null || true
    # Clean up temp file if we downloaded one
    [ -z "$SCRIPT_DIR" ] && rm -f "$DEFAULT_CFG"
  fi
fi

# --- Persist --no-rc preference to config ---
if [ "$NO_RC" = true ] && [ -f "$INSTALL_DIR/config.json" ]; then
  python3 -c "
import json
path = '$INSTALL_DIR_PY/config.json'
with open(path) as f:
    cfg = json.load(f)
if not cfg.get('no_rc', False):
    cfg['no_rc'] = True
    with open(path, 'w') as f:
        json.dump(cfg, f, indent=2)
        f.write('\n')
" 2>/dev/null || true
fi

# --- Download sound packs via shared engine ---
PACK_DL="$INSTALL_DIR/scripts/pack-download.sh"
chmod +x "$PACK_DL" 2>/dev/null || true

if [ -n "$CUSTOM_PACKS" ]; then
  bash "$PACK_DL" --dir="$INSTALL_DIR" --packs="$CUSTOM_PACKS"
elif [ "$INSTALL_ALL" = true ]; then
  bash "$PACK_DL" --dir="$INSTALL_DIR" --all
else
  bash "$PACK_DL" --dir="$INSTALL_DIR" --packs="$(echo "$DEFAULT_PACKS" | tr ' ' ',')"
fi

chmod +x "$INSTALL_DIR/peon.sh"
chmod +x "$INSTALL_DIR/relay.sh"
chmod +x "$INSTALL_DIR/scripts/hook-handle-use.sh" 2>/dev/null || true
chmod +x "$INSTALL_DIR/scripts/pack-download.sh" 2>/dev/null || true
chmod +x "$INSTALL_DIR/scripts/notify.sh" 2>/dev/null || true

# --- Build peon-play (macOS Sound Effects device support) ---
if [ "$PLATFORM" = "mac" ] && command -v swiftc &>/dev/null; then
  PEON_PLAY_SRC="$INSTALL_DIR/scripts/peon-play.swift"
  if [ ! -f "$PEON_PLAY_SRC" ] && [ -z "$SCRIPT_DIR" ]; then
    curl -fsSL "$REPO_BASE/scripts/peon-play.swift" -o "$PEON_PLAY_SRC" 2>/dev/null || true
  fi
  if [ -f "$PEON_PLAY_SRC" ]; then
    echo "Building peon-play (Sound Effects device support)..."
    swiftc -O -o "$INSTALL_DIR/scripts/peon-play" \
      "$PEON_PLAY_SRC" \
      -framework AVFoundation -framework CoreAudio -framework AudioToolbox 2>/dev/null \
      && echo "  peon-play built successfully" \
      || echo "  Warning: could not build peon-play, using afplay fallback"
  fi
fi

# --- Install skill (slash command) ---
SKILL_DIR="$BASE_DIR/skills/peon-ping-toggle"
mkdir -p "$SKILL_DIR"
SKILL_HOOK_CMD="bash $INSTALL_DIR/peon.sh"
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/skills/peon-ping-toggle" ]; then
  cp "$SCRIPT_DIR/skills/peon-ping-toggle/SKILL.md" "$SKILL_DIR/"
  if [ "$LOCAL_MODE" = true ]; then
    sed -i.bak 's|bash "${CLAUDE_CONFIG_DIR:-\$HOME/\.claude}"/hooks/peon-ping/peon\.sh|'"$SKILL_HOOK_CMD"'|g' "$SKILL_DIR/SKILL.md"
    rm -f "$SKILL_DIR/SKILL.md.bak"
  fi
elif [ -z "$SCRIPT_DIR" ]; then
  curl -fsSL "$REPO_BASE/skills/peon-ping-toggle/SKILL.md" -o "$SKILL_DIR/SKILL.md"
  if [ "$LOCAL_MODE" = true ]; then
    sed -i.bak 's|bash "${CLAUDE_CONFIG_DIR:-\$HOME/\.claude}"/hooks/peon-ping/peon\.sh|'"$SKILL_HOOK_CMD"'|g' "$SKILL_DIR/SKILL.md"
    rm -f "$SKILL_DIR/SKILL.md.bak"
  fi
else
  echo "Warning: skills/peon-ping-toggle not found in local clone, skipping skill install"
fi

# --- Install config skill ---
CONFIG_SKILL_DIR="$BASE_DIR/skills/peon-ping-config"
mkdir -p "$CONFIG_SKILL_DIR"
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/skills/peon-ping-config" ]; then
  cp "$SCRIPT_DIR/skills/peon-ping-config/SKILL.md" "$CONFIG_SKILL_DIR/"
elif [ -z "$SCRIPT_DIR" ]; then
  curl -fsSL "$REPO_BASE/skills/peon-ping-config/SKILL.md" -o "$CONFIG_SKILL_DIR/SKILL.md"
else
  echo "Warning: skills/peon-ping-config not found in local clone, skipping config skill install"
fi

# --- Install use skill ---
USE_SKILL_DIR="$BASE_DIR/skills/peon-ping-use"
mkdir -p "$USE_SKILL_DIR"
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/skills/peon-ping-use" ]; then
  cp "$SCRIPT_DIR/skills/peon-ping-use/SKILL.md" "$USE_SKILL_DIR/"
elif [ -z "$SCRIPT_DIR" ]; then
  curl -fsSL "$REPO_BASE/skills/peon-ping-use/SKILL.md" -o "$USE_SKILL_DIR/SKILL.md"
else
  echo "Warning: skills/peon-ping-use not found in local clone, skipping use skill install"
fi

# --- Install log skill ---
LOG_SKILL_DIR="$BASE_DIR/skills/peon-ping-log"
mkdir -p "$LOG_SKILL_DIR"
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/skills/peon-ping-log" ]; then
  cp "$SCRIPT_DIR/skills/peon-ping-log/SKILL.md" "$LOG_SKILL_DIR/"
elif [ -z "$SCRIPT_DIR" ]; then
  curl -fsSL "$REPO_BASE/skills/peon-ping-log/SKILL.md" -o "$LOG_SKILL_DIR/SKILL.md"
else
  echo "Warning: skills/peon-ping-log not found in local clone, skipping log skill install"
fi

# --- Install trainer voice packs ---
TRAINER_DIR="$INSTALL_DIR/trainer"
mkdir -p "$TRAINER_DIR/sounds"
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/trainer" ]; then
  cp "$SCRIPT_DIR/trainer/manifest.json" "$TRAINER_DIR/"
  for subdir in "$SCRIPT_DIR/trainer/sounds/"*/; do
    [ -d "$subdir" ] || continue
    dirname=$(basename "$subdir")
    mkdir -p "$TRAINER_DIR/sounds/$dirname"
    cp "$subdir"*.mp3 "$TRAINER_DIR/sounds/$dirname/" 2>/dev/null || true
  done
  echo "Trainer voice packs installed."
elif [ -z "$SCRIPT_DIR" ]; then
  curl -fsSL "$REPO_BASE/trainer/manifest.json" -o "$TRAINER_DIR/manifest.json"
  # Parse manifest to download all trainer sounds
  python3 -c "
import json, sys
m = json.load(open('$(py_path "$TRAINER_DIR")/manifest.json'))
for cat in m.values():
    for s in cat:
        print(s['file'])
" | while read -r sfile; do
    mkdir -p "$TRAINER_DIR/$(dirname "$sfile")"
    curl -fsSL "$REPO_BASE/trainer/$sfile" -o "$TRAINER_DIR/$sfile" 2>/dev/null || true
  done
  echo "Trainer voice packs installed."
else
  echo "Warning: trainer/ not found in local clone, skipping trainer install"
fi

# --- Add shell alias (global install only, unless --no-rc) ---
if [ "$LOCAL_MODE" = false ] && [ "$NO_RC" = false ]; then
  ALIAS_LINE="alias peon=\"bash $INSTALL_DIR/peon.sh\""
  for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rcfile" ] && [ -w "$rcfile" ] && ! grep -qF 'alias peon=' "$rcfile"; then
      echo "" >> "$rcfile"
      echo "# peon-ping quick controls" >> "$rcfile"
      echo "$ALIAS_LINE" >> "$rcfile"
      echo "Added peon alias to $(basename "$rcfile")"
    elif [ -f "$rcfile" ] && [ ! -w "$rcfile" ]; then
      echo "Warning: $(basename "$rcfile") is not writable, skipping alias" >&2
    fi
  done

  # --- Add tab completion ---
  COMPLETION_LINE="[ -f $INSTALL_DIR/completions.bash ] && source $INSTALL_DIR/completions.bash"
  for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rcfile" ] && [ -w "$rcfile" ] && ! grep -qF 'peon-ping/completions.bash' "$rcfile"; then
      echo "$COMPLETION_LINE" >> "$rcfile"
      echo "Added tab completion to $(basename "$rcfile")"
    fi
  done
fi

# --- Add fish shell function + completions ---
if [ "$NO_RC" = false ]; then
  FISH_CONFIG="$HOME/.config/fish/config.fish"
  if [ -f "$FISH_CONFIG" ] && [ -w "$FISH_CONFIG" ]; then
    FISH_FUNC="function peon; bash $INSTALL_DIR/peon.sh \$argv; end"
    if ! grep -qF 'function peon' "$FISH_CONFIG"; then
      echo "" >> "$FISH_CONFIG"
      echo "# peon-ping quick controls" >> "$FISH_CONFIG"
      echo "$FISH_FUNC" >> "$FISH_CONFIG"
      echo "Added peon function to config.fish"
    fi
  elif [ -f "$FISH_CONFIG" ] && [ ! -w "$FISH_CONFIG" ]; then
    echo "Warning: config.fish is not writable, skipping fish function" >&2
  fi
  FISH_COMPLETIONS_DIR="$HOME/.config/fish/completions"
  if [ -d "$HOME/.config/fish" ]; then
    mkdir -p "$FISH_COMPLETIONS_DIR"
    cp "$INSTALL_DIR/completions.fish" "$FISH_COMPLETIONS_DIR/peon.fish"
    echo "Installed fish completions to $FISH_COMPLETIONS_DIR/peon.fish"
  fi
fi

# --- Verify sounds are installed ---
if [ -n "$CUSTOM_PACKS" ]; then
  VERIFY_PACKS=$(echo "$CUSTOM_PACKS" | tr ',' ' ')
elif [ "$INSTALL_ALL" = true ]; then
  VERIFY_PACKS=""
  for _d in "$INSTALL_DIR/packs"/*/; do
    [ -d "$_d" ] && VERIFY_PACKS="$VERIFY_PACKS $(basename "$_d")"
  done
else
  VERIFY_PACKS="$DEFAULT_PACKS"
fi
echo ""
for pack in $VERIFY_PACKS; do
  sound_dir="$INSTALL_DIR/packs/$pack/sounds"
  sound_count=$({ ls "$sound_dir"/*.wav "$sound_dir"/*.mp3 "$sound_dir"/*.ogg 2>/dev/null || true; } | wc -l | tr -d ' ')
  if [ "$sound_count" -eq 0 ]; then
    echo "[$pack] Warning: No sound files found!"
  else
    echo "[$pack] $sound_count sound files installed."
  fi
done

# --- Backup existing notify.sh (global fresh install only) ---
if [ "$LOCAL_MODE" = false ] && [ "$UPDATING" = false ]; then
  NOTIFY_SH="$BASE_DIR/hooks/notify.sh"
  if [ -f "$NOTIFY_SH" ]; then
    cp "$NOTIFY_SH" "$NOTIFY_SH.backup"
    echo ""
    echo "Backed up notify.sh → notify.sh.backup"
  fi
fi

# --- OpenClaw skill installation ---
if [ "$OPENCLAW_MODE" = true ]; then
  echo ""
  echo "Installing OpenClaw skill..."

  OC_SKILL_DIR="$OPENCLAW_BASE/skills/peon-ping"
  mkdir -p "$OC_SKILL_DIR"

  cat > "$OC_SKILL_DIR/SKILL.md" <<'OCSKILL'
# peon-ping — Sound Notifications for OpenClaw

Play audio notifications when your OpenClaw agent completes tasks, encounters errors, or needs input.

## Usage

The adapter translates OpenClaw events into peon-ping sounds:

```bash
# Play a sound for an event
bash ~/.openclaw/hooks/peon-ping/adapters/openclaw.sh task.complete
bash ~/.openclaw/hooks/peon-ping/adapters/openclaw.sh task.error
bash ~/.openclaw/hooks/peon-ping/adapters/openclaw.sh input.required
bash ~/.openclaw/hooks/peon-ping/adapters/openclaw.sh session.start
```

## Controls

```bash
# Toggle sounds on/off
peon toggle

# Check status
peon status

# Switch sound pack
peon use <pack_name>

# List available packs
peon list
```

## OpenClaw Integration

Add to your agent's workflow by calling the adapter after key events:
- Sub-agent completion → `task.complete`
- Build/deploy errors → `task.error`
- Permission needed → `input.required`
- Session start → `session.start`

## Config

Edit `~/.openclaw/hooks/peon-ping/config.json` to change volume, active pack, or toggle categories.
OCSKILL

  echo "OpenClaw skill installed at $OC_SKILL_DIR/SKILL.md"

  # Copy the OpenClaw adapter
  if [ -f "$INSTALL_DIR/adapters/openclaw.sh" ]; then
    chmod +x "$INSTALL_DIR/adapters/openclaw.sh"
    echo "OpenClaw adapter ready at $INSTALL_DIR/adapters/openclaw.sh"
  fi

  echo ""
  echo "=== OpenClaw Installation complete! ==="
  echo ""
  echo "Config: $INSTALL_DIR/config.json"
  echo "Skill:  $OC_SKILL_DIR/SKILL.md"
  echo ""
  echo "Quick controls:"
  echo "  peon toggle        — toggle sounds"
  echo "  peon status        — check if sounds are paused"
  echo "  peon use <pack>    — switch sound pack"
  echo ""
  echo "Usage in your agent:"
  echo "  bash $INSTALL_DIR/adapters/openclaw.sh task.complete"
  echo ""
  echo "Ready to work!"
  exit 0
fi

# --- Update settings.json ---
# Always write hooks to GLOBAL settings — hooks need absolute paths and
# must work regardless of which project directory Claude Code runs in.
echo ""
echo "Updating Claude Code hooks in settings.json..."

HOOK_CMD="$GLOBAL_BASE/hooks/peon-ping/peon.sh"
HOOK_SETTINGS="$GLOBAL_BASE/settings.json"

python3 -c "
import json, os, sys

settings_path = '$(py_path "$HOOK_SETTINGS")'
hook_cmd = '$(py_path "$HOOK_CMD")'

# Load existing settings
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

hooks = settings.setdefault('hooks', {})

# Preserve existing command path if it resolves to the installed file
installed = os.path.realpath(hook_cmd)
for entries in hooks.values():
    for entry in entries:
        for hk in entry.get('hooks', []):
            cmd = hk.get('command', '')
            if 'peon-ping/' in cmd and cmd.endswith('/peon.sh'):
                resolved = os.path.realpath(os.path.expanduser(cmd))
                if resolved == installed:
                    hook_cmd = cmd
                break

peon_hook_sync = {
    'type': 'command',
    'command': hook_cmd,
    'timeout': 10
}
peon_hook_async = {
    'type': 'command',
    'command': hook_cmd,
    'timeout': 10,
    'async': True
}

# SessionStart runs sync so stderr messages (update notice, pause status,
# relay guidance) appear immediately. All other events run async.
sync_events = ('SessionStart',)
events = ['SessionStart', 'SessionEnd', 'SubagentStart', 'UserPromptSubmit', 'Stop', 'Notification', 'PermissionRequest', 'PostToolUseFailure', 'PreCompact']

# PostToolUseFailure only triggers on Bash failures — use matcher to limit scope
bash_only_events = ('PostToolUseFailure',)
# PreCompact supports manual|auto matchers — empty matcher fires for both

for event in events:
    hook = peon_hook_sync if event in sync_events else peon_hook_async
    if event in bash_only_events:
        peon_entry = dict(matcher='Bash', hooks=[hook])
    else:
        peon_entry = dict(matcher='', hooks=[hook])
    event_hooks = hooks.get(event, [])
    # Remove any existing notify.sh or peon.sh entries
    event_hooks = [
        h for h in event_hooks
        if not any(
            'notify.sh' in hk.get('command', '') or 'peon.sh' in hk.get('command', '')
            for hk in h.get('hooks', [])
        )
    ]
    event_hooks.append(peon_entry)
    hooks[event] = event_hooks

settings['hooks'] = hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('Hooks registered for: ' + ', '.join(events))
"

# Register UserPromptSubmit hook for /peon-ping-use command
# (Claude Code uses UserPromptSubmit; Cursor uses beforeSubmitPrompt — see below)
BEFORE_SUBMIT_HOOK="$GLOBAL_BASE/hooks/peon-ping/scripts/hook-handle-use.sh"

python3 -c "
import json, os, sys

settings_path = '$(py_path "$HOOK_SETTINGS")'
hook_cmd = '$(py_path "$BEFORE_SUBMIT_HOOK")'

# Load existing settings
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

hooks = settings.setdefault('hooks', {})

# Preserve existing command path if it resolves to the installed file
installed = os.path.realpath(hook_cmd)
for entries in hooks.values():
    for entry in entries:
        for hk in entry.get('hooks', []):
            cmd = hk.get('command', '')
            if 'peon-ping/' in cmd and '/hook-handle-use' in cmd:
                resolved = os.path.realpath(os.path.expanduser(cmd))
                if resolved == installed:
                    hook_cmd = cmd
                break

# Create UserPromptSubmit hook entry for /peon-ping-use handler
before_submit_hook = {
    'type': 'command',
    'command': hook_cmd,
    'timeout': 5
}

before_submit_entry = {
    'matcher': '',
    'hooks': [before_submit_hook]
}

# Register under UserPromptSubmit (valid Claude Code event)
event_hooks = hooks.get('UserPromptSubmit', [])
# Remove any existing hook-handle-use entries (keep peon.sh entries)
event_hooks = [
    h for h in event_hooks
    if not any(
        'hook-handle-use' in hk.get('command', '')
        for hk in h.get('hooks', [])
    )
]
event_hooks.append(before_submit_entry)
hooks['UserPromptSubmit'] = event_hooks

# Clean up stale beforeSubmitPrompt key if present (was incorrectly registered before)
if 'beforeSubmitPrompt' in hooks:
    del hooks['beforeSubmitPrompt']

settings['hooks'] = hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('UserPromptSubmit hook registered for /peon-ping-use command')
"

# Register beforeSubmitPrompt hook for Cursor IDE if ~/.cursor exists
CURSOR_DIR="$HOME/.cursor"
CURSOR_HOOKS_FILE="$CURSOR_DIR/hooks.json"
CURSOR_HOOK_CMD="$GLOBAL_BASE/hooks/peon-ping/scripts/hook-handle-use.sh"

if [ -d "$CURSOR_DIR" ]; then
  echo ""
  echo "Detected Cursor IDE installation, registering hooks..."
  
  python3 -c "
import json, os

hooks_file = '$(py_path "$CURSOR_HOOKS_FILE")'
hook_cmd = '$(py_path "$CURSOR_HOOK_CMD")'

# Load or create hooks.json
if os.path.exists(hooks_file):
    with open(hooks_file) as f:
        data = json.load(f)
else:
    data = {'version': 1, 'hooks': {}}

# Ensure version and hooks structure
if 'version' not in data:
    data['version'] = 1
if 'hooks' not in data:
    data['hooks'] = {}

hooks = data['hooks']

# Preserve existing command path if it resolves to the installed file
installed = os.path.realpath(hook_cmd)
def _find_existing(hooks_data, suffix):
    if isinstance(hooks_data, list):
        for h in hooks_data:
            cmd = h.get('command', '')
            if 'peon-ping/' in cmd and cmd.endswith(suffix):
                yield cmd
    elif isinstance(hooks_data, dict):
        for entries in hooks_data.values():
            for h in (entries if isinstance(entries, list) else []):
                cmd = h.get('command', '')
                if 'peon-ping/' in cmd and cmd.endswith(suffix):
                    yield cmd

for cmd in _find_existing(hooks, '/hook-handle-use'):
    resolved = os.path.realpath(os.path.expanduser(cmd))
    if resolved == installed:
        hook_cmd = cmd
        break

# Create beforeSubmitPrompt hook entry (Cursor format)
before_submit_hook = {
    'command': hook_cmd,
    'timeout': 5
}

# Handle both flat-array format [{event, command}] and dict format {event: [{command}]}
if isinstance(hooks, list):
    # Flat array format: remove existing peon-ping entries for this event
    hooks = [
        h for h in hooks
        if not (h.get('event') == 'beforeSubmitPrompt' and 'peon-ping/' in h.get('command', ''))
    ]
    before_submit_hook['event'] = 'beforeSubmitPrompt'
    hooks.append(before_submit_hook)
else:
    # Dict format
    event_hooks = hooks.get('beforeSubmitPrompt', [])
    event_hooks = [
        h for h in event_hooks
        if 'peon-ping' not in h.get('command', '')
    ]
    event_hooks.append(before_submit_hook)
    hooks['beforeSubmitPrompt'] = event_hooks

data['hooks'] = hooks

# Ensure directory exists
os.makedirs(os.path.dirname(hooks_file), exist_ok=True)

with open(hooks_file, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')

print('Cursor beforeSubmitPrompt hook registered')
"
fi

# --- Remove peon-ping hooks from project-level settings to prevent doubles ---
# Since hooks are always written to global settings now, clean any stale
# project-level hooks that may exist from older installs.
OTHER_SETTINGS="$LOCAL_BASE/settings.json"

if [ -f "$OTHER_SETTINGS" ] && [ "$OTHER_SETTINGS" != "$HOOK_SETTINGS" ]; then
  python3 -c "
import json, os

path = '$(py_path "$OTHER_SETTINGS")'
try:
    with open(path) as f:
        settings = json.load(f)
except Exception:
    exit(0)

hooks = settings.get('hooks', {})
changed = False
for event, entries in list(hooks.items()):
    filtered = [
        e for e in entries
        if not any('peon-ping/' in h.get('command', '') for h in e.get('hooks', []))
    ]
    if len(filtered) != len(entries):
        hooks[event] = filtered
        changed = True

if changed:
    settings['hooks'] = hooks
    with open(path, 'w') as f:
        json.dump(settings, f, indent=2)
        f.write('\n')
    print('Removed duplicate peon-ping hooks from ' + path)
" 2>/dev/null || true
fi

# --- Initialize state (fresh install only) ---
if [ "$UPDATING" = false ]; then
  echo '{}' > "$INSTALL_DIR/.state.json"
fi

# --- Test sound ---
echo ""
if [ "$PLATFORM" = "devcontainer" ]; then
  echo "Skipping test sound (devcontainer — start relay on host to test)"
  echo "  Host: peon relay"
  echo "  Test: curl -sf http://host.docker.internal:19998/health"
elif [ "$PLATFORM" = "ssh" ]; then
  echo "Skipping test sound (SSH — start relay on your local machine to test)"
  echo "  Local: peon relay --daemon"
  echo "  SSH:   ssh -R 19998:localhost:19998 <host>"
  echo "  Test:  curl -sf http://localhost:19998/health"
else
  echo "Testing sound..."
  ACTIVE_PACK=$(python3 -c "
import json
try:
    c = json.load(open('$INSTALL_DIR_PY/config.json'))
    print(c.get('active_pack', 'peon'))
except Exception:
    print('peon')
" 2>/dev/null)
  PACK_DIR="$INSTALL_DIR/packs/$ACTIVE_PACK"
  TEST_SOUND=$({ ls "$PACK_DIR/sounds/"*.wav "$PACK_DIR/sounds/"*.mp3 "$PACK_DIR/sounds/"*.ogg 2>/dev/null || true; } | head -1)
  if [ -n "$TEST_SOUND" ]; then
    if [ "$PLATFORM" = "mac" ]; then
      USE_SFX=$(python3 -c "
import json
try:
    c = json.load(open('$INSTALL_DIR_PY/config.json'))
    print(str(c.get('use_sound_effects_device', True)).lower())
except Exception:
    print('true')
" 2>/dev/null)
      if [ -x "$INSTALL_DIR/scripts/peon-play" ] && [ "$USE_SFX" != "false" ]; then
        "$INSTALL_DIR/scripts/peon-play" -v 0.3 "$TEST_SOUND"
      else
        afplay -v 0.3 "$TEST_SOUND"
      fi
    elif [ "$PLATFORM" = "wsl" ]; then
      wpath=$(wslpath -w "$TEST_SOUND")
      # Convert backslashes to forward slashes for file:/// URI
      wpath="${wpath//\\//}"
      powershell.exe -NoProfile -NonInteractive -Command "
        Add-Type -AssemblyName PresentationCore
        \$p = New-Object System.Windows.Media.MediaPlayer
        \$p.Open([Uri]::new('file:///$wpath'))
        \$p.Volume = 0.3
        Start-Sleep -Milliseconds 200
        \$p.Play()
        Start-Sleep -Seconds 3
        \$p.Close()
      " 2>/dev/null
    elif [ "$PLATFORM" = "linux" ]; then
      if command -v pw-play &>/dev/null; then
        LC_ALL=C pw-play --volume=0.3 "$TEST_SOUND" 2>/dev/null
      elif command -v paplay &>/dev/null; then
        paplay --volume="$(python3 -c "print(int(0.3 * 65536))")" "$TEST_SOUND" 2>/dev/null
      elif command -v ffplay &>/dev/null; then
        ffplay -nodisp -autoexit -volume 30 "$TEST_SOUND" 2>/dev/null
      elif command -v mpv &>/dev/null; then
        mpv --no-video --volume=30 "$TEST_SOUND" 2>/dev/null
      elif command -v aplay &>/dev/null; then
        aplay -q "$TEST_SOUND" 2>/dev/null
      fi
    elif [ "$PLATFORM" = "msys2" ]; then
      if command -v ffplay &>/dev/null; then
        ffplay -nodisp -autoexit -volume 30 "$TEST_SOUND" 2>/dev/null
      elif command -v mpv &>/dev/null; then
        mpv --no-video --volume=30 "$TEST_SOUND" 2>/dev/null
      elif command -v play &>/dev/null; then
        play -v 0.3 "$TEST_SOUND" 2>/dev/null
      else
        wpath=$(cygpath -w "$TEST_SOUND")
        powershell.exe -NoProfile -NonInteractive -File "$(cygpath -w "$INSTALL_DIR/scripts/win-play.ps1")" -path "$wpath" -vol 0.3 2>/dev/null
      fi
    fi
    echo "Sound working!"
  else
    echo "Warning: No sound files found. Sounds may not play."
  fi
fi

echo ""
if [ "$UPDATING" = true ]; then
  echo "=== Update complete! ==="
  echo ""
  echo "Updated: peon.sh, sound packs"
  echo "Preserved: config.json, state"
else
  echo "=== Installation complete! ==="
  echo ""
  echo "Config: $INSTALL_DIR/config.json"
  echo "  - Adjust volume, toggle categories, switch packs"
  echo ""
  echo "Uninstall: bash $INSTALL_DIR/uninstall.sh"
fi
echo ""
echo "Quick controls:"
echo "  /peon-ping-toggle  — toggle sounds in Claude Code"
if [ "$LOCAL_MODE" = false ]; then
  echo "  peon toggle        — toggle sounds from any terminal"
  echo "  peon status        — check if sounds are paused"
fi
echo ""
echo "Ready to work! (run 'peon toggle' to mute)"
