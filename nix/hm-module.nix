{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.peon-ping;
  jsonFormat = pkgs.formats.json { };
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
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of sound pack names to install automatically.
        These will be downloaded from the OpenPeon registry.
        Common packs: peon, glados, sc_kerrigan, murloc, witcher
      '';
      example = literalExpression ''[ "peon" "glados" ]'';
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
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Create the config file at the legacy location peon-ping expects
    home.file.".openpeon/config.json".source = jsonFormat.generate "peon-ping-config" cfg.settings;

    # Install sound packs via activation script (only if packs specified)
    home.activation.peonPacksInstall = lib.mkIf (cfg.installPacks != [ ]) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${cfg.package}/bin/peon packs install ${lib.concatStringsSep "," cfg.installPacks}
      ''
    );

    # Shell completions
    programs.zsh.initExtra = mkIf cfg.enableZshIntegration ''
      source ${cfg.package}/share/zsh/site-functions/_peon 2>/dev/null || true
      alias peon="${cfg.package}/bin/peon"
    '';

    programs.bash.initExtra = mkIf cfg.enableBashIntegration ''
      source ${cfg.package}/share/bash-completion/completions/peon 2>/dev/null || true
      alias peon="${cfg.package}/bin/peon"
    '';
  };
}
