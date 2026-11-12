"""Run source: PATH binaries.

CLI tools (htop, ssh, python) need a terminal to live in, so they get
one. GUI programs do not, and a terminal flashing up behind a launching
window looks broken, so when a binary answers to an installed desktop
entry that says Terminal=false it is launched detached instead. The
desktop entry is the authority; unknown binaries keep the terminal.
"""

import os
import shlex

from .apps import _clean_exec, _launch_desktop_entry, load_apps
from .base import launch


def _is_internal_binary(name):
    # NixOS and similar setups expose internal wrapper targets (e.g.
    # .foo-wrapped, foo-wrapped); never show/run them directly.
    return name.startswith(".") or name.endswith("-wrapped") or ".-wrapped" in name


def _binaries():
    out = []
    seen = set()
    for d in os.environ.get("PATH", "").split(os.pathsep):
        if not d:
            continue
        try:
            names = os.listdir(d)
        except OSError:
            continue
        for n in names:
            if n in seen or _is_internal_binary(n):
                continue
            p = os.path.join(d, n)
            if os.path.isfile(p) and os.access(p, os.X_OK):
                seen.add(n)
                out.append(n)
    return sorted(out)


def _app_index(apps):
    """Binary name -> desktop app, and binary name -> Terminal flag.

    First entry wins, the same order the menu itself loads them in.
    """
    by_bin = {}
    terminal = {}
    for app in apps:
        argv = shlex.split(_clean_exec(app["exec"]))
        if not argv:
            continue
        name = os.path.basename(argv[0])
        if not name:
            continue
        if name not in by_bin:
            by_bin[name] = app
        if name not in terminal:
            terminal[name] = app["terminal"]
    return by_bin, terminal


class RunSource:
    name = "Run"
    show_subtitles = False

    def __init__(self, apps=None):
        self._bins = _binaries()
        self._app_by_bin, self._terminal = _app_index(load_apps() if apps is None else apps)

    def items(self, query):
        q = (query or "").strip()
        if not q:
            return []
        first, _, rest = q.partition(" ")
        scored = []
        for b in self._bins:
            bl = b.lower()
            fl = first.lower()
            if bl == fl:
                scored.append((0, b))
            elif bl.startswith(fl):
                scored.append((1, b))
            elif fl in bl:
                scored.append((2, b))
        scored.sort()
        rows = []
        for _, b in scored[:25]:
            if self._terminal.get(b) is False:
                sub = ("run: " + q) if rest else "run"
            else:
                sub = ("run: " + q) if rest else "run in terminal"
            rows.append((b, sub, "system-run", (b, rest)))
        return rows

    def activate(self, payload):
        b, rest = payload
        # If a GUI desktop app owns this command, launch it like the
        # application menu (desktop entry) instead of running/wrapping the
        # raw binary directly.
        if not rest:
            app = self._app_by_bin.get(b)
            if app and not app.get("terminal"):
                return _launch_desktop_entry(app)
        try:
            argv = [b] + shlex.split(rest) if rest else [b]
        except ValueError:
            return False
        return launch(argv, terminal=self._terminal.get(b, True))
