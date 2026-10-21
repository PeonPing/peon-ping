#!/bin/bash
# peon-ping uninstaller
# Removes peon hooks and optionally restores notify.sh
set -euo pipefail

# Refuse to run via pipe to ensure path resolution is safe and deterministic
if [ -z "${BASH_SOURCE[0]:-}" ] || [ ! -f "${BASH_SOURCE[0]}" ]; then
  echo "Error: Running the uninstaller via piped stdin (e.g., curl | bash) is not supported." >&2
  echo "Please run the local uninstaller script instead:" >&2
  echo "  bash \"\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}\"/hooks/peon-ping/uninstall.sh        # global" >&2
  echo "  bash .claude/hooks/peon-ping/uninstall.sh                                  # project-local" >&2
  exit 1
fi

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Hard gatekeeper for resolved INSTALL_DIR
if [ -z "$INSTALL_DIR" ] || [ "$INSTALL_DIR" = "/" ] || [ "$INSTALL_DIR" = "$HOME" ]; then
  echo "Error: Invalid or dangerous INSTALL_DIR: $INSTALL_DIR" >&2
  exit 1
fi

# Positive verification: Ensure this is actually a peon-ping directory
if [ ! -f "$INSTALL_DIR/peon.sh" ]; then
  echo "Security Error: Target directory does not appear to be a valid peon-ping installation (missing peon.sh)." >&2
  exit 1
fi


# Resolve and validate BASE_DIR
BASE_DIR="$(cd "$INSTALL_DIR/../.." && pwd)"
if [ -z "$BASE_DIR" ] || [ "$BASE_DIR" = "/" ] || [ "$BASE_DIR" = "$HOME" ]; then
  echo "Error: Invalid or dangerous BASE_DIR: $BASE_DIR" >&2
  exit 1
fi

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
install_dir = '$INSTALL_DIR'
_home = os.path.expanduser('~')
# peon's own notify.sh is either bundled under the peon-ping dir or the legacy
# <base>/hooks/notify.sh one level above it. Match absolute and ~-relative
# forms so we catch the path however the stored command spells it.
_legacy_notify = os.path.join(os.path.dirname(install_dir), 'notify.sh')
def _path_markers(p):
    m = [p]
    if p.startswith(_home):
        m.append('~' + p[len(_home):])
    return m
_peon_notify_markers = _path_markers(install_dir) + _path_markers(_legacy_notify)

def _is_peon_hook(cmd):
    # Only strip hooks peon installed. 'notify.sh' is a generic name other
    # tools register too (e.g. ~/.deckard/hooks/notify.sh), so qualify it to
    # peon's own copy; sibling tools' notify.sh hooks must survive.
    # 'hook-handle-' covers every handler peon registers (hook-handle-use.sh,
    # hook-handle-rename.sh, and any future hook-handle-*.sh) — install.sh
    # registers all of them, so uninstall must strip all of them.
    if 'peon.sh' in cmd or 'hook-handle-' in cmd:
        return True
    if 'notify.sh' in cmd:
        return any(m in cmd for m in _peon_notify_markers)
    return False

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
events_cleaned = []

for event, entries in list(hooks.items()):
    changed = False
    cleaned = []
    for h in entries:
        original_inner = h.get('hooks', [])
        kept = [
            hk for hk in original_inner
            if not _is_peon_hook(hk.get('command', ''))
        ]
        if len(kept) != len(original_inner):
            changed = True
        # Preserve entries that started empty (malformed/stale but not ours to
        # drop); only skip entries we emptied by stripping peon hooks.
        if kept or not original_inner:
            new_entry = dict(h)
            new_entry['hooks'] = kept
            cleaned.append(new_entry)
    if changed:
        events_cleaned.append(event)
    if cleaned:
        hooks[event] = cleaned
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
        if 'hook-handle-' not in h.get('command', '')
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

