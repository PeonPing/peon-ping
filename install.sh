#!/bin/bash
# peon-ping installer
# Works both via `curl | bash` (downloads from GitHub) and local clone
# Re-running updates core files; sounds are version-controlled in the repo
set -euo pipefail

LOCAL_MODE=false
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_MODE=true ;;
  esac
done

if [ "$LOCAL_MODE" = true ]; then
  BASE_DIR="$PWD/.claude"
else
  BASE_DIR="$HOME/.claude"
fi
INSTALL_DIR="$BASE_DIR/hooks/peon-ping"
SETTINGS="$BASE_DIR/settings.json"
REPO_BASE="https://raw.githubusercontent.com/PeonPing/peon-ping/main"

# All available sound packs (add new packs here)
PACKS="acolyte_ru glados peon peon_fr peon_pl peon_ru peasant peasant_fr peasant_ru ra2_soviet_engineer sc_battlecruiser sc_firebat sc_kerrigan sc_medic sc_scv sc_tank sc_terran sc_vessel tf2_engineer"

# --- Platform detection ---
detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "mac" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi ;;
    *) echo "unknown" ;;
  esac
}
PLATFORM=$(detect_platform)

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
if [ "$PLATFORM" != "mac" ] && [ "$PLATFORM" != "wsl" ] && [ "$PLATFORM" != "linux" ]; then
  echo "Error: peon-ping requires macOS, Linux, or WSL (Windows Subsystem for Linux)"
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
fi

if [ ! -d "$BASE_DIR" ]; then
  if [ "$LOCAL_MODE" = true ]; then
    echo "Error: .claude/ not found in current directory. Is this a Claude Code project?"
  else
    echo "Error: ~/.claude/ not found. Is Claude Code installed?"
  fi
  exit 1
fi

# --- Detect if running from local clone or curl|bash ---
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
  CANDIDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  if [ -f "$CANDIDATE/peon.sh" ]; then
    SCRIPT_DIR="$CANDIDATE"
  fi
fi

# --- Install/update core files ---
for pack in $PACKS; do
  mkdir -p "$INSTALL_DIR/packs/$pack/sounds"
done

if [ -n "$SCRIPT_DIR" ]; then
  # Local clone — copy files directly (including sounds)
  cp -r "$SCRIPT_DIR/packs/"* "$INSTALL_DIR/packs/"
  cp "$SCRIPT_DIR/peon.sh" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/completions.bash" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/completions.fish" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/VERSION" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"
  if [ "$UPDATING" = false ]; then
    cp "$SCRIPT_DIR/config.json" "$INSTALL_DIR/"
  fi
else
  # curl|bash — download from GitHub (sounds are version-controlled in repo)
  echo "Downloading from GitHub..."
  curl -fsSL "$REPO_BASE/peon.sh" -o "$INSTALL_DIR/peon.sh"
  curl -fsSL "$REPO_BASE/completions.bash" -o "$INSTALL_DIR/completions.bash"
  curl -fsSL "$REPO_BASE/completions.fish" -o "$INSTALL_DIR/completions.fish"
  curl -fsSL "$REPO_BASE/VERSION" -o "$INSTALL_DIR/VERSION"
  curl -fsSL "$REPO_BASE/uninstall.sh" -o "$INSTALL_DIR/uninstall.sh"
  for pack in $PACKS; do
    curl -fsSL "$REPO_BASE/packs/$pack/manifest.json" -o "$INSTALL_DIR/packs/$pack/manifest.json"
  done
  # Download sound files for each pack
  for pack in $PACKS; do
    manifest="$INSTALL_DIR/packs/$pack/manifest.json"
    # Extract sound filenames from manifest and download each one
    python3 -c "
import json
m = json.load(open('$manifest'))
seen = set()
for cat in m.get('categories', {}).values():
    for s in cat.get('sounds', []):
        f = s['file']
        if f not in seen:
            seen.add(f)
            print(f)
" | while read -r sfile; do
      curl -fsSL "$REPO_BASE/packs/$pack/sounds/$sfile" -o "$INSTALL_DIR/packs/$pack/sounds/$sfile" </dev/null || echo "Warning: could not download $pack/sounds/$sfile (skipping)"
    done
  done
  if [ "$UPDATING" = false ]; then
    curl -fsSL "$REPO_BASE/config.json" -o "$INSTALL_DIR/config.json"
  fi
fi

chmod +x "$INSTALL_DIR/peon.sh"

# --- Install skill (slash command) ---
SKILL_DIR="$BASE_DIR/skills/peon-ping-toggle"
mkdir -p "$SKILL_DIR"
if [ "$LOCAL_MODE" = true ]; then
  SKILL_HOOK_CMD="bash .claude/hooks/peon-ping/peon.sh"
else
  SKILL_HOOK_CMD="bash ~/.claude/hooks/peon-ping/peon.sh"
fi
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/skills/peon-ping-toggle" ]; then
  cp "$SCRIPT_DIR/skills/peon-ping-toggle/SKILL.md" "$SKILL_DIR/"
  if [ "$LOCAL_MODE" = true ]; then
    sed -i.bak 's|bash ~/.claude/hooks/peon-ping/peon.sh|'"$SKILL_HOOK_CMD"'|g' "$SKILL_DIR/SKILL.md"
    rm -f "$SKILL_DIR/SKILL.md.bak"
  fi
elif [ -z "$SCRIPT_DIR" ]; then
  curl -fsSL "$REPO_BASE/skills/peon-ping-toggle/SKILL.md" -o "$SKILL_DIR/SKILL.md"
  if [ "$LOCAL_MODE" = true ]; then
    sed -i.bak 's|bash ~/.claude/hooks/peon-ping/peon.sh|'"$SKILL_HOOK_CMD"'|g' "$SKILL_DIR/SKILL.md"
    rm -f "$SKILL_DIR/SKILL.md.bak"
  fi
