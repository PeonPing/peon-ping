{
  description = "peon-ping — Warcraft III Peon voice lines for Claude Code hooks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Home Manager module (system-agnostic)
      homeManagerModules.default = import ./nix/hm-module.nix;
      
      # NixOS module
      nixosModules.default = import ./nix/nixos-module.nix;
      
      # nix-darwin module
      darwinModules.default = import ./nix/darwin-module.nix;
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        version = pkgs.lib.strings.trim (builtins.readFile ./VERSION);

        runtimeDeps = with pkgs; [
          bash
          python3
          curl
          coreutils   # sha256sum, nohup on Linux
          gzip
        ];

        peon-ping = pkgs.stdenv.mkDerivation {
          pname = "peon-ping";
          inherit version;
          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            share="$out/share/peon-ping"
            mkdir -p "$share/scripts"

            # Core scripts
            cp peon.sh relay.sh install.sh "$share/"
            chmod +x "$share/peon.sh" "$share/relay.sh" "$share/install.sh"

            # Bundled helper scripts (find_bundled_script looks here via BASH_SOURCE fallback)
            for f in scripts/pack-download.sh scripts/notify.sh \
                     scripts/remote-hook.sh scripts/hook-handle-use.sh \
                     scripts/mac-overlay.js; do
              [ -f "$f" ] && cp "$f" "$share/scripts/"
            done
            chmod +x "$share/scripts/"*.sh 2>/dev/null || true

            # Runtime data
            cp config.json VERSION "$share/"
            cp -r trainer "$share/trainer"
            mkdir -p "$share/docs"
            cp docs/peon-icon.png "$share/docs/"

            # MCP server
            mkdir -p "$share/mcp"
            cp mcp/peon-mcp.js mcp/package.json "$share/mcp/"

            # Skills + adapters (for reference; not executed by Nix)
            cp -r skills "$share/skills"
            cp -r adapters "$share/adapters"

            # Shell completions
            mkdir -p "$out/share/bash-completion/completions"
            mkdir -p "$out/share/fish/vendor_completions.d"
            cp completions.bash "$out/share/bash-completion/completions/peon"
            cp completions.fish "$out/share/fish/vendor_completions.d/peon.fish"

            # bin/peon wrapper
            mkdir -p "$out/bin"
            makeWrapper ${pkgs.bash}/bin/bash "$out/bin/peon" \
              --add-flags "$share/peon.sh" \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
          '';

          meta = with pkgs.lib; {
            description = "Warcraft III Peon voice lines for Claude Code hooks";
            homepage = "https://github.com/PeonPing/peon-ping";
            license = licenses.mit;
            platforms = platforms.unix;
            mainProgram = "peon";
          };
        };

      in {
        packages = {
          peon-ping = peon-ping;
          default = peon-ping;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = peon-ping;
          name = "peon";
        };

        devShells.default = pkgs.mkShell {
          name = "peon-ping-dev";

          packages = with pkgs; [
            bats
            shellcheck
            python3
            nodejs_22
            curl
            jq
            coreutils
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            ffmpeg
            pulseaudio
            mpv
            sox
            alsa-utils
          ];

          shellHook = ''
            echo "peon-ping dev shell — v${version}"
            echo "  bats tests/       run test suite"
            echo "  shellcheck *.sh   lint scripts"
          '';
        };
      }
    ) // { 
      inherit homeManagerModules nixosModules darwinModules;
    };
}
