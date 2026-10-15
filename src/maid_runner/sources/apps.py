"""Applications source: the KDE menu program list, from XDG dirs.

Reads .desktop files directly (same data the menu shows): honors
NoDisplay/Hidden, OnlyShowIn/NotShowIn for KDE, TryExec, and strips
Exec field codes. TAB lands here first.
"""

import configparser
import os
import shlex

from .base import app_dirs, launch, pick_terminal


def _parse_desktop(path):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            cp.read_file(f)
    except OSError:
        return None
    if "Desktop Entry" not in cp:
        return None
    e = cp["Desktop Entry"]
    if e.get("NoDisplay", "false").lower() == "true":
        return None
    if e.get("Hidden", "false").lower() == "true":
        return None
    only = e.get("OnlyShowIn", "")
    if only and "KDE" not in [s.strip() for s in only.split(";")]:
        return None
    notshow = e.get("NotShowIn", "")
    if "KDE" in [s.strip() for s in notshow.split(";")]:
        return None
    if e.get("Type", "Application") != "Application":
        return None
    name = (e.get("Name") or "").strip()
    exec_line = (e.get("Exec") or "").strip()
    if not name or not exec_line:
        return None
    if e.get("TryExec"):
        import shutil
        if shutil.which(e["TryExec"].strip()) is None:
            return None
    return {
        "name": name,
        "generic": (e.get("GenericName") or "").strip(),
        "comment": (e.get("Comment") or "").strip(),
        "keywords": (e.get("Keywords") or "").strip(),
        "exec": exec_line,
        "terminal": e.get("Terminal", "false").lower() == "true",
    }


def _clean_exec(exec_line):
    # strip freedesktop field codes (%f %F %u %U %i %c %k %d %D %n %N %v %m)
    import re
    return re.sub(r"\s*%[fFuUickdDnNvm]", "", exec_line).strip()


def _rank(query, app):
    q = query.lower()
    blobs = [(app["name"], 0), (app["generic"], 1), (app["keywords"], 2)]
    best = None
    for text, base in blobs:
        t = text.lower()
        if not t or q not in t:
            continue
        if t.startswith(q):
            rank = base * 10 + 0
        elif any(w.startswith(q) for w in t.replace(";", " ").split()):
            rank = base * 10 + 1
        else:
            rank = base * 10 + 2
        if best is None or rank < best:
            best = rank
    if best is not None:
        return best
    # fuzzy fallback: query chars appear in order
    t = (app["name"] + " " + app["generic"] + " " + app["keywords"]).lower()
    pos = 0
    for c in q:
        pos = t.find(c, pos)
        if pos < 0:
            return None
        pos += 1
    return 40 + len(t)


def load_apps(dirs=None):
    seen, apps = set(), []
    for d in dirs if dirs is not None else app_dirs():
        try:
            names = os.listdir(d)
        except OSError:
            continue
        for n in names:
            if not n.endswith(".desktop"):
                continue
            key = n.lower()
            if key in seen:
                continue
            seen.add(key)
            app = _parse_desktop(os.path.join(d, n))
            if app:
                apps.append(app)
    return apps


class AppsSource:
    name = "Applications"
    show_subtitles = False

    def __init__(self, dirs=None):
        self._apps = load_apps(dirs)

    def items(self, query):
        q = (query or "").strip()
        if not q:
            return [(a["name"], a["generic"] or a["comment"], a)
                    for a in sorted(self._apps, key=lambda a: a["name"].lower())]
        scored = []
        for a in self._apps:
            r = _rank(q, a)
            if r is not None:
                scored.append((r, a["name"].lower(), a))
        scored.sort(key=lambda t: (t[0], t[1]))
        return [(a["name"], a["generic"] or a["comment"], a) for _, _, a in scored]

    def activate(self, app):
        argv = shlex.split(_clean_exec(app["exec"]))
        if not argv:
            return False
        if app["terminal"]:
            term = pick_terminal()
            if term is None:
                return False
            argv = term + argv
        return launch(argv)
