"""Which Maid tools are actually on this machine.

The suite is independent: every tool installs and uninstalls on its own,
and you may only have some of them. It is also interconnected: the
runner's Maid tab can drive the others, so it must not offer an action
whose tool is missing - an "Earbuds to PC" row on a machine with no Maid
BT just fails when pressed.

Point MAID_RUNNER_BIN at another bin dir to test without touching a
real home.
"""

import os
import shutil

BIN = (os.environ.get("MAID_RUNNER_BIN")
       or os.path.join(os.path.expanduser("~"), ".local", "bin"))

# tool name -> command(s) that prove it is installed (any match)
TOOLS = {
    "Maid BT": ("bluetooth-toggle.sh",),
    "Maidshare": ("maidshare",),
    "Maid Suite": ("maid-suite", "update-all.sh", "maid-helper"),
}


def resolve(command):
    """Full path to a suite command, or None when it is not installed.

    The bin dir first (where our installers put things), then PATH, so a
    system-wide install counts too - and activate() runs exactly what
    this found.
    """
    path = os.path.join(BIN, command)
    if os.path.exists(path):
        return path
    return shutil.which(command)


def installed(tool):
    """True when any of the tool's commands is in our bin dir or on PATH."""
    cmds = TOOLS[tool]
    if isinstance(cmds, str):
        cmds = (cmds,)
    return any(resolve(c) is not None for c in cmds)


def installed_tools():
    return [t for t in TOOLS if installed(t)]


def any_installed():
    return bool(installed_tools())
