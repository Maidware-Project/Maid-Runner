{
  description = "Maid Runner - search everything from one key (Maidware)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        py = pkgs.python3.withPackages (ps: [ ps.pyqt6 ]);
        runtimePath = pkgs.lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.procps pkgs.util-linux ];
        maid-runner = pkgs.stdenv.mkDerivation {
          pname = "maid-runner";
          version = "0.1.0";
          src = self;
          nativeBuildInputs = [ pkgs.makeWrapper pkgs.qt6.wrapQtAppsHook ];
          dontBuild = true;
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin $out/lib/maid-runner $out/share/maid-runner $out/share/applications
            cp -a src/maid_runner $out/lib/maid-runner/
            cp -a bin/maid-runner bin/maid-scroll $out/bin/ 2>/dev/null || true
            chmod +x $out/bin/maid-runner $out/bin/maid-scroll 2>/dev/null || true
            [ -d desktop ] && cp -a desktop/*.desktop $out/share/applications/ 2>/dev/null || true
            [ -d themes ] && cp -a themes $out/share/maid-runner/themes 2>/dev/null || true
            cp -a README.md LICENSE THIRD-PARTY-NOTICES.md $out/share/maid-runner/ 2>/dev/null || true
            # ensure wrapper uses packaged lib
            wrapProgram $out/bin/maid-runner \
              --prefix PATH : ${runtimePath}:${py}/bin \
              --set PYTHONPATH $out/lib/maid-runner
            if [ -f $out/bin/maid-scroll ]; then
              wrapProgram $out/bin/maid-scroll \
                --prefix PATH : ${runtimePath}:${py}/bin \
                --set PYTHONPATH $out/lib/maid-runner
            fi
            runHook postInstall
          '';
          postFixup = ''
            for f in $out/bin/maid-runner $out/bin/maid-scroll; do [ -f "$f" ] && wrapQtApp "$f" || true; done
          '';
          meta = with pkgs.lib; {
            description = "search everything from one key (Maidware)";
            homepage = "https://github.com/Maidware-Project/Maid-Runner";
            license = licenses.gpl3Plus;
            platforms = platforms.linux;
            mainProgram = "maid-runner";
          };
        };
      in {
        packages.default = maid-runner;
        packages.maid-runner = maid-runner;
        apps.default = { type = "app"; program = "${maid-runner}/bin/maid-runner"; };
      }
    ) // {
      homeManagerModules.default = { config, lib, pkgs, ... }: {
        options.programs.maid-runner.enable = lib.mkEnableOption "Maid Runner (Maidware)";
        config = lib.mkIf config.programs.maid-runner.enable {
          home.packages = [ self.packages.${pkgs.system}.default ];
        };
      };
    };
}
