#compdef peon
# peon-ping tab completion for zsh (native)

_peon() {
  local -a toplevel_cmds packs_cmds packs_rotation_cmds notif_cmds notif_position_cmds
  local -a debug_cmds mobile_cmds rotation_cmds logs_cmds

  toplevel_cmds=(
    'pause:Mute sounds'
    'resume:Unmute sounds'
    'mute:Alias for pause — mute sounds'
    'unmute:Alias for resume — unmute sounds'
    'toggle:Toggle mute on/off'
    'status:Show current status'
    'volume:Get or set volume level'
    'rotation:Get or set pack rotation mode'
    'packs:Manage sound packs'
    'notifications:Control desktop notifications'
    'mobile:Configure mobile push notifications'
    'relay:Start audio relay for devcontainers'
    'debug:Toggle debug logging'
    'logs:View or manage log files'
    'help:Show help message'
  )

  packs_cmds=(
    'list:List installed sound packs'
    'use:Switch to a specific pack'
    'next:Cycle to the next pack'
    'install:Download and install new packs'
    'install-local:Install a pack from a local directory'
    'remove:Remove specific packs'
    'rotation:Manage pack rotation list'
    'bind:Bind a pack to the current directory'
    'unbind:Remove pack binding for current directory'
    'bindings:List all directory-to-pack bindings'
    'community:List all packs from registry'
    'search:Search registry packs by name'
  )

  packs_rotation_cmds=(
    'list:Show current rotation list and mode'
    'add:Add pack(s) to rotation'
    'remove:Remove pack(s) from rotation'
    'clear:Clear all packs from rotation'
  )

  notif_cmds=(
    'on:Enable desktop notifications'
    'off:Disable desktop notifications'
    'overlay:Use large overlay banners'
    'standard:Use standard system notifications'
    'position:Get or set overlay position'
    'dismiss:Get or set auto-dismiss time'
    'label:Get, set, or reset notification label'
    'test:Send test notification'
  )

  notif_position_cmds=(
    'top-center:Top center (default)'
    'top-right:Top right corner'
    'top-left:Top left corner'
    'bottom-right:Bottom right corner'
    'bottom-left:Bottom left corner'
    'bottom-center:Bottom center'
  )

  debug_cmds=(
    'on:Enable debug logging'
    'off:Disable debug logging'
    'status:Show debug logging status'
  )

  mobile_cmds=(
    'ntfy:Set up ntfy.sh notifications'
    'pushover:Set up Pushover notifications'
    'telegram:Set up Telegram notifications'
    'on:Enable mobile notifications'
    'off:Disable mobile notifications'
    'status:Show mobile config'
    'test:Send test notification'
  )

  rotation_cmds=(
    'random:Pick a random pack each session (default)'
    'round-robin:Cycle through packs in order'
    'agentskill:Assign pack per session via /peon-ping-use'
  )

  logs_cmds=(
    '--last:Show last N lines from latest log'
    '--session:Show entries for a session'
    '--prune:Delete old log files'
    '--clear:Delete all log files'
  )

  # helper: list installed pack names
  _peon_pack_names() {
    local packs_dir="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}/packs"
    [[ ! -d "$packs_dir" ]] && [[ -d "$HOME/.openpeon/packs" ]] && packs_dir="$HOME/.openpeon/packs"
    if [[ -d "$packs_dir" ]]; then
      local -a names
      names=( ${packs_dir}/*(/:t) )
      # filter to only dirs containing a manifest
      names=( ${(M)names:#*(#e)} )
      local -a valid
      for n in "${names[@]}"; do
        [[ -f "$packs_dir/$n/manifest.json" || -f "$packs_dir/$n/openpeon.json" ]] && valid+=("$n")
      done
      compadd -a valid
    fi
  }

  case "$words[2]" in
    packs)
      case "$words[3]" in
        rotation)
          case "$words[4]" in
            add|remove)
              _peon_pack_names
              ;;
            *)
              _describe 'rotation command' packs_rotation_cmds
              ;;
          esac
          ;;
        use|remove|bind)
          _peon_pack_names
          ;;
        install)
          compadd -- --all
          ;;
        install-local)
          _directories
          ;;
        list)
          compadd -- --registry
          ;;
        *)
          _describe 'packs command' packs_cmds
          ;;
      esac
      ;;
    notifications)
      case "$words[3]" in
        position)
          _describe 'position' notif_position_cmds
          ;;
        label)
          compadd -- reset
          ;;
        *)
          _describe 'notifications command' notif_cmds
          ;;
      esac
      ;;
    rotation)
      _describe 'rotation mode' rotation_cmds
      ;;
    status)
      compadd -- --verbose
      ;;
    mobile)
      _describe 'mobile command' mobile_cmds
      ;;
    debug)
      _describe 'debug command' debug_cmds
      ;;
    logs)
      case "$words[3]" in
        --session)
          compadd -- --all
          ;;
        *)
          _describe 'logs option' logs_cmds
          ;;
      esac
      ;;
    *)
      _describe 'peon command' toplevel_cmds
      ;;
  esac
}

_peon "$@"
