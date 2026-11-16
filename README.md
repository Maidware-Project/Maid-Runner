# Maid Runner

Maid Runner is a Qt-based launcher/search interface for Linux desktops. It provides a centered search card for quickly finding and launching applications, files, commands, web searches, and Maidware actions.

- **Native Wayland/X11 app behavior** (environment-dependent integrations)
- **Resident mode** for fast reopen/toggle
- **Unified search:** typing searches across available sources without manual tab switching

## Features
- **Applications:** searches XDG desktop entries (including Flatpak exports), respects `NoDisplay`/`Hidden`/`TryExec`
- **Menu categories:** category tabs (Internet, Games, Multimedia, etc.) when available
- **Maid actions:** quick access to installed Maidware tool actions
- **Files:** filename search from home directory (in-memory scan while running)
- **Run:** PATH binaries (launched in terminal for CLI tools)
- **Calculator:** safe arithmetic evaluation (AST allowlist)
- **Web:** shortcuts/prefixes and SearXNG-powered queries; opens in default browser
- **Palettes:** six Maid Scroll palettes (`dark`, `light`, `tokyo`, `mallow`, `green`, `blue`)

## Quick start

### Install
```sh
# GitHub (primary)
bash <(curl -fsSL https://raw.githubusercontent.com/Maidware-Project/Maid-Runner/main/install.sh)

# Codeberg (fallback)
bash <(curl -fsSL https://codeberg.org/Maidware_Project/Maid-Runner/raw/branch/main/install.sh)
```

The installer deploys the app, palettes, launcher/desktop entry, and related files (no package installation by itself).

### Bind a shortcut (recommended)
Bind `maid-runner --toggle` in your desktop/compositor shortcut settings.

Example (KDE Plasma):
1. **System Settings → Keyboard → Shortcuts → Custom Shortcuts**
2. Add **Command/URL**
3. Command: `~/.local/bin/maid-runner --toggle`
4. Assign a key (e.g. `Meta+Space`)

## Usage

### Commands
```sh
maid-runner            # open (starts resident instance if needed)
maid-runner --toggle   # open if hidden, close if open
maid-runner --service  # start hidden and wait (optional autostart)
maid-runner --quit     # stop resident instance
```

### Interaction basics
- **Type** to search across sources
- **Enter** to run/open selected result
- **Esc** or click outside the card to close
- **Tab / Shift+Tab** to browse tabs when query is empty
- **Caps Lock** cycles palettes and persists selection

### Palettes (Maid Scroll)
```sh
maid-scroll list
maid-scroll next
maid-scroll set mallow
```

Set palette during install:
```sh
bash install.sh --set mallow
```

## Supported platforms (best effort)
- **Desktops:** KDE Plasma, GNOME, XFCE, MATE, Cinnamon, LXQt
- **Compositors/WMs:** Hyprland, Sway, i3 (Wayland/X11 as applicable)
- **Shells/environments:** Event Horizon and KineticWE detected/reported where applicable
- **Distributions:** broad Linux support; installer/`--doctor` detect distro/family

> Requires a graphical session (Wayland or X11). Keybinding setup is user-managed and environment-specific.

## Search behavior
- Bare text queries are sent to SearXNG (default instance: `search.jeremyh.xyz`, configurable via `MAID_RUNNER_SEARX`)
- Results/URLs open in your default browser
- Maid Runner itself does not embed browsing; network use is for search queries as configured

## NixOS (flakes & Home Manager)
```nix
inputs.maid-runner.url = "github:Maidware-Project/Maid-Runner";
imports = [ inputs.maid-runner.homeManagerModules.default ];
programs.maid-runner.enable = true;
```

Try without installing:
```sh
nix run github:Maidware-Project/Maid-Runner
```

## Uninstall
```sh
bash install.sh --uninstall
```
Maid Scroll state in `~/.config/maid-scroll/` is left in place.

## Notes
- After major system/library upgrades during a running session, logging out/in can help avoid mixed-runtime desktop issues (Qt/PipeWire/GL stack swaps).
- Documentation (in-repo): [`docs/wiki/`](docs/wiki/Home.md)

## License
GPL-3.0-or-later. See [`LICENSE`](LICENSE). Part of the [Maidware Project](https://maidware-project.github.io/).
