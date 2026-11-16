"""Dmenu source: items from stdin for compositor/scripting integration.

Reads lines from stdin and presents them as selectable items. On selection,
the chosen line is printed to stdout (dmenu-compatible behavior).
"""


class DmenuSource:
    name = "Select"
    show_subtitles = False

    def __init__(self, lines):
        # Each line becomes an item: (title, subtitle, icon, payload)
        self._items = []
        for line in lines:
            line = line.rstrip("\n\r")
            if not line:
                continue
            self._items.append((line, "", "", line))

    def items(self, query):
        q = (query or "").strip().lower()
        if not q:
            return list(self._items)
        return [(t, s, i, p) for t, s, i, p in self._items if q in t.lower()]

    def activate(self, payload):
        # In dmenu mode, activation is handled specially by the window
        # (print to stdout + exit). Return True to signal "handled".
        print(payload)
        return True
