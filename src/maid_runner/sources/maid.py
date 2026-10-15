"""Maid source: full use of every suite app from the runner.
Each action is (title, subtitle, keywords, argv, terminal?).
Silent actions run detached; anything printing runs in a terminal."""

import os

BIN = os.path.join(os.path.expanduser("~"), ".local/bin")


def _b(name):
    return os.path.join(BIN, name)


ACTIONS = [
    # Maid BT — earbuds switcher
    ("Earbuds to PC", "Maid BT: connect + route audio",
     "bluetooth earbuds pc buds connect sound",
     ["bluetooth-toggle.sh", "on"], False),
    ("Earbuds to phone", "Maid BT: warm release, instant switch-back",
     "bluetooth earbuds phone release buds",
     ["bluetooth-toggle.sh", "release"], False),
    ("Bluetooth off", "Maid BT: disconnect, park audio, radio off",
     "bluetooth off radio buds disconnect",
     ["bluetooth-toggle.sh", "off"], False),
    ("Radio only", "Maid BT: radio on, buds untouched",
     "bluetooth radio controller mouse",
     ["bluetooth-toggle.sh", "radio"], False),
    ("Bluetooth status", "Maid BT: state, buds, sink, watcher",
     "bluetooth status state buds",
     ["bluetooth-toggle.sh", "status"], True),
    # Maid AU — updater
    ("System update check", "Maid AU: dry run, what would update",
     "update upgrade check system packages",
     ["update-all.sh", "--check"], True),
    ("System update", "Maid AU: full run (snapshots first)",
     "update upgrade system packages reboot",
     ["update-all.sh"], True),
    ("Last update", "Maid AU: when the last good run happened",
     "update last history log",
     ["update-all.sh", "--last"], True),
    # Maidshare — phone sharing
    ("Share to phone", "Maidshare: pick a file, auto backend",
     "share send phone file kdeconnect",
     ["maidshare"], False),
    ("Receive from phone", "Maidshare: QR upload, browser, token URL",
     "share receive phone upload qr",
     ["maidshare", "--receive"], True),
    # Maid Helper — first aid
    ("System check", "Maid Helper: read-only health report",
     "doctor fix help check health codecs gpu printer fonts",
     ["maid-helper", "--check"], True),
    ("Fix my system", "Maid Helper: apply safe fixes",
     "doctor fix help repair update",
     ["maid-helper", "--fix"], True),
]


class MaidSource:
    name = "Maid"
    show_subtitles = True

    def items(self, query):
        q = (query or "").strip().lower()
        rows = []
        for title, sub, keys, argv, term in ACTIONS:
            if not q or q in title.lower() or q in sub.lower() \
                    or any(q in w for w in keys.split()):
                rows.append((title, sub, (argv, term)))
        return rows

    def activate(self, payload):
        from .base import launch
        argv, term = payload
        argv = [a if "/" in a else os.path.join(BIN, a) for a in argv]
        return launch(argv, terminal=term)
