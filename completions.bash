#!/bin/bash
# peon-ping tab completion for bash and zsh

_peon_completions() {
  local cur prev opts packs_dir
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  # Top-level options
  opts="--pause --resume --toggle --status --packs --pack --remove --notifications-on --notifications-off --help"

  if [ "$prev" = "--pack" ] || [ "$prev" = "--remove" ]; then
    # Complete pack names by scanning manifest files
    packs_dir="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}/packs"
    if [ -d "$packs_dir" ]; then
      local names
      names=$(find "$packs_dir" -maxdepth 2 -name manifest.json -exec dirname {} \; 2>/dev/null | xargs -I{} basename {} | sort)
      COMPREPLY=( $(compgen -W "$names" -- "$cur") )
    fi
    return 0
  fi

  COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
  return 0
}

# zsh compatibility: enable bashcompinit first
if [ -n "$ZSH_VERSION" ]; then
  autoload -Uz bashcompinit 2>/dev/null && bashcompinit
fi

complete -F _peon_completions peon
