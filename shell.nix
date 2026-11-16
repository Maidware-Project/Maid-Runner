{ pkgs ? import <nixpkgs> { } }:

let
  py = pkgs.python3.withPackages (ps: [ ps.pyqt6 ]);
in
pkgs.mkShell {
  packages = with pkgs; [
    bash coreutils procps util-linux
    py qt6.qtbase qt6.qtwayland
    shellcheck
  ];

  shellHook = ''
    export PYTHONPATH="$PWD/src''${PYTHONPATH:+:$PYTHONPATH}"
    echo "Maid Runner dev shell (PYTHONPATH includes ./src)"
  '';
}
