# Installation

## Quick install
```sh
bash <(curl -fsSL https://raw.githubusercontent.com/Maidware-Project/Maid-Runner/main/install.sh)
```

Fallback:
```sh
bash <(curl -fsSL https://codeberg.org/Maidware_Project/Maid-Runner/raw/branch/main/install.sh)
```

## After install
- Bind `maid-runner --toggle` in your desktop/compositor shortcut settings
- Optionally set palette: `bash install.sh --set <palette>` (`dark|light|tokyo|mallow|green|blue`)

## NixOS
```nix
inputs.maid-runner.url = "github:Maidware-Project/Maid-Runner";
imports = [ inputs.maid-runner.homeManagerModules.default ];
programs.maid-runner.enable = true;
```

## Uninstall
```sh
bash install.sh --uninstall
``` (keeps `~/.config/maid-scroll/` state)