# changelog

## unreleased

- **relicensed to GPL-3.0-or-later** (forkable, open source). Rationale: keep improvements shared in the open — as WINE’s move from MIT to LGPL (2002) is often cited, “those who do not learn from history are doomed to repeat.” Third-party components retain their own licenses.

## Maid Runner v1.0 (this release)

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
