{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.peon-ping-relay;
in
{
  options.services.peon-ping-relay = {
    enable = mkEnableOption "peon-ping audio relay server for SSH/devcontainer support";
    
    package = mkOption {
      type = types.package;
      default = pkgs.peon-ping or (throw "peon-ping not available. Import the flake package.");
      defaultText = literalExpression "pkgs.peon-ping";
      description = "The peon-ping package to use";
    };
    
    port = mkOption {
      type = types.port;
      default = 19998;
      description = "Port for the relay server to listen on";
    };
    
    bindAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to bind to";
    };
    
    logDir = mkOption {
      type = types.str;
      default = "/tmp/peon-ping";
      description = "Directory for relay log files. Must be writable by the service user.";
    };
  };
  
  config = mkIf cfg.enable {
    system.activationScripts.peon-ping-relay-logs.text = ''
      mkdir -p ${cfg.logDir}
    '';
    
    launchd.user.agents.peon-ping-relay = {
      serviceConfig = {
        ProgramArguments = [ 
          "${cfg.package}/bin/peon" 
          "relay" 
          "--port=${toString cfg.port}"
          "--bind=${cfg.bindAddress}"
        ];
        KeepAlive = true;
        ThrottleInterval = 30;
        RunAtLoad = true;
        StandardOutPath = "${cfg.logDir}/peon-relay.log";
        StandardErrorPath = "${cfg.logDir}/peon-relay.error.log";
      };
    };
  };
}
