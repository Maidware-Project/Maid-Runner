"""python3 -m maid_runner.scroll: the Maid Scroll cli.

    list        every palette, star on the current one
    current     the current name (the default command)
    next        advance one, store it, print it
    set NAME    store NAME, one of the six

No display and no rofi involved: this is the terminal side of the
same state the app's caps lock writes.
"""

import sys

from .palettes import PALETTES, index_of, load, save


def _usage():
    print("usage: maid-scroll [list | current | next | set NAME]",
          file=sys.stderr)
    return 2


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    cmd = args[0] if args else "current"
    if cmd == "list":
        cur = load()
        for name, _p in PALETTES:
            print(("* " if name == cur else "  ") + name)
        return 0
    if cmd == "current":
        print(load())
        return 0
    if cmd == "next":
        name = PALETTES[(index_of(load()) + 1) % len(PALETTES)][0]
        save(name)
        print(name)
        return 0
    if cmd == "set" and len(args) == 2:
        if not save(args[1]):
            print(f"maid-scroll: no theme named {args[1]!r}", file=sys.stderr)
            return 2
        print(args[1])
        return 0
    return _usage()


if __name__ == "__main__":
    raise SystemExit(main())
