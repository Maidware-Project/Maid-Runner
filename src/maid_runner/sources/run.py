"""Run source: PATH binaries. Always wrapped in a terminal so CLI
tools (htop, ssh, python) work instead of dying silently."""

import os
import shlex

from .base import launch


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
            if n in seen or n.startswith("."):
                continue
            p = os.path.join(d, n)
            if os.path.isfile(p) and os.access(p, os.X_OK):
                seen.add(n)
                out.append(n)
    return sorted(out)


class RunSource:
    name = "Run"

    def __init__(self):
        self._bins = _binaries()

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
        return [(b, ("run: " + q) if rest else "run in terminal", (b, rest))
                for _, b in scored[:25]]

    def activate(self, payload):
        b, rest = payload
        argv = [b] + shlex.split(rest) if rest else [b]
        return launch(argv, terminal=True)
