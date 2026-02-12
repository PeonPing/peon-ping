#!/bin/bash
# peon-ping uninstaller
# Removes peon hooks and optionally restores notify.sh
set -euo pipefail

# Derive CLAUDE_DIR from script location if inside a claude directory hierarchy
CLAUDE_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
  _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  _candidate="$(cd "$_script_dir/../.." 2>/dev/null && pwd)"
  if [[ "$_script_dir" == */hooks/peon-ping ]] && [ -f "$_candidate/settings.json" ]; then
    CLAUDE_DIR="$_candidate"
  fi
fi
if [ -z "$CLAUDE_DIR" ]; then
  CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
fi
INSTALL_DIR="$CLAUDE_DIR/hooks/peon-ping"
SETTINGS="$CLAUDE_DIR/settings.json"
NOTIFY_BACKUP="$CLAUDE_DIR/hooks/notify.sh.backup"
NOTIFY_SH="$CLAUDE_DIR/hooks/notify.sh"

echo "=== peon-ping uninstaller ==="
echo ""

# --- Remove hook entries from settings.json ---
if [ -f "$SETTINGS" ]; then
  echo "Removing peon hooks from settings.json..."
  python3 -c "
import json, os

settings_path = '$SETTINGS'
with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
events_cleaned = []

for event, entries in list(hooks.items()):
    original_count = len(entries)
    entries = [
        h for h in entries
        if not any(
            'peon.sh' in hk.get('command', '')
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
fi

# --- Restore notify.sh backup ---
if [ -f "$NOTIFY_BACKUP" ]; then
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
