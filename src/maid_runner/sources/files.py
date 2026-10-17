"""Files source: names under the home folder, no indexer needed.

Scans once, in a background thread, then answers from memory: a
launcher must not stall on a keystroke. Hidden directories, build
trees and caches are pruned during the walk, and the index stops at a
cap, so a real home stays quick and small. MAID_RUNNER_FILES=dir1:dir2
replaces the roots (tests, odd setups); by default the home folder is
the root.

Rows open through the system handler, the same way the Web tab opens
a URL.
"""

import os
import threading
import time

from .base import open_external

# Directory names that never hold something you would look for from a
# launcher; pruned wherever they appear.
_PRUNE = frozenset((
    "node_modules", "target", "build", "dist", "venv", "__pycache__",
    "snap", "steamapps", "tmp",
))

# Nobody scrolls this far; the cap keeps a monster home from eating
# memory for rows that do not matter.
_MAX_FILES = 40000


def _roots():
    override = os.environ.get("MAID_RUNNER_FILES")
    if override:
        return [d for d in override.split(":") if d]
    return [os.path.expanduser("~")]


class FileIndex:
    """The name list, filled once by a background thread.

    ``files`` swaps atomically (a new list per scan), so readers never
    see a half-built index.
    """

    def __init__(self, roots=None):
        self._roots = list(roots) if roots else _roots()
        self._lock = threading.Lock()
        self._scanning = False
        self._last = 0.0
        self.files = []

    @property
    def scanning(self):
        return self._scanning

    def start(self):
        """Scan in the background; harmless to call again."""
        with self._lock:
            if self._scanning:
                return False
            self._scanning = True
        threading.Thread(target=self._scan, daemon=True).start()
        return True

    def refresh(self, age=300.0):
        """Rescan in the background, but not more often than ``age``.

        A resident window can live for days; a download from this
        morning must not stay invisible all evening.
        """
        if self._scanning or time.monotonic() - self._last < age:
            return False
        return self.start()

    def _scan(self):
        found = []
        stop = False
        for root in self._roots:
            for dirpath, dirnames, filenames in os.walk(
                    root, followlinks=False):
                # In place: os.walk descends into whatever stays.
                dirnames[:] = [d for d in dirnames
                               if not d.startswith(".") and d not in _PRUNE]
                for name in filenames:
                    if name.startswith("."):
                        continue
                    found.append(os.path.join(dirpath, name))
                    if len(found) >= _MAX_FILES:
                        stop = True
                        break
                if stop:
                    break
            if stop:
                break
        self.files = found
        self._last = time.monotonic()
        with self._lock:
            self._scanning = False


class FilesSource:
    name = "Files"
    show_subtitles = True

    def __init__(self, index=None):
        self._index = index if index is not None else FileIndex()
        self._index.start()

    def _rank(self, query, path):
        baseline = os.path.basename(path).lower()
        q = query.lower()
        if baseline.startswith(q):
            return 0
        # a word inside the name beats a letter run inside the path
        words = baseline.replace("-", " ").replace("_", " ").split()
        if any(w.startswith(q) for w in words):
            return 1
        if q in baseline:
            return 2
        if q in path.lower():
            return 3
        return None

    def items(self, query):
        q = (query or "").strip()
        if len(q) < 2:
            return []
        home = os.path.expanduser("~")
        scored = []
        for path in self._index.files:
            rank = self._rank(q, path)
            if rank is None:
                continue
            scored.append((rank, len(path), path))
        scored.sort()
        rows = []
        for _, _, path in scored[:40]:
            name = os.path.basename(path)
            parent = os.path.dirname(path)
            if parent.startswith(home + os.sep):
                parent = "~" + parent[len(home):]
            rows.append((name, parent, "text-x-generic", path))
        return rows

    def activate(self, path):
        return open_external(path)
