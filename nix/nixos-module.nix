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
      description = "Address to bind to. Use 0.0.0.0 to allow remote SSH connections";
    };
    
    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the relay port in the firewall";
    };
  };
  
  config = mkIf cfg.enable {
    systemd.services.peon-ping-relay = {
      description = "peon-ping audio relay server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/peon relay --port=${toString cfg.port} --bind=${cfg.bindAddress}";
        Restart = "always";
        RestartSec = 5;
        
        # Security hardening
        DynamicUser = true;
        RuntimeDirectory = "peon-ping";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = [ "/tmp" ];
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        CapabilityBoundingSet = "";
      };
    };
    
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
  };
}