else
  echo "Warning: skills/peon-ping-toggle not found in local clone, skipping skill install"
fi

# --- Add shell alias (global install only) ---
if [ "$LOCAL_MODE" = false ]; then
  ALIAS_LINE='alias peon="bash ~/.claude/hooks/peon-ping/peon.sh"'
  for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rcfile" ] && ! grep -qF 'alias peon=' "$rcfile"; then
      echo "" >> "$rcfile"
      echo "# peon-ping quick controls" >> "$rcfile"
      echo "$ALIAS_LINE" >> "$rcfile"
      echo "Added peon alias to $(basename "$rcfile")"
    fi
  done

  # --- Add tab completion ---
  COMPLETION_LINE='[ -f ~/.claude/hooks/peon-ping/completions.bash ] && source ~/.claude/hooks/peon-ping/completions.bash'
  for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rcfile" ] && ! grep -qF 'peon-ping/completions.bash' "$rcfile"; then
      echo "$COMPLETION_LINE" >> "$rcfile"
      echo "Added tab completion to $(basename "$rcfile")"
    fi
  done
fi

# --- Add fish shell function + completions ---
FISH_CONFIG="$HOME/.config/fish/config.fish"
if [ -f "$FISH_CONFIG" ]; then
  FISH_FUNC='function peon; bash ~/.claude/hooks/peon-ping/peon.sh $argv; end'
  if ! grep -qF 'function peon' "$FISH_CONFIG"; then
    echo "" >> "$FISH_CONFIG"
    echo "# peon-ping quick controls" >> "$FISH_CONFIG"
    echo "$FISH_FUNC" >> "$FISH_CONFIG"
    echo "Added peon function to config.fish"
  fi
fi
FISH_COMPLETIONS_DIR="$HOME/.config/fish/completions"
if [ -d "$HOME/.config/fish" ]; then
  mkdir -p "$FISH_COMPLETIONS_DIR"
  cp "$INSTALL_DIR/completions.fish" "$FISH_COMPLETIONS_DIR/peon.fish"
  echo "Installed fish completions to $FISH_COMPLETIONS_DIR/peon.fish"
fi

# --- Verify sounds are installed ---
echo ""
for pack in $PACKS; do
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
  NOTIFY_SH="$HOME/.claude/hooks/notify.sh"
  if [ -f "$NOTIFY_SH" ]; then
    cp "$NOTIFY_SH" "$NOTIFY_SH.backup"
    echo ""
    echo "Backed up notify.sh → notify.sh.backup"
  fi
fi

# --- Update settings.json ---
echo ""
echo "Updating Claude Code hooks in settings.json..."

if [ "$LOCAL_MODE" = true ]; then
  HOOK_CMD=".claude/hooks/peon-ping/peon.sh"
else
  HOOK_CMD="$HOME/.claude/hooks/peon-ping/peon.sh"
fi

python3 -c "
import json, os, sys

settings_path = '$SETTINGS'
hook_cmd = '$HOOK_CMD'

# Load existing settings
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

hooks = settings.setdefault('hooks', {})

peon_hook = {
    'type': 'command',
    'command': hook_cmd,
    'timeout': 10
}

peon_entry = {
    'matcher': '',
    'hooks': [peon_hook]
}

# Events to register
events = ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification', 'PermissionRequest']

for event in events:
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

# --- Initialize state (fresh install only) ---
if [ "$UPDATING" = false ]; then
  echo '{}' > "$INSTALL_DIR/.state.json"
fi

# --- Test sound ---
echo ""
echo "Testing sound..."
ACTIVE_PACK=$(python3 -c "
import json
try:
    c = json.load(open('$INSTALL_DIR/config.json'))
    print(c.get('active_pack', 'peon'))
except:
    print('peon')
" 2>/dev/null)
PACK_DIR="$INSTALL_DIR/packs/$ACTIVE_PACK"
TEST_SOUND=$({ ls "$PACK_DIR/sounds/"*.wav "$PACK_DIR/sounds/"*.mp3 "$PACK_DIR/sounds/"*.ogg 2>/dev/null || true; } | head -1)
if [ -n "$TEST_SOUND" ]; then
  if [ "$PLATFORM" = "mac" ]; then
    afplay -v 0.3 "$TEST_SOUND"
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
      pw-play --volume=0.3 "$TEST_SOUND" 2>/dev/null
    elif command -v paplay &>/dev/null; then
      paplay --volume="$(python3 -c "print(int(0.3 * 65536))")" "$TEST_SOUND" 2>/dev/null
    elif command -v ffplay &>/dev/null; then
      ffplay -nodisp -autoexit -volume 30 "$TEST_SOUND" 2>/dev/null
    elif command -v mpv &>/dev/null; then
      mpv --no-video --volume=30 "$TEST_SOUND" 2>/dev/null
    elif command -v aplay &>/dev/null; then
      aplay -q "$TEST_SOUND" 2>/dev/null
    fi
  fi
  echo "Sound working!"
else
  echo "Warning: No sound files found. Sounds may not play."
fi

echo ""
if [ "$UPDATING" = true ]; then
  echo "=== Update complete! ==="
  echo ""
  echo "Updated: peon.sh, manifest.json"
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
  echo "  peon --toggle      — toggle sounds from any terminal"
  echo "  peon --status      — check if sounds are paused"
fi
echo ""
echo "Ready to work!"
