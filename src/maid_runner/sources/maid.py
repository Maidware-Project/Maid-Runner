"""Maid source: full use of every suite app from the runner.
Each action is (tool, title, subtitle, keywords, argv, terminal?).
Silent actions run detached; anything printing runs in a terminal.

Only actions for tools that are installed show up, so the list follows
what is actually on the machine - the suite is independent per tool,
even though this tab drives all of them."""

import os

from ..suite import installed

BIN = os.path.join(os.path.expanduser("~"), ".local/bin")


def _b(name):
    return os.path.join(BIN, name)


ACTIONS = [
    # Maid BT - earbuds switcher
    ("Maid BT", "Earbuds to PC", "Maid BT: connect + route audio",
     "bluetooth earbuds pc buds connect sound",
     ["bluetooth-toggle.sh", "on"], "bluetooth", False),
    ("Maid BT", "Earbuds to phone", "Maid BT: warm release, instant switch-back",
     "bluetooth earbuds phone release buds",
     ["bluetooth-toggle.sh", "release"], "bluetooth", False),
    ("Maid BT", "Bluetooth off", "Maid BT: disconnect, park audio, radio off",
     "bluetooth off radio buds disconnect",
     ["bluetooth-toggle.sh", "off"], "bluetooth", False),
    ("Maid BT", "Radio only", "Maid BT: radio on, buds untouched",
     "bluetooth radio controller mouse",
     ["bluetooth-toggle.sh", "radio"], "bluetooth", False),
    ("Maid BT", "Bluetooth status", "Maid BT: state, buds, sink, watcher",
     "bluetooth status state buds",
     ["bluetooth-toggle.sh", "status"], "bluetooth", True),
    # Maid AU - updater
    ("Maid AU", "System update check", "Maid AU: dry run, what would update",
     "update upgrade check system packages",
     ["update-all.sh", "--check"], "software-update-available", True),
    ("Maid AU", "System update", "Maid AU: full run (snapshots first)",
     "update upgrade system packages reboot",
     ["update-all.sh"], "software-update-available", True),
    ("Maid AU", "Last update", "Maid AU: when the last good run happened",
     "update last history log",
     ["update-all.sh", "--last"], "software-update-available", True),
    # Maidshare - phone sharing
    ("Maidshare", "Share to phone", "Maidshare: pick a file, auto backend",
     "share send phone file kdeconnect",
     ["maidshare"], "kdeconnect", False),
    ("Maidshare", "Receive from phone", "Maidshare: QR upload, browser, token URL",
     "share receive phone upload qr",
     ["maidshare", "--receive"], "kdeconnect", True),
    # Maid Helper - first aid
    ("Maid Helper", "System check", "Maid Helper: read-only health report",
     "doctor fix help check health codecs gpu printer fonts",
     ["maid-helper", "--check"], "maid-helper", True),
    ("Maid Helper", "Fix my system", "Maid Helper: apply safe fixes",
     "doctor fix help repair update",
     ["maid-helper", "--fix"], "maid-helper", True),
]


class MaidSource:
    name = "Maid"
    show_subtitles = True

    def items(self, query):
        q = (query or "").strip().lower()
        rows = []
        for tool, title, sub, keys, argv, icon, term in ACTIONS:
            if not installed(tool):
                continue
            if not q or q in title.lower() or q in sub.lower() \
                    or any(q in w for w in keys.split()):
                rows.append((title, sub, icon, (argv, term)))
        return rows

    def activate(self, payload):
        from .base import launch
        argv, term = payload
        argv = [a if "/" in a else os.path.join(BIN, a) for a in argv]
        return launch(argv, terminal=term)
