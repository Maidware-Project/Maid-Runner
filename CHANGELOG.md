# changelog

## Maid Runner v1.1.1 (this release)

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
