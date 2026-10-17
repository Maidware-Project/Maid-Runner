"""Maid Scroll: the suite's own theme backend.

The six palettes live here as the source of truth for the app. The
rofi themes in themes/maid-*.rasi mirror them, and tests/run.sh checks
the hex values stay identical. The chosen name is one line of state
under ~/.config/maid-scroll/, read and written by the app and by
bin/maid-scroll.
"""

import os

DEFAULT = "tokyo"

# Same names and colors as themes/maid-*.rasi.
PALETTES = [
    ("dark", {"bg": "#232629", "bg_alt": "#2a2e32", "fg": "#fcfcfc",
              "muted": "#7a7e85", "accent": "#3daee9"}),
    ("light", {"bg": "#fcfcfc", "bg_alt": "#eff0f1", "fg": "#232629",
               "muted": "#7f8c8d", "accent": "#3daee9"}),
    ("tokyo", {"bg": "#1a1b26", "bg_alt": "#24283b", "fg": "#c0caf5",
               "muted": "#565f89", "accent": "#5cb9ae"}),
    ("mallow", {"bg": "#121212", "bg_alt": "#1e1e1e", "fg": "#ececec",
                "muted": "#757575", "accent": "#efa8c4"}),
    ("green", {"bg": "#121212", "bg_alt": "#1c1c1c", "fg": "#ececec",
               "muted": "#7a7a7a", "accent": "#1db954"}),
    ("blue", {"bg": "#0f1419", "bg_alt": "#182028", "fg": "#e6edf3",
              "muted": "#6e7681", "accent": "#58a6ff"}),
]


def state_path():
    base = (os.environ.get("XDG_CONFIG_HOME")
            or os.path.join(os.path.expanduser("~"), ".config"))
    return os.path.join(base, "maid-scroll", "theme")


def index_of(name):
    for i, (n, _p) in enumerate(PALETTES):
        if n == name:
            return i
    return next(i for i, (n, _p) in enumerate(PALETTES) if n == DEFAULT)


def load():
    try:
        with open(state_path(), encoding="utf-8") as f:
            name = f.read().strip()
    except OSError:
        return DEFAULT
    return name if any(n == name for n, _p in PALETTES) else DEFAULT


def save(name):
    if not any(n == name for n, _p in PALETTES):
        return False
    path = state_path()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path + ".tmp", "w", encoding="utf-8") as f:
            f.write(name + "\n")
        os.replace(path + ".tmp", path)
    except OSError:
        return False
    return True
