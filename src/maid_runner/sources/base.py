"""Shared bits: XDG dirs, terminal launching."""

import os
import shlex
import shutil
import subprocess


def app_dirs():
    """XDG application dirs, user first (flatpak exports included)."""
    dirs = []
    home = os.path.expanduser("~")
    xdg_data = os.environ.get("XDG_DATA_HOME", os.path.join(home, ".local/share"))
    dirs.append(os.path.join(xdg_data, "applications"))
    dirs.append(os.path.join(xdg_data, "flatpak/exports/share/applications"))
    for base in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
        if base:
            dirs.append(os.path.join(base, "applications"))
    seen, out = set(), []
    for d in dirs:
        if d not in seen:
            seen.add(d)
            out.append(d)
    return out


def pick_terminal():
    """First available terminal's exec argv prefix, or None."""
    for term, flag in (("ghostty", "-e"), ("konsole", "-e"),
                       ("xfce4-terminal", "-x"), ("gnome-terminal", "--"),
                       ("xterm", "-e")):
        if shutil.which(term):
            return [term, flag]
    return None


def launch(argv, terminal=False):
    """Run detached. terminal=True wraps in the user's terminal."""
    if terminal:
        term = pick_terminal()
        if term is None:
            return False
        argv = term + [a for a in argv]
    else:
        if isinstance(argv, str):
            argv = shlex.split(argv)
    try:
        subprocess.Popen(argv, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except (OSError, ValueError):
        return False
