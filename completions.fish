# peon-ping tab completion for fish shell

# Helper: true when no subcommand has been given yet
function __peon_no_subcommand
  set -l cmd (commandline -opc)
  test (count $cmd) -eq 1
end

# Helper: true when the given subcommand is active
function __peon_using_subcommand
  set -l cmd (commandline -opc)
  test (count $cmd) -ge 2; and test $cmd[2] = $argv[1]
end

# Helper: true when packs subcommand is active and second arg matches
function __peon_packs_subcommand
  set -l cmd (commandline -opc)
  test (count $cmd) -ge 3; and test $cmd[2] = packs; and test $cmd[3] = $argv[1]
end

# Disable file completions
complete -c peon -f

# Top-level commands (only when no subcommand given)
complete -c peon -n __peon_no_subcommand -a pause -d "Mute sounds"
complete -c peon -n __peon_no_subcommand -a resume -d "Unmute sounds"
complete -c peon -n __peon_no_subcommand -a toggle -d "Toggle mute on/off"
complete -c peon -n __peon_no_subcommand -a status -d "Show current status"
complete -c peon -n __peon_no_subcommand -a packs -d "Manage sound packs"
complete -c peon -n __peon_no_subcommand -a notifications -d "Control desktop notifications"
complete -c peon -n __peon_no_subcommand -a relay -d "Start audio relay for devcontainers"
complete -c peon -n __peon_no_subcommand -a help -d "Show help message"

# packs subcommands
complete -c peon -n "__peon_using_subcommand packs" -a list -d "List installed sound packs"
complete -c peon -n "__peon_using_subcommand packs" -a use -d "Switch to a specific pack"
complete -c peon -n "__peon_using_subcommand packs" -a next -d "Cycle to the next pack"
complete -c peon -n "__peon_using_subcommand packs" -a remove -d "Remove specific packs"

# Pack name completions for 'packs use' and 'packs remove'
complete -c peon -n "__peon_packs_subcommand use" -a "(
  set -l packs_dir (set -q CLAUDE_PEON_DIR; and echo \$CLAUDE_PEON_DIR; or echo \$HOME/.claude/hooks/peon-ping)/packs
  if test -d \$packs_dir
    for manifest in \$packs_dir/*/manifest.json
      basename (dirname \$manifest)
    end
  end
)"
complete -c peon -n "__peon_packs_subcommand remove" -a "(
  set -l packs_dir (set -q CLAUDE_PEON_DIR; and echo \$CLAUDE_PEON_DIR; or echo \$HOME/.claude/hooks/peon-ping)/packs
  if test -d \$packs_dir
    for manifest in \$packs_dir/*/manifest.json
      basename (dirname \$manifest)
    end
  end
)"

# notifications subcommands
complete -c peon -n "__peon_using_subcommand notifications" -a on -d "Enable desktop notifications"
complete -c peon -n "__peon_using_subcommand notifications" -a off -d "Disable desktop notifications"