# Remove Copilot CLI hooks if ~/.copilot/hooks/peon-ping.json exists
_remove_copilot_hooks() {
  local copilot_hooks="$HOME/.copilot/hooks/peon-ping.json"
  [ -f "$copilot_hooks" ] || return 0
  rm -f "$copilot_hooks"
  echo "Removed Copilot CLI hooks: $copilot_hooks"
}

# Remove this install's peon-ping hooks from pw code's settings, keeping
# everything else. Hooks that point at a different, still-present peon-ping
# install (e.g. the global one when uninstalling a project-local copy) stay.
_remove_pwcode_hooks() {
  local pw_settings="${XDG_CONFIG_HOME:-$HOME/.config}/pw/code.json"
  [ -f "$pw_settings" ] || return 0
  PW_SETTINGS="$pw_settings" PEON_INSTALL_DIR="$INSTALL_DIR" python3 -c "
import json, os, shlex, tempfile
path = os.environ['PW_SETTINGS']
install_dir = os.environ['PEON_INSTALL_DIR'].rstrip('/')
install_real = os.path.realpath(install_dir)
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    raise SystemExit(0)
hooks = data.get('hooks') if isinstance(data, dict) else None
if not isinstance(hooks, dict):
    raise SystemExit(0)
def is_ours(hook):
    if not isinstance(hook, dict):
        return False
    cmd = str(hook.get('command', ''))
    if 'peon-ping/' not in cmd:
        return False
    if install_dir + '/' in cmd:
        return True
    try:
        parts = shlex.split(cmd)
    except ValueError:
        parts = cmd.split()
    for p in parts:
        if 'peon-ping/' not in p:
            continue
        p = os.path.expanduser(p)
        if not os.path.isabs(p):
            continue
        if os.path.realpath(p).startswith(install_real + os.sep):
            return True
        # A stale entry whose peon-ping install is already gone.
        if '/hooks/peon-ping/' in p and not os.path.exists(p):
            return True
    return False
changed = False
for evt in list(hooks):
    groups = hooks[evt]
    if not isinstance(groups, list):
        continue
    kept_groups = []
    evt_changed = False
    for g in groups:
        inner = g.get('hooks') if isinstance(g, dict) else None
        if not isinstance(inner, list):
            kept_groups.append(g)
            continue
        kept = [h for h in inner if not is_ours(h)]
        if len(kept) == len(inner):
            kept_groups.append(g)
            continue
        evt_changed = True
        if kept:
            kept_groups.append(dict(g, hooks=kept))
    if not evt_changed:
        continue
    changed = True
    if kept_groups:
        hooks[evt] = kept_groups
    else:
        del hooks[evt]
if not changed:
    raise SystemExit(0)
if not hooks:
    del data['hooks']
# Write through a symlinked code.json (dotfiles managers) to its target.
target = os.path.realpath(path)
mode = os.stat(target).st_mode & 0o777
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(target), prefix='.code.json.')
try:
    with os.fdopen(fd, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\\n')
    os.chmod(tmp, mode)
    os.replace(tmp, target)
except BaseException:
    os.unlink(tmp)
    raise
print('Removed pw code hooks from ' + path)
" || echo "Warning: could not remove peon-ping hooks from $pw_settings"
}

# Remove Grok Build hooks if ~/.grok/hooks/peon-ping.json exists
_remove_grok_hooks() {
  local grok_hooks="$HOME/.grok/hooks/peon-ping.json"
  [ -f "$grok_hooks" ] || return 0
  rm -f "$grok_hooks"
  echo "Removed Grok Build hooks: $grok_hooks"
}

