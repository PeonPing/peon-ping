{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.peon-ping;
  jsonFormat = pkgs.formats.json { };
  claudeHooksJsonFormat = pkgs.formats.json { };

  ogPacksVersion = "1.4.0";

  # Fetch the og-packs repository
  ogPacksSrc = pkgs.fetchzip {
    url = "https://github.com/PeonPing/og-packs/archive/refs/tags/v${ogPacksVersion}.tar.gz";
    sha256 = "sha256-jkybxNrXfc8GFPAi0Lb1rF8fsx8Z8K0k5gQxh8Y62Ds=";
    stripRoot = false;
  };
in
{
  options.programs.peon-ping = {
    enable = mkEnableOption "peon-ping — Warcraft III Peon voice lines for Claude Code hooks";

    package = mkOption {
      type = types.package;
      default = pkgs.peon-ping or (throw "peon-ping not available in nixpkgs. Use the flake package instead.");
      defaultText = literalExpression "pkgs.peon-ping";
      description = "The peon-ping package to use.";
    };

    settings = mkOption {
      type = jsonFormat.type;
      default = { };
      description = ''
        peon-ping configuration written to ~/.openpeon/config.json.
        See https://github.com/PeonPing/peon-ping for all options.
      '';
      example = literalExpression ''
        {
          default_pack = "peon";
          volume = 0.5;
          enabled = true;
          desktop_notifications = true;
          categories = {
            "session.start" = true;
            "task.complete" = true;
            "task.error" = true;
            "input.required" = true;
            "resource.limit" = true;
            "user.spam" = true;
            "task.acknowledge" = false;
          };
          pack_rotation = [ ];
          pack_rotation_mode = "random";
          annoyed_threshold = 3;
          annoyed_window_seconds = 10;
          silent_window_seconds = 0;
          suppress_subagent_complete = false;
          use_sound_effects_device = true;
        }
      '';
    };

    installPacks = mkOption {
      type = types.listOf (types.either types.str (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Name of the sound pack (used as directory name in ~/.openpeon/packs/)";
          };
          src = mkOption {
            type = types.either types.package types.path;
            description = ''
              Source for the pack. Can be:
              - A path to a local directory
              - Result of fetchFromGitHub, fetchzip, etc.
            '';
          };
        };
      }));
      default = [ ];
      description = ''
        List of sound packs to install automatically.

        Can be either:
        - A string (pack name from og-packs): "peon", "glados", etc.
        - An attrset with name and src fields for custom packs

        Common og-packs: peon, glados, sc_kerrigan, murloc, witcher
      '';
      example = literalExpression ''
        [
          "peon"
          "glados"
          {
            name = "mr_meeseeks";
            src = pkgs.fetchFromGitHub {
              owner = "kasperhendriks";
              repo = "openpeon-mrmeeseeks";
              rev = "main";  # or a commit hash
              sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
            };
          }
        ]
      '';
    };

    enableZshIntegration = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable Zsh completions and alias.
      '';
    };

    enableBashIntegration = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable Bash completions and alias.
      '';
    };

    claudeCodeIntegration = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to install Claude Code hook files under ~/.claude/hooks/peon-ping
        and merge peon-ping hook registrations into ~/.claude/settings.json.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Install base files from share into ~/.openpeon, excluding peon.sh which is wrapped by bin/peon.sh
    home.file.".openpeon" = {
      source = pkgs.runCommand "peon-home-files" {} ''
        cp -r ${cfg.package}/share/peon-ping $out
        chmod -R u+w $out
        rm -f $out/peon.sh
      '';
      recursive = true;
    };

    # PEON_DIR points at ~/.openpeon where all runtime files live.
    home.sessionVariables.PEON_DIR = "${config.home.homeDirectory}/.openpeon";

    # peon.sh in ~/.openpeon is the bin/peon wrapper (has runtime PATH baked in).
    home.file.".openpeon/peon.sh".source = "${cfg.package}/bin/peon";

    # Create the config file at the location peon-ping expects.
    # Overrides any config.json that may be present in the package.
    home.file.".openpeon/config.json".source = jsonFormat.generate "peon-ping-config" cfg.settings;

    home.file = mkIf cfg.claudeCodeIntegration {
      ".claude/hooks/peon-ping/peon.sh".source = "${cfg.package}/bin/peon";
      ".claude/hooks/peon-ping/scripts/hook-handle-use.sh".source = "${cfg.package}/share/peon-ping/scripts/hook-handle-use.sh";
      ".claude/hooks/peon-ping/scripts/hook-handle-rename.sh".source = "${cfg.package}/share/peon-ping/scripts/hook-handle-rename.sh";
    };

    home.activation.peonPingClaudeCodeHooks = mkIf cfg.claudeCodeIntegration (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      hooks_json='${claudeHooksJsonFormat.generate "peon-claude-hooks" {
        hooks = {
          SessionStart = [{
            matcher = "";
            hooks = [{
              type = "command";
              command = "${config.home.homeDirectory}/.claude/hooks/peon-ping/peon.sh";
              timeout = 10;
            }];
          }];
          SessionEnd = [{
            matcher = "";
            hooks = [{ type = "command"; command = "${config.home.homeDirectory}/.claude/hooks/peon-ping/peon.sh"; timeout = 10; async = true; }];
          }];
          SubagentStart = [{
            matcher = "";
            hooks = [{ type = "command"; command = "${config.home.homeDirectory}/.claude/hooks/peon-ping/peon.sh"; timeout = 10; async = true; }];
          }];
          UserPromptSubmit = [
            {
              matcher = "";
              hooks = [{ type = "command"; command = "${config.home.homeDirectory}/.claude/hooks/peon-ping/peon.sh"; timeout = 10; async = true; }];
            }
            {
              matcher = "";
              hooks = [
                { type = "command"; command = "${config.home.homeDirectory}/.claude/hooks/peon-ping/scripts/hook-handle-use.sh"; timeout = 5; }
                { type = "command"; command = "${config.home.homeDirectory}/.claude/hooks/peon-ping/scripts/hook-handle-rename.sh"; timeout = 5; }
              ];
            }
          ];
          Stop = [{
            matcher = "";
            hooks = [{ type = "command"; command = "${config.home.homeDirectory}/.claude/hooks/peon-ping/peon.sh"; timeout = 10; async = true; }];
          }];
          Notification = [{
            matcher = "";
            hooks = [{ type = "command"; command = "${config.home.homeDirectory}/.claude/hooks/peon-ping/peon.sh"; timeout = 10; async = true; }];
          }];
          PermissionRequest = [{
            matcher = "";
            hooks = [{ type = "command"; command = "${config.home.homeDirectory}/.claude/hooks/peon-ping/peon.sh"; timeout = 10; async = true; }];
          }];
          PostToolUseFailure = [{
            matcher = "Bash";
            hooks = [{ type = "command"; command = "${config.home.homeDirectory}/.claude/hooks/peon-ping/peon.sh"; timeout = 10; async = true; }];
          }];
          PreCompact = [{
            matcher = "";
            hooks = [{ type = "command"; command = "${config.home.homeDirectory}/.claude/hooks/peon-ping/peon.sh"; timeout = 10; async = true; }];
          }];
        };
      }}'

      settings_path="$HOME/.claude/settings.json"
      mkdir -p "$(dirname "$settings_path")"

      ${pkgs.python3}/bin/python3 - "$settings_path" "$hooks_json" <<'PY'
