# changelog

## Maid Runner v1.1.5

- **Performance:** skip file/app indexing and source initialization in `--dmenu` mode for faster, lighter startup.
- **Nix:** add `shell.nix`, `devShells`, and `formatter` outputs; update `flake.lock` and package metadata for better native Nix/NixOS development and usage.

## Maid Runner v1.1.2 (this release)

- **Run:** keep terminal-run commands open after they finish so output from quick commands (e.g. `fastfetch`) stays visible.
- **Custom commands:** load user-defined commands from `$XDG_CONFIG_HOME/maid-runner/commands.json` (or `~/.config/maid-runner/commands.json`) and show them in the new Commands source.

## Maid Runner v1.1.1

- Installers: fetch package/updates from the latest GitHub release (fallback to main if unavailable).

## Maid Runner v1.1.0

- **NixOS (flakes + home-manager), easy setup:** `flake.nix` with packages/app, `homeManagerModules.default`/`nixosModules.default`, and `programs.maid-runner.enable`. track `main` and rebuild with `--refresh` to auto-update on every rebuild/switch.
- Maid actions labeled **Maid Suite** (replaces archived AU/Helper naming), shown only for installed capabilities (independence preserved).

## Maid Runner v1.0

added:
- the launcher, stable: type once, every source answers at the same
  time - all applications, the maid suite, files, run, calculator, web.
- with the box empty, tab walks tabs that mirror the app menu (all
  applications, then the menu's groups).
- caps lock cycles the six Maid Scroll palettes; the same colors ship
  as drun themes for the fallback path.
- the terminal opens the shell the person actually uses ($SHELL, then
  the passwd entry, then bash/sh).
- plain qt app: native wayland, X11 for the fallback path; no taskbar
  icon, no accounts, no telemetry. installed files only - no systemd
  units, and it works the same on any distro.
