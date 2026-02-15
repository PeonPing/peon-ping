#!/bin/bash
# peon-ping uninstaller
# Removes peon hooks and optionally restores notify.sh
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$INSTALL_DIR/../.." && pwd)"
SETTINGS="$BASE_DIR/settings.json"

IS_LOCAL=true
if [ "$BASE_DIR" = "$HOME/.claude" ]; then
  IS_LOCAL=false
fi

# Hooks are always written to global settings (install.sh design).
# When uninstalling a local install, also clean hooks from global settings.
GLOBAL_SETTINGS="$HOME/.claude/settings.json"

NOTIFY_BACKUP="$BASE_DIR/hooks/notify.sh.backup"
NOTIFY_SH="$BASE_DIR/hooks/notify.sh"

echo "=== peon-ping uninstaller ==="
echo ""

# --- Remove hook entries from settings.json ---
# Clean both local and global settings files (if they differ).
_remove_peon_hooks() {
  local target="$1"
  [ -f "$target" ] || return 0
  python3 -c "
import json, os

settings_path = '$target'
with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
events_cleaned = []

for event, entries in list(hooks.items()):
    original_count = len(entries)
    entries = [
        h for h in entries
        if not any(
            'peon.sh' in hk.get('command', '') or 'hook-handle-use.sh' in hk.get('command', '')
            for hk in h.get('hooks', [])
        )
    ]
    if len(entries) < original_count:
        events_cleaned.append(event)
    if entries:
        hooks[event] = entries
    else:
        del hooks[event]

settings['hooks'] = hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

if events_cleaned:
    print('Removed hooks for: ' + ', '.join(events_cleaned))
else:
    print('No peon hooks found in settings.json')
"
}

# Remove Cursor hooks if ~/.cursor/hooks.json exists
_remove_cursor_hooks() {
  local cursor_hooks="$HOME/.cursor/hooks.json"
  [ -f "$cursor_hooks" ] || return 0
  
  python3 -c "
import json, os

hooks_path = '$cursor_hooks'
try:
    with open(hooks_path) as f:
        data = json.load(f)
except:
    exit(0)

if 'hooks' not in data:
    exit(0)

hooks = data['hooks']
events_cleaned = []

for event, entries in list(hooks.items()):
    if not isinstance(entries, list):
        continue
    original_count = len(entries)
    entries = [
        h for h in entries
        if not ('hook-handle-use' in h.get('command', ''))
    ]
    if len(entries) < original_count:
        events_cleaned.append(event)
    if entries:
        hooks[event] = entries
    else:
        del hooks[event]

data['hooks'] = hooks

with open(hooks_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')

if events_cleaned:
    print('Removed Cursor hooks for: ' + ', '.join(events_cleaned))
"
}

echo "Removing peon hooks from settings.json..."
_remove_peon_hooks "$SETTINGS"

# For local installs, hooks live in global settings — clean those too.
if [ "$IS_LOCAL" = true ] && [ "$SETTINGS" != "$GLOBAL_SETTINGS" ]; then
  echo "Removing peon hooks from global settings.json..."
  _remove_peon_hooks "$GLOBAL_SETTINGS"
fi

# Remove Cursor hooks
echo "Removing Cursor hooks..."
_remove_cursor_hooks

# --- Restore notify.sh backup (global install only) ---
if [ "$IS_LOCAL" = false ] && [ -f "$NOTIFY_BACKUP" ]; then
  echo ""
  read -p "Restore original notify.sh from backup? [Y/n] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    # Re-register notify.sh for its original events
    python3 -c "
import json

settings_path = '$SETTINGS'
with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})
notify_hook = {
    'matcher': '',
    'hooks': [{
        'type': 'command',
        'command': '$NOTIFY_SH',
        'timeout': 10
    }]
}

for event in ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification']:
    event_hooks = hooks.get(event, [])
    # Don't add if already present
    has_notify = any(
        'notify.sh' in hk.get('command', '')
        for h in event_hooks
        for hk in h.get('hooks', [])
    )
    if not has_notify:
        event_hooks.append(notify_hook)
    hooks[event] = event_hooks

settings['hooks'] = hooks
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('Restored notify.sh hooks for: SessionStart, UserPromptSubmit, Stop, Notification')
"
    cp "$NOTIFY_BACKUP" "$NOTIFY_SH"
    rm "$NOTIFY_BACKUP"
    echo "notify.sh restored"
  fi
fi

# --- Remove shell alias and completions from rc files ---
for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$rcfile" ] && [ -w "$rcfile" ]; then
    if grep -qF 'alias peon=' "$rcfile" || grep -qF 'peon-ping/completions.bash' "$rcfile"; then
      # Remove peon-ping lines (alias, completion, comment)
      sed -i.bak \
        -e '/# peon-ping quick controls/d' \
        -e '/alias peon=/d' \
        -e '/peon-ping\/completions\.bash/d' \
        "$rcfile"
      rm -f "${rcfile}.bak"
      echo "Cleaned peon-ping lines from $(basename "$rcfile")"
    fi
  fi
done

# --- Remove fish function and completions ---
FISH_CONFIG="$HOME/.config/fish/config.fish"
if [ -f "$FISH_CONFIG" ] && [ -w "$FISH_CONFIG" ]; then
  if grep -qF 'function peon' "$FISH_CONFIG"; then
    sed -i.bak \
      -e '/# peon-ping quick controls/d' \
      -e '/function peon;.*peon\.sh/d' \
      "$FISH_CONFIG"
    rm -f "${FISH_CONFIG}.bak"
    echo "Cleaned peon-ping lines from config.fish"
  fi
fi
FISH_COMPLETIONS="$HOME/.config/fish/completions/peon.fish"
if [ -f "$FISH_COMPLETIONS" ]; then
  rm "$FISH_COMPLETIONS"
  echo "Removed fish completions"
fi

# --- Remove skill directories ---
for SKILL_NAME in peon-ping-toggle peon-ping-config peon-ping-use; do
  SKILL_DIR="$BASE_DIR/skills/$SKILL_NAME"
  if [ -d "$SKILL_DIR" ]; then
    echo ""
    echo "Removing $SKILL_DIR..."
    rm -rf "$SKILL_DIR"
    echo "Removed $SKILL_NAME skill"
  fi
done

# --- Remove install directory ---
if [ -d "$INSTALL_DIR" ]; then
  echo ""
  echo "Removing $INSTALL_DIR..."
  rm -rf "$INSTALL_DIR"
  echo "Removed"
fi

echo ""
echo "=== Uninstall complete ==="
echo "Me go now."
