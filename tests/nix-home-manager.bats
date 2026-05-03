#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  MODULE="$REPO_ROOT/nix/hm-module.nix"
}

@test "home-manager module merges home.file definitions" {
  grep -q 'home.file = mkMerge' "$MODULE"
}

@test "home-manager module parses as a Nix expression" {
  command -v nix-instantiate >/dev/null || skip "nix-instantiate is not available"

  run nix-instantiate --parse "$MODULE"
  [ "$status" -eq 0 ]
}

@test "home-manager module exposes Claude Code integration option" {
  grep -q 'claudeCodeIntegration = mkOption' "$MODULE"
}

@test "home-manager Claude Code integration installs hook files and settings merge" {
  grep -q '".claude/hooks/peon-ping/peon.sh"' "$MODULE"
  grep -q '".claude/hooks/peon-ping/scripts/hook-handle-use.sh"' "$MODULE"
  grep -q 'settings_path=\"\$HOME/.claude/settings.json\"' "$MODULE"
  grep -q 'hooks.pop("beforeSubmitPrompt", None)' "$MODULE"
}