import json
import pathlib
import sys

settings_path = pathlib.Path(sys.argv[1]).expanduser()
hooks_path = pathlib.Path(sys.argv[2])

if settings_path.exists():
    settings = json.loads(settings_path.read_text())
else:
    settings = {}

incoming = json.loads(hooks_path.read_text())["hooks"]
hooks = settings.setdefault("hooks", {})

def command_contains(entry, needles):
    return any(any(needle in hook.get("command", "") for needle in needles) for hook in entry.get("hooks", []))

for event, event_hooks in incoming.items():
    existing = hooks.get(event, [])
    if event == "UserPromptSubmit":
        existing = [
            entry for entry in existing
            if not command_contains(entry, ("peon.sh", "hook-handle-use", "hook-handle-rename"))
        ]
    elif event == "PostToolUseFailure":
        existing = [entry for entry in existing if not command_contains(entry, ("peon.sh", "notify.sh"))]
    else:
        existing = [entry for entry in existing if not command_contains(entry, ("peon.sh", "notify.sh"))]
    hooks[event] = existing + event_hooks

    if event == "UserPromptSubmit" and "beforeSubmitPrompt" in hooks:
        hooks.pop("beforeSubmitPrompt", None)

settings["hooks"] = hooks
settings_path.write_text(json.dumps(settings, indent=2) + "\n")
PY
    '');

    # Install sound packs from og-packs and/or custom sources
    home.file.".openpeon/packs" = lib.mkIf (cfg.installPacks != [ ]) (let
      # Separate string pack names (og-packs) from custom pack specs
      ogPacks = lib.filter (p: lib.isString p) cfg.installPacks;
      customPacks = lib.filter (p: lib.isAttrs p) cfg.installPacks;
    in {
      source = pkgs.runCommand "peon-packs" { } ''
        set -euo pipefail
        mkdir -p $out

        # Install packs from og-packs
        ${lib.concatMapStringsSep "\n" (packName: ''
          if [ -d "${ogPacksSrc}/og-packs-${ogPacksVersion}/${packName}" ]; then
            cp -r "${ogPacksSrc}/og-packs-${ogPacksVersion}/${packName}" $out/
          else
            echo "Error: Pack '${packName}' not found in og-packs" >&2
            exit 1
          fi
        '') ogPacks}

        # Install custom packs
        ${lib.concatMapStringsSep "\n" (pack: ''
          if [ -d "${pack.src}" ]; then
            cp -r "${pack.src}" "$out/${pack.name}"
          else
            echo "Error: Custom pack '${pack.name}' source not found" >&2
            exit 1
          fi
        '') customPacks}
      '';
    });

    # Shell completions
    programs.zsh.initContent = mkIf cfg.enableZshIntegration ''
      source ${cfg.package}/share/zsh/site-functions/_peon 2>/dev/null || true
      alias peon="${cfg.package}/bin/peon"
    '';

    programs.bash.initExtra = mkIf cfg.enableBashIntegration ''
      source ${cfg.package}/share/bash-completion/completions/peon 2>/dev/null || true
      alias peon="${cfg.package}/bin/peon"
    '';
  };
}
