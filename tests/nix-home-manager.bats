#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  MODULE="$REPO_ROOT/nix/hm-module.nix"
}

@test "home-manager module exposes Claude Code integration option" {
  grep -q 'claudeCodeIntegration = mkOption' "$MODULE"
}

@test "home-manager Claude Code integration installs hook files and settings merge" {
  grep -q '".claude/hooks/peon-ping/peon.sh".source' "$MODULE"
  grep -q '".claude/hooks/peon-ping/scripts/hook-handle-use.sh".source' "$MODULE"
  grep -q 'settings_path=\"\$HOME/.claude/settings.json\"' "$MODULE"
  grep -q 'hooks.pop("beforeSubmitPrompt", None)' "$MODULE"
}