# Remove only this installation's Codex handlers from either representation.
_remove_codex_hooks() {
  local codex_dir="${CODEX_HOME:-$HOME/.codex}"
  local codex_config="$codex_dir/config.toml"
  [ -f "$codex_config" ] || [ -f "$codex_dir/hooks.json" ] || return 0
  local codex_config_helper="$INSTALL_DIR/scripts/codex-config.py"
  if [ -f "$codex_config_helper" ]; then
    python3 "$codex_config_helper" clean \
      --config "$codex_config" \
      --install-dir "$INSTALL_DIR"
    echo "Removed peon-ping Codex hooks from $codex_dir"
  else
    echo "Error: cannot safely remove Codex hooks because scripts/codex-config.py is missing"
    echo "Re-run the peon-ping installer to restore the helper, then uninstall again."
    return 1
  fi
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

# Remove Copilot CLI hooks
echo "Removing Copilot CLI hooks..."
_remove_copilot_hooks

# Remove Grok Build hooks
echo "Removing Grok Build hooks..."
_remove_grok_hooks

# Remove pw code hooks
echo "Removing pw code hooks..."
_remove_pwcode_hooks

# Remove OpenAI Codex hooks
echo "Removing Codex hooks..."
_remove_codex_hooks

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

# Delete lines from a file, working for both regular files and symlinks.
# BSD sed's `-i` aborts on a symlinked target ("in-place editing only works
# for regular files"), which breaks the common dotfiles setup where rc files
# are symlinks. Filter through a temp file and copy the content back with a
# redirect, which follows the symlink and preserves it (and its target).
_delete_lines() {
  local file="$1"
  shift
  local tmp
  tmp="$(mktemp)"
  sed "$@" "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

# --- Remove shell alias and completions from rc files ---
for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$rcfile" ] && [ -w "$rcfile" ]; then
    if grep -qF 'alias peon=' "$rcfile" || grep -qF 'peon-ping/completions.bash' "$rcfile"; then
      # Remove peon-ping lines (alias, completion, comment)
      _delete_lines "$rcfile" \
        -e '/# peon-ping quick controls/d' \
        -e '/alias peon=/d' \
        -e '/peon-ping\/completions\.bash/d'
      echo "Cleaned peon-ping lines from $(basename "$rcfile")"
    fi
  fi
done

# --- Remove fish function and completions ---
FISH_CONFIG="$HOME/.config/fish/config.fish"
if [ -f "$FISH_CONFIG" ] && [ -w "$FISH_CONFIG" ]; then
  if grep -qF 'function peon' "$FISH_CONFIG"; then
    _delete_lines "$FISH_CONFIG" \
      -e '/# peon-ping quick controls/d' \
      -e '/function peon;.*peon\.sh/d'
    echo "Cleaned peon-ping lines from config.fish"
  fi
fi
FISH_COMPLETIONS="$HOME/.config/fish/completions/peon.fish"
if [ -f "$FISH_COMPLETIONS" ]; then
  rm "$FISH_COMPLETIONS"
  echo "Removed fish completions"
fi

# --- Remove skill directories ---
for SKILL_NAME in peon-ping-toggle peon-ping-config peon-ping-use peon-ping-log peon-ping-rename; do
  SKILL_DIR="$BASE_DIR/skills/$SKILL_NAME"
  if [ -d "$SKILL_DIR" ]; then
    # Sanity check before deletion
    if [ -z "$SKILL_DIR" ] || [ "$SKILL_DIR" = "/" ] || [ "$SKILL_DIR" = "$HOME" ]; then
      echo "Security Error: Refusing to delete $SKILL_DIR" >&2
      exit 1
    fi
    echo ""
    echo "Removing $SKILL_DIR..."
    rm -rf "$SKILL_DIR"
    echo "Removed $SKILL_NAME skill"
  fi
done

# --- Remove install directory ---
if [ -d "$INSTALL_DIR" ]; then
  # Sanity check before deletion
  if [ -z "$INSTALL_DIR" ] || [ "$INSTALL_DIR" = "/" ] || [ "$INSTALL_DIR" = "$HOME" ]; then
    echo "Security Error: Refusing to delete $INSTALL_DIR" >&2
    exit 1
  fi
  echo ""
  echo "Removing $INSTALL_DIR..."
  rm -rf "$INSTALL_DIR"
  echo "Removed"
fi

echo ""
echo "=== Uninstall complete ==="
echo "Me go now."
