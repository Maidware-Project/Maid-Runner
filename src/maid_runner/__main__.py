"""Entry point: python3 -m maid_runner."""

import os
import sys


def _early_cli():
    """Handle commands that don't need Qt/the full app."""
    args = sys.argv[1:]

    if "--version" in args or "-v" in args:
        try:
            # Try to get version from package metadata or __init__
            try:
                from importlib.metadata import version
                print(f"maid-runner {version('maid-runner')}")
            except Exception:
                from . import __version__
                print(f"maid-runner {__version__}")
        except Exception:
            print("maid-runner")
        return 0

    if "--help" in args or "-h" in args or "help" in args:
        print("usage: maid-runner [--toggle|--service|--quit|--info|--version|--dmenu|--help]")
        print("  --toggle   show/hide the runner window (for keybinds)")
        print("  --service  start resident instance hidden (for autostart)")
        print("  --quit     stop the resident instance")
        print("  --info     print session/environment diagnostics")
        print("  --version  print version")
        print("  --dmenu    read items from stdin, print selection to stdout (scripting)")
        print("  --help     show this help")
        return 0

    if "--info" in args or "--doctor" in args:
        from . import toggle
        import platform
        print("Maid Runner — session/environment info")
        print(f"  platform: {platform.system()} {platform.release()}")
        print(f"  XDG_CURRENT_DESKTOP={os.environ.get('XDG_CURRENT_DESKTOP', '')}")
        print(f"  XDG_SESSION_DESKTOP={os.environ.get('XDG_SESSION_DESKTOP', '')}")
        print(f"  XDG_SESSION_TYPE={os.environ.get('XDG_SESSION_TYPE', '')}")
        print(f"  WAYLAND_DISPLAY={os.environ.get('WAYLAND_DISPLAY', '')}")
        print(f"  DISPLAY={os.environ.get('DISPLAY', '')}")
        print(f"  XDG_RUNTIME_DIR={os.environ.get('XDG_RUNTIME_DIR', '')}")
        print(f"  QT_QPA_PLATFORM={os.environ.get('QT_QPA_PLATFORM', '(auto)')}")
        print(f"  socket: {toggle.socket_path()}")
        running = toggle.send("ping")
        print(f"  resident instance: {'yes' if running else 'no'}")
        de = " ".join([
            os.environ.get("XDG_CURRENT_DESKTOP", ""),
            os.environ.get("XDG_SESSION_DESKTOP", ""),
            os.environ.get("DESKTOP_SESSION", ""),
        ]).lower()
        hints = []
        for key, label in [("sonicde", "SonicDE"), ("plasma", "KDE Plasma"), ("kde", "KDE"), ("gnome", "GNOME"),
                           ("hyprland", "Hyprland"), ("sway", "Sway"), ("niri", "Niri"),
                           ("instantos", "instantOS"), ("instantwm", "instantWM")]:
            if key in de and label not in hints:
                hints.append(label)
        if hints:
            print(f"  detected: {', '.join(hints)}")
        return 0

    return None


if __name__ == "__main__":
    rc = _early_cli()
    if rc is not None:
        raise SystemExit(rc)
    from .app import main
    raise SystemExit(main())
