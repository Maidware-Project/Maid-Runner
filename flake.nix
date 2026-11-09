{
  description = "Maid Runner - search everything from one key (Maidware)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          py = pkgs.python3.withPackages (ps: [ ps.pyqt6 ]);
          runtimePath = pkgs.lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.procps pkgs.util-linux ];
          maid-runner = pkgs.stdenv.mkDerivation {
            pname = "maid-runner";
            version = "0.1.0";
            src = self;
            nativeBuildInputs = [ pkgs.makeWrapper pkgs.qt6.wrapQtAppsHook ];
            buildInputs = [ pkgs.qt6.qtbase ];
            dontBuild = true;
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin $out/lib/maid-runner $out/share/maid-runner $out/share/applications $out/libexec/maid-runner
              cp -a src/maid_runner $out/lib/maid-runner/
              cp -a bin/maid-runner bin/maid-scroll $out/bin/ 2>/dev/null || true
              chmod +x $out/bin/maid-runner $out/bin/maid-scroll 2>/dev/null || true
              if [ -f bin/maid-suite-update ]; then
                cp -a bin/maid-suite-update $out/libexec/maid-runner/maid-suite-update
                chmod +x $out/libexec/maid-runner/maid-suite-update
                makeWrapper $out/libexec/maid-runner/maid-suite-update $out/bin/maid-suite-update --prefix PATH : ${runtimePath}
              fi
              [ -d desktop ] && cp -a desktop/*.desktop $out/share/applications/ 2>/dev/null || true
              [ -d themes ] && cp -a themes $out/share/maid-runner/themes 2>/dev/null || true
              find $out/share/applications -name '*.desktop' -type f 2>/dev/null | while IFS= read -r f; do
                sed -i "s|@HOME@/.local/bin/||g; s|@HOME@|$HOME|g" "$f"
              done
              cp -a README.md LICENSE THIRD-PARTY-NOTICES.md $out/share/maid-runner/ 2>/dev/null || true
              wrapProgram $out/bin/maid-runner --prefix PATH : ${runtimePath}:${py}/bin --set PYTHONPATH $out/lib/maid-runner
              [ -f $out/bin/maid-scroll ] && wrapProgram $out/bin/maid-scroll --prefix PATH : ${runtimePath}:${py}/bin --set PYTHONPATH $out/lib/maid-runner || true
              runHook postInstall
            '';
            postFixup = ''
              for f in $out/bin/maid-runner $out/bin/maid-scroll; do [ -f "$f" ] && wrapQtApp "$f" || true; done
            '';
            meta = with pkgs.lib; { description = "search everything from one key (Maidware)"; homepage = "https://github.com/Maidware-Project/Maid-Runner"; license = licenses.gpl3Plus; platforms = platforms.linux; mainProgram = "maid-runner"; };
          };
        in { default = maid-runner; maid-runner = maid-runner; });

      apps = forAllSystems (system: { default = { type = "app"; program = "${self.packages.${system}.default}/bin/maid-runner"; }; });
      checks = forAllSystems (system: { package = self.packages.${system}.default; });

      # easy: imports = [ inputs.maid-runner.homeManagerModules.default ]; programs.maid-runner.enable = true;
      homeManagerModules.default = { config, lib, pkgs, ... }: {
        options.programs.maid-runner = {
          enable = lib.mkEnableOption "Maid Runner (Maidware)";
          package = lib.mkOption { type = lib.types.package; default = self.packages.${pkgs.stdenv.hostPlatform.system}.default; };
        };
        config = lib.mkIf config.programs.maid-runner.enable { home.packages = [ config.programs.maid-runner.package ]; };
      };
      homeModules = self.homeManagerModules;
      nixosModules.default = { lib, ... }: { options.programs.maid-runner.enableNote = lib.mkEnableOption "Maid Runner (use home-manager module)"; };
    };
}
