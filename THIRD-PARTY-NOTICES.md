# third-party and credits

Maid Runner is Maidware work under the **GPL-3.0-or-later** license in `LICENSE`. It does not bundle third-party libraries; it uses the runtime and desktop components below when present.

## Runtime dependencies (not bundled)
Provided by your system/distribution:
- **Python 3** (PSF License).
- **PyQt6** / **Qt 6** (Riverbank Computing / Qt Project): the GUI application, widgets, and Wayland/X11 integration. Installed separately (e.g. `python3-pyqt6` / Qt6 packages) under their respective licenses/terms.
- **A display server**: Wayland or X11 (compositor/toolkit integration; layer-shell behavior depends on the compositor and available libraries).
- **bash** and common userland tools (for the entry/wrapper scripts).

## Desktop integration (referenced, not bundled)
- **XDG Desktop Entry / icon themes** conventions (freedesktop.org specifications) — followed for launchers; no freedesktop code bundled.
- **KDE Plasma / KWin** integration is supported on KDE; Hyprland/Sway/i3 are supported on a best-effort/partial basis (keybinds configured in the compositor). No compositor code is bundled.

Everything else in this repository is original Maidware work. Corrections welcome.
