"""Custom commands source: user-defined commands from a JSON file.

Commands are loaded from $XDG_CONFIG_HOME/maid-runner/commands.json
(falling back to ~/.config/maid-runner/commands.json). Each entry may
contain:
  - name/title: label shown in the runner
  - description/subtitle: optional secondary text
  - command: string or argv list to execute
  - icon: optional freedesktop icon name
  - terminal: whether to run in a terminal (default: true)
  - keywords: optional extra search terms (string or list)
"""

import json
import os
import shlex

from .base import launch


def config_path():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(
        os.path.expanduser("~"), ".config"
    )
    return os.path.join(base, "maid-runner", "commands.json")


def _as_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v) for v in value if str(v).strip()]
    if isinstance(value, str):
        return [v for v in value.split() if v]
    return [str(value)]


def load_commands(path=None):
    path = path or config_path()
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError, TypeError):
        return []

    items = data.get("commands") if isinstance(data, dict) else data
    if not isinstance(items, list):
        return []

    out = []
    for entry in items:
        if not isinstance(entry, dict):
            continue
        name = str(entry.get("name") or entry.get("title") or "").strip()
        cmd = entry.get("command")
        if not name or cmd is None:
            continue
        if isinstance(cmd, str):
            cmd_str = cmd.strip()
            if not cmd_str:
                continue
            try:
                argv = shlex.split(cmd_str)
            except ValueError:
                argv = cmd_str.split()
        elif isinstance(cmd, list):
            argv = [str(a) for a in cmd if str(a) != ""]
        else:
            continue
        if not argv:
            continue

        desc = str(entry.get("description") or entry.get("subtitle") or "").strip()
        icon = str(entry.get("icon") or "utilities-terminal").strip() or "utilities-terminal"
        terminal = bool(entry.get("terminal", True))
        keywords = _as_list(entry.get("keywords"))
        hay = " ".join([name, desc] + keywords).lower()
        out.append(
            {
                "name": name,
                "description": desc,
                "icon": icon,
                "terminal": terminal,
                "argv": argv,
                "hay": hay,
            }
        )
    return out


class CustomCommandsSource:
    name = "Commands"
    show_subtitles = True

    def __init__(self, path=None):
        self._path = path
        self.reload()

    def reload(self):
        self._commands = load_commands(self._path)

    def items(self, query):
        q = (query or "").strip().lower()
        rows = []
        for cmd in self._commands:
            if q and q not in cmd["hay"]:
                continue
            rows.append(
                (cmd["name"], cmd["description"], cmd["icon"], cmd)
            )
        return rows

    def activate(self, payload):
        argv = payload.get("argv") or []
        terminal = bool(payload.get("terminal", True))
        if not argv:
            return False
        return launch(list(argv), terminal=terminal, hold=terminal)
