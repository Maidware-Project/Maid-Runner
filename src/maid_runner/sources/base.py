"""Shared bits: XDG dirs, terminal launching."""

import os
import shlex
import shutil
import subprocess

# How each terminal takes a trailing command; unknown names get -e.
RUN_FLAGS = {
    "konsole": ["-e"], "alacritty": ["-e"], "kitty": ["-e"],
    "qterminal": ["-e"], "tilix": ["-e"], "xterm": ["-e"],
    "ghostty": ["-e"], "wezterm": ["start", "--"],
    "gnome-terminal": ["--"], "xfce4-terminal": ["-x"],
    "xfce-terminal": ["-x"], "foot": [], "blackbox-terminal": [],
    "console": [],
}

# Last resort, neutral order. Only reached when the desktop will not say.
FALLBACK_TERMINALS = ("alacritty", "foot", "ghostty", "kitty", "konsole",
                      "qterminal", "tilix", "wezterm", "xfce4-terminal",
                      "gnome-terminal", "xterm")


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


def _terminal_argv(cmd):
    """argv prefix: the terminal command plus how it takes a command."""
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        tokens = (cmd or "").split()
    if not tokens or not shutil.which(tokens[0]):
        return None
    return tokens + RUN_FLAGS.get(os.path.basename(tokens[0]), ["-e"])


def _kde_terminal():
    """Plasma records the default terminal in kdeglobals."""
    kr = shutil.which("kreadconfig6") or shutil.which("kreadconfig5")
    if not kr:
        return None
    try:
        out = subprocess.run(
            [kr, "--file", "kdeglobals", "--group", "General",
             "--key", "TerminalApplication"],
            capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return None
    return _terminal_argv(out.stdout.strip())


def _gnome_terminal():
    """GNOME records it in its default-applications settings."""
    gs = shutil.which("gsettings")
    if not gs:
        return None

    def get(key):
        try:
            out = subprocess.run([gs, "get",
                                  "org.gnome.desktop.default-applications.terminal",
                                  key], capture_output=True, text=True, timeout=5)
        except (OSError, subprocess.SubprocessError):
            return ""
        return out.stdout.strip().strip("'\"")

    argv = _terminal_argv(get("exec"))
    if argv is None:
        return None
    arg = get("exec-arg")
    return argv + ([arg] if arg and arg != "-e" else [])


def pick_terminal():
    """argv prefix that runs a command in this machine's default
    terminal. Nothing here assumes a setup: ask the freedesktop helper,
    then $TERMINAL, then the desktop (kdeglobals, gnome settings), and
    only then fall back to known names."""
    if shutil.which("xdg-terminal-exec"):
        return ["xdg-terminal-exec"]
    term = os.environ.get("TERMINAL", "").strip()
    if term:
        argv = _terminal_argv(term)
        if argv:
            return argv
    for probe in (_kde_terminal, _gnome_terminal):
        argv = probe()
        if argv:
            return argv
    for name in FALLBACK_TERMINALS:
        if shutil.which(name):
            return [name] + RUN_FLAGS.get(name, ["-e"])
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


def open_external(target):
    """Open a URL or a local file with the user's default handler.

    QDesktopServices routes through the desktop portal; when that is
    missing the freedesktop xdg-open still is not. Returns True when a
    handler was handed the target.
    """
    from PyQt6.QtCore import QUrl
    from PyQt6.QtGui import QDesktopServices
    is_file = os.path.exists(target)
    url = QUrl.fromLocalFile(target) if is_file else QUrl(target)
    if QDesktopServices.openUrl(url):
        return True
    return launch(["xdg-open", os.path.abspath(target) if is_file else target])
