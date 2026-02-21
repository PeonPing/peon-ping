#!/bin/bash
# peon-ping tab completion for bash and zsh

_peon_completions() {
  local cur prev words cword packs_dir
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  words=("${COMP_WORDS[@]}")
  cword=$COMP_CWORD

  # Second-level completions
  if [ "$cword" -ge 2 ]; then
    local subcmd="${words[1]}"
    case "$subcmd" in
      packs)
        if [ "$cword" -eq 2 ]; then
          COMPREPLY=( $(compgen -W "list use next install install-local remove rotation" -- "$cur") )
        elif [ "$cword" -eq 3 ] && [ "$prev" = "rotation" ]; then
          COMPREPLY=( $(compgen -W "list add remove" -- "$cur") )
        elif [ "$cword" -eq 4 ] && [ "${words[2]}" = "rotation" ] && { [ "$prev" = "add" ] || [ "$prev" = "remove" ]; }; then
          packs_dir="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}/packs"
          [ ! -d "$packs_dir" ] && [ -d "$HOME/.openpeon/packs" ] && packs_dir="$HOME/.openpeon/packs"
          if [ -d "$packs_dir" ]; then
            local names
            names=$(find "$packs_dir" -maxdepth 2 \( -name manifest.json -o -name openpeon.json \) -exec dirname {} \; 2>/dev/null | xargs -I{} basename {} | sort)
            COMPREPLY=( $(compgen -W "$names" -- "$cur") )
          fi
        elif [ "$cword" -eq 3 ] && [ "$prev" = "install" ]; then
          COMPREPLY=( $(compgen -W "--all" -- "$cur") )
        elif [ "$cword" -eq 3 ] && [ "$prev" = "install-local" ]; then
          COMPREPLY=( $(compgen -d -- "$cur") )
        elif [ "$cword" -eq 3 ] && [ "$prev" = "list" ]; then
          COMPREPLY=( $(compgen -W "--registry" -- "$cur") )
        elif [ "$cword" -eq 3 ] && { [ "$prev" = "use" ] || [ "$prev" = "remove" ]; }; then
          packs_dir="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}/packs"
          [ ! -d "$packs_dir" ] && [ -d "$HOME/.openpeon/packs" ] && packs_dir="$HOME/.openpeon/packs"
          if [ -d "$packs_dir" ]; then
            local names
            names=$(find "$packs_dir" -maxdepth 2 \( -name manifest.json -o -name openpeon.json \) -exec dirname {} \; 2>/dev/null | xargs -I{} basename {} | sort)
            COMPREPLY=( $(compgen -W "$names" -- "$cur") )
          fi
        fi
        return 0 ;;
      notifications)
        if [ "$cword" -eq 2 ]; then
          COMPREPLY=( $(compgen -W "on off overlay standard test" -- "$cur") )
        fi
        return 0 ;;
      rotation)
        if [ "$cword" -eq 2 ]; then
          COMPREPLY=( $(compgen -W "random round-robin agentskill" -- "$cur") )
        fi
        return 0 ;;
      mobile)
        if [ "$cword" -eq 2 ]; then
          COMPREPLY=( $(compgen -W "ntfy pushover telegram on off status test" -- "$cur") )
        fi
        return 0 ;;
    esac
    return 0
  fi

  # Top-level commands
  COMPREPLY=( $(compgen -W "pause resume toggle status volume rotation packs notifications mobile relay help" -- "$cur") )
  return 0
}

# Only register completions in interactive shells (complete is unavailable in
# non-interactive contexts like Nix hook environments, CI runners, etc.)
case "$-" in
  *i*)
    # zsh compatibility: enable bashcompinit first
    if [ -n "$ZSH_VERSION" ]; then
      autoload -Uz bashcompinit 2>/dev/null && bashcompinit
    fi
    complete -F _peon_completions peon
    ;;
esac
