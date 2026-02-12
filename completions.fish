# peon-ping tab completion for fish shell

# Top-level options (no repeated suggestions)
complete -c peon -f
complete -c peon -l pause -d "Pause sound notifications"
complete -c peon -l resume -d "Resume sound notifications"
complete -c peon -l toggle -d "Toggle sound notifications"
complete -c peon -l status -d "Show current status"
complete -c peon -l packs -d "List available sound packs"
complete -c peon -l pack -d "Switch active sound pack" -r -a "(
  set -l packs_dir (set -q CLAUDE_PEON_DIR; and echo \$CLAUDE_PEON_DIR; or echo \$HOME/.claude/hooks/peon-ping)/packs
  if test -d \$packs_dir
    for manifest in \$packs_dir/*/manifest.json
      basename (dirname \$manifest)
    end
  end
)"
complete -c peon -l remove -d "Remove installed packs" -r -a "(
  set -l packs_dir (set -q CLAUDE_PEON_DIR; and echo \$CLAUDE_PEON_DIR; or echo \$HOME/.claude/hooks/peon-ping)/packs
  if test -d \$packs_dir
    for manifest in \$packs_dir/*/manifest.json
      basename (dirname \$manifest)
    end
  end
)"
complete -c peon -l notifications-on -d "Enable desktop notifications"
complete -c peon -l notifications-off -d "Disable desktop notifications"
complete -c peon -l help -d "Show help message"
