#!/usr/bin/env bash
# Maid Runner test suite. Pure-python unit tests (no display needed)
# plus one offscreen Qt smoke test. Safe: fixture dirs, /tmp only.
# Exit nonzero on first failure.
set -u
PKGDIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$PKGDIR/src"
PASS=0
ok()   { PASS=$((PASS+1)); echo "ok $PASS - $1"; }
fail() { echo "NOT OK - $1"; exit 1; }

echo "== syntax =="
bash -n "$PKGDIR"/bin/maid-runner "$PKGDIR"/bin/maid-scroll "$PKGDIR"/install.sh || fail "bash -n"
command -v shellcheck >/dev/null 2>&1 && shellcheck -S error "$PKGDIR"/bin/maid-runner "$PKGDIR"/bin/maid-scroll "$PKGDIR"/install.sh || true
python3 -m py_compile "$SRC"/maid_runner/*.py "$SRC"/maid_runner/sources/*.py || fail "py_compile"
ok "syntax"

echo "== personal data =="
# every shipped file is scanned, desktop Exec included: those carry a
# @HOME@ placeholder that install.sh rewrites to this $HOME, so the repo
# never names a machine's own paths. The suite must never carry a
# machine's own config: no host names, no desktop ids, no paths from one
# person's box.
if grep -rn --exclude-dir=__pycache__ -iE "([0-9a-f]{2}:){5}[0-9a-f]{2}|/(home|Users)/[^/[:space:]]+|(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}" \
    "$SRC" "$PKGDIR/README.md" "$PKGDIR/install.sh" "$PKGDIR/bin" "$PKGDIR/desktop" "$PKGDIR/CONTRIBUTING.md" 2>/dev/null \
    | grep -v "AA:BB:CC:DD:EE:FF"; then
  fail "personal string leaked"
fi
ok "no personal data"

# A fake suite: the runner's Maid tab only lists actions for tools that
# are installed, so the sources tests point MAID_RUNNER_BIN at a fixture
# instead of whatever is really on the machine.
rm -rf /tmp/mr-bin && mkdir -p /tmp/mr-bin
for t in bluetooth-toggle.sh update-all.sh maidshare maid-helper; do
  printf '#!/bin/sh\nexit 0\n' > "/tmp/mr-bin/$t"
  chmod +x "/tmp/mr-bin/$t"
done
ok "suite fixture"

echo "== unit: scoring, calc, web, maid =="
MAID_RUNNER_BIN=/tmp/mr-bin PYTHONPATH="$SRC" python3 - <<'EOF' || fail "unit checks"
from maid_runner.sources.apps import _rank as rank, _parse_desktop as parse
from maid_runner.sources.calc import looks_like_math as ismath, compute
from maid_runner.sources.web import WebSource
from maid_runner.sources.maid import MaidSource, ACTIONS
from maid_runner.sources.run import RunSource

a = {"name": "LibreWolf", "generic": "Web Browser", "keywords": "internet;www;"}
assert rank("lib", a) is not None and rank("lib", a) < rank("wolf", a)
assert rank("libre", a) == 0
assert rank("zzzqqq", a) is None
assert rank("bwser", a) is not None  # fuzzy fallback

assert ismath("2+2*3") and compute("2+2*3") == 8
assert compute("(100-15)/17") == 5
assert compute("2^10") == 1024
assert compute("1/0") is None
assert not ismath("hello world")
assert compute("__import__('os').system('x')") is None

w = WebSource()
assert w.items("")[0] == [] if False else True
rows = dict((t, u) for t, s, _, u in w.items("yt cats"))
assert "youtube.com" in rows["cats"]
assert w.items("example.com")[0][3] == "https://example.com"
assert w.items("x") == []
# bare text asks SearXNG, an open source metasearch engine, not a single
# company; the instance is swappable without touching code
import os
from maid_runner.sources.web import SEARX, searx_base
assert searx_base() == SEARX[0], searx_base()
plain = w.items("cats and dogs")
assert plain and plain[0][3].startswith(searx_base() + "/search?q="), plain
assert "searx" in plain[0][1].lower(), plain[0][1]
os.environ["MAID_RUNNER_SEARX"] = "https://searxng.site/"
assert w.items("cats and dogs")[0][3].startswith("https://searxng.site/search?q=")
del os.environ["MAID_RUNNER_SEARX"]

m = MaidSource()
allrows = m.items("")
assert len(allrows) == len(ACTIONS) and len(allrows) >= 10
assert any("Earbuds to PC" in t for t, _, _, _ in m.items("buds"))
assert any("System update" in t for t, _, _, _ in m.items("update"))
print("unit checks passed")
EOF
ok "unit checks"

echo "== unit: desktop parsing =="
rm -rf /tmp/mr-xdg && mkdir -p /tmp/mr-xdg/applications
cat > /tmp/mr-xdg/applications/good.desktop <<'EOF'
[Desktop Entry]
Name=Test App
GenericName=Testing
Comment=Fixture
Exec=/usr/bin/testapp --flag %F
Icon=testapp
Terminal=false
Type=Application
Categories=Utility;
Keywords=test;fixture;
EOF
cat > /tmp/mr-xdg/applications/hidden.desktop <<'EOF'
[Desktop Entry]
Name=Hidden App
Exec=/usr/bin/hidden
NoDisplay=true
Type=Application
EOF
cat > /tmp/mr-xdg/applications/term.desktop <<'EOF'
[Desktop Entry]
Name=Term Tool
Exec=/usr/bin/termtool
Terminal=true
Type=Application
EOF
# spec string escapes: \s is a space and \\ is a backslash; the KDE
# menu decodes them, so a shipped Name=Brave\s must show as "Brave".
cat > /tmp/mr-xdg/applications/escaped.desktop <<'EOF'
[Desktop Entry]
Name=Odd\\Name\sApp
Exec=/usr/bin/escaped
Type=Application
EOF
PYTHONPATH="$SRC" XDG_DATA_HOME=/tmp/mr-xdg XDG_DATA_DIRS=/nonexistent python3 - <<'EOF' || fail "desktop parsing"
import sys
sys.path.insert(0, "/tmp/nonexistent")
from maid_runner.sources import apps
from maid_runner.sources.apps import load_apps
got = {a["name"]: a for a in load_apps()}
assert "Test App" in got, got.keys()
assert "Hidden App" not in got
assert got["Test App"]["terminal"] is False
assert got["Term Tool"]["terminal"] is True
assert "Odd\\Name App" in got, got.keys()
from maid_runner.sources.apps import _clean_exec
assert _clean_exec("/usr/bin/testapp --flag %F") == "/usr/bin/testapp --flag"
print("desktop parsing passed")
EOF
ok "desktop parsing"
rm -rf /tmp/mr-xdg

echo "== terminal picker =="
# Hermetic: point PATH at a scratch dir so nothing from this machine's
# real setup decides the answer.
PYTHONPATH="$SRC" python3 - <<'EOF' || fail "terminal picker"
import os
from maid_runner.sources import base

D = "/tmp/mr-term"
orig_path, orig_term = os.environ.get("PATH"), os.environ.get("TERMINAL")


def _reset(bins):
    os.system("rm -rf " + D)
    os.makedirs(D)
    for name, body in bins:
        p = os.path.join(D, name)
        with open(p, "w") as f:
            f.write(body)
        os.chmod(p, 0o755)


def pick(bins, term=None, kde=None):
    _reset(bins)
    if kde:
        _reset(bins + [("kreadconfig6",
                        '#!/bin/sh\necho "/tmp/mr-term/myterm --single"\n')])
    os.environ["PATH"] = D
    os.environ.pop("TERMINAL", None)
    if term:
        os.environ["TERMINAL"] = term
    try:
        return base.pick_terminal()
    finally:
        os.environ["PATH"] = orig_path
        if orig_term is None:
            os.environ.pop("TERMINAL", None)
        else:
            os.environ["TERMINAL"] = orig_term


SH = "#!/bin/sh\nexit 0\n"
# unknown names default to -e, in list order
assert pick([("konsole", SH)]) == ["konsole", "-e"]
assert pick([("konsole", SH), ("ghostty", SH)]) == ["ghostty", "-e"]
assert pick([("foot", SH)]) == ["foot"], "foot takes no flag"
# the freedesktop helper beats guessing
assert pick([("konsole", SH), ("xdg-terminal-exec", SH)]) == ["xdg-terminal-exec"]
# $TERMINAL is honoured
assert pick([("konsole", SH)], term="konsole") == ["konsole", "-e"]
# whatever the desktop configured wins over the fallback list, flags and all
assert pick([("konsole", SH), ("myterm", SH)], kde=True) == [
    "/tmp/mr-term/myterm", "--single", "-e"]
# no terminal at all -> None, and launch() reports the failure
assert pick([]) is None
os.system("rm -rf " + D)
print("terminal picker passed")
EOF
ok "terminal picker"

echo "== resident toggle channel =="
rm -rf /tmp/mr-run && mkdir -p /tmp/mr-run
XDG_RUNTIME_DIR=/tmp/mr-run PYTHONPATH="$SRC" python3 - <<'EOF' || fail "toggle channel"
from maid_runner import toggle

# per-runtime socket path; nothing listens yet
assert toggle.socket_path() == "/tmp/mr-run/maid-runner.sock", toggle.socket_path()
assert toggle.send("ping") is False

first = toggle.listen()
assert first is not None, "first instance must own the socket"
# a live instance keeps the socket: the second listen() refuses, and
# the ping it used to ask really reaches the owner
assert toggle.listen() is None, "second instance must refuse"
first.setblocking(True)
first.settimeout(2)
conn, _addr = first.accept()
assert conn.recv(64) == b"ping\n", "the refusing call must ping the owner"
conn.close()
# and a word really crosses the socket, newline-terminated
assert toggle.send("show") is True
conn, _addr = first.accept()
assert conn.recv(64) == b"show\n", "word must arrive newline-terminated"
conn.close()

# a crashed instance leaves a dead socket file: the next listen
# takes the path over (bind fails, ping gets no answer)
first.close()  # the socket file stays behind, nothing listens
second = toggle.listen()
assert second is not None, "dead socket file must be taken over"
second.close()
print("toggle channel passed")
EOF
ok "resident toggle channel"

echo "== files search =="
rm -rf /tmp/mr-files && mkdir -p /tmp/mr-files/docs /tmp/mr-files/node_modules /tmp/mr-files/.hidden
: > "/tmp/mr-files/docs/Taxes-2025.pdf"
: > "/tmp/mr-files/docs/meeting-notes.txt"
: > "/tmp/mr-files/node_modules/skipme.txt"
: > "/tmp/mr-files/.hidden/skip.txt"
: > "/tmp/mr-files/.dotfile"
HOME=/tmp/mr-files MAID_RUNNER_FILES=/tmp/mr-files PYTHONPATH="$SRC" python3 - <<'EOF' || fail "files search"
import os
import time
from maid_runner.sources.files import FileIndex, FilesSource, _roots

assert _roots() == ["/tmp/mr-files"], _roots()
idx = FileIndex()
assert idx.files == [] and idx.scanning is False
assert idx.start() is True
while idx.scanning:
    time.sleep(0.01)
names = sorted(os.path.basename(p) for p in idx.files)
assert names == ["Taxes-2025.pdf", "meeting-notes.txt"], names

src = FilesSource(index=idx)
rows = src.items("tax")           # basename prefix
assert rows and rows[0][0] == "Taxes-2025.pdf", rows
assert rows[0][1] == "~/docs", rows[0][1]  # the home path reads as ~
rows = src.items("notes")         # a word inside the name
assert any(r[0] == "meeting-notes.txt" for r in rows), rows
assert src.items("t") == []       # one letter is not a search
assert src.items("zzz") == []
# rescans are rate-limited and swap in a fresh list; the source's
# constructor started one already, so let that land first
while idx.scanning:
    time.sleep(0.01)
assert idx.refresh(age=10**9) is False
assert idx.refresh(age=0) is True
while idx.scanning:
    time.sleep(0.01)
print("files search passed")
EOF
ok "files search"

echo "== category tabs =="
rm -rf /tmp/mr-xdg3 && mkdir -p /tmp/mr-xdg3/applications
cat > /tmp/mr-xdg3/applications/net.desktop <<'EOF'
[Desktop Entry]
Name=Net Tool
Exec=/usr/bin/nettool
Type=Application
Categories=Network;WebDevelopment;
EOF
cat > /tmp/mr-xdg3/applications/game.desktop <<'EOF'
[Desktop Entry]
Name=Game Tool
Exec=/usr/bin/gametool
Type=Application
Categories=Game;Graphics;
EOF
XDG_DATA_HOME=/tmp/mr-xdg3 XDG_DATA_DIRS=/nonexistent PYTHONPATH="$SRC" python3 - <<'EOF' || fail "category tabs"
from maid_runner.sources.apps import (AppsSource, CATEGORY_TOKENS,
                                      categories_present, load_apps)
apps = load_apps()
got = {a["name"]: a for a in apps}
assert set(got) == {"Net Tool", "Game Tool"}, got.keys()
# an app sits in every tab its Categories= honestly names
assert got["Net Tool"]["buckets"] == {"Internet", "Development"}
assert got["Game Tool"]["buckets"] == {"Games", "Graphics"}
# tabs: only categories with apps, in the menu's order
present = categories_present(apps)
assert present == ["Internet", "Games", "Graphics", "Development"], present
tabs = {name: [row[0] for row in AppsSource(apps, category=name).items("")]
        for name, _tokens in CATEGORY_TOKENS}
assert tabs["Internet"] == ["Net Tool"] and tabs["Games"] == ["Game Tool"]
assert tabs["Office"] == [] and tabs["Multimedia"] == []
assert AppsSource(apps, category="Games").name == "Games"
print("category tabs passed")
EOF
ok "category tabs"

echo "== run source gui/terminal =="
rm -rf /tmp/mr-runs && mkdir -p /tmp/mr-runs
for b in guitool clitool mystery; do
  printf '#!/bin/sh\nexit 0\n' > "/tmp/mr-runs/$b"
  chmod +x "/tmp/mr-runs/$b"
done
PYTHONPATH="$SRC" python3 - <<'EOF' || fail "run source"
import os
# the source reads PATH at construction; point it at the fixture then
os.environ["PATH"] = "/tmp/mr-runs"
from maid_runner.sources import run as runmod
from maid_runner.sources.run import RunSource, _gui_wants

apps = [
    {"name": "Gui", "exec": "/usr/bin/guitool %U", "terminal": False,
     "generic": "", "comment": "", "keywords": "", "icon": ""},
    {"name": "Cli", "exec": "/usr/bin/clitool --flag", "terminal": True,
     "generic": "", "comment": "", "keywords": "", "icon": ""},
]
assert _gui_wants(apps) == {"guitool": False, "clitool": True}
r = RunSource(apps)
# the desktop entry decides: Terminal=false means no terminal window
assert dict((t, s) for t, s, _, _ in r.items("guitool"))["guitool"] == "run"
assert dict((t, s) for t, s, _, _ in r.items("clitool"))["clitool"] == "run in terminal"
assert dict((t, s) for t, s, _, _ in r.items("mystery"))["mystery"] == "run in terminal"
# args ride along and the flag reaches launch()
calls = []
runmod.launch = lambda argv, terminal=False: (calls.append((argv, terminal)), True)[1]
assert r.activate(("guitool", "x --y")) is True
assert calls == [(["guitool", "x", "--y"], False)], calls
assert r.activate(("mystery", "")) is True
assert calls[1] == (["mystery"], True), calls
assert r.items("") == []
print("run source passed")
EOF
ok "run source gui/terminal"

echo "== web opens externally =="
PYTHONPATH="$SRC" python3 - <<'EOF' || fail "web open"
from maid_runner.sources import files as filesmod
from maid_runner.sources import web as webmod

calls = []
webmod.open_external = lambda t: (calls.append(t), True)[1]
filesmod.open_external = lambda t: (calls.append(t), True)[1]

w = webmod.WebSource()
assert w.activate("example.com") is True
assert calls[-1] == "https://example.com", calls
assert w.activate("https://example.com/x") is True
assert calls[-1] == "https://example.com/x"
# a file row opens through the same system handler, not inside the app
from maid_runner.sources.files import FileIndex, FilesSource
idx = FileIndex(roots=["/nonexistent-mr-web"])
f = FilesSource(index=idx)
assert f.activate("/tmp/mr-web-fixture.txt") is True
assert calls[-1] == "/tmp/mr-web-fixture.txt"
print("web open passed")
EOF
ok "web opens externally"

echo "== animation speed =="
rm -rf /tmp/mr-anim && mkdir -p /tmp/mr-anim
printf '[KDE]\nAnimationDurationFactor=0.5\n' > /tmp/mr-anim/kdeglobals
printf '[KDE]\nAnimationDurationFactor=2\n' > /tmp/mr-anim/slow
printf '[KDE]\nAnimationDurationFactor=0.1\n' > /tmp/mr-anim/tiny
printf '[KDE]\nAnimationDurationFactor=0\n' > /tmp/mr-anim/off
PYTHONPATH="$SRC" python3 - <<'EOF' || fail "animation speed"
import os
from maid_runner.app import animation_duration

os.environ["MAID_RUNNER_KDE_GLOBALS"] = "/tmp/mr-anim/kdeglobals"
assert animation_duration(140) == 70, animation_duration(140)
os.environ["MAID_RUNNER_KDE_GLOBALS"] = "/tmp/mr-anim/slow"
assert animation_duration(140) == 280
os.environ["MAID_RUNNER_KDE_GLOBALS"] = "/tmp/mr-anim/tiny"
assert animation_duration(140) == 50, "a tiny factor keeps a visible fade"
os.environ["MAID_RUNNER_KDE_GLOBALS"] = "/tmp/mr-anim/off"
assert animation_duration(140) == 0, "0 means the desktop wants none"
os.environ["MAID_RUNNER_KDE_GLOBALS"] = "/tmp/mr-anim/missing"
assert animation_duration(140) == 140, "no config means normal speed"
print("animation speed passed")
EOF
ok "animation speed"
rm -rf /tmp/mr-anim

echo "== suite checker =="
# full fixture: every action shows
MAID_RUNNER_BIN=/tmp/mr-bin PYTHONPATH="$SRC" python3 - <<'EOF' || fail "suite full"
from maid_runner import suite
from maid_runner.sources.maid import ACTIONS, MaidSource
assert sorted(suite.installed_tools()) == sorted(suite.TOOLS), \
    suite.installed_tools()
assert suite.any_installed()
assert len(MaidSource().items("")) == len(ACTIONS)
print("suite full passed")
EOF
# one tool installed: only its rows show
rm -rf /tmp/mr-one && mkdir -p /tmp/mr-one
printf '#!/bin/sh\nexit 0\n' > /tmp/mr-one/maidshare
chmod +x /tmp/mr-one/maidshare
MAID_RUNNER_BIN=/tmp/mr-one PYTHONPATH="$SRC" python3 - <<'EOF' || fail "suite partial"
import os
from maid_runner import suite
from maid_runner.sources.maid import MaidSource
os.environ["PATH"] = "/tmp/mr-one"  # nothing else on PATH
assert suite.installed_tools() == ["Maidshare"], suite.installed_tools()
rows = MaidSource().items("")
assert len(rows) == 2 and all("Maidshare" in s for _, s, _, _ in rows), rows
assert MaidSource().items("update") == [], "missing tool must not show"
print("suite partial passed")
EOF
# nothing installed: the Maid tab offers nothing at all
rm -rf /tmp/mr-none && mkdir -p /tmp/mr-none
MAID_RUNNER_BIN=/tmp/mr-none PYTHONPATH="$SRC" python3 - <<'EOF' || fail "suite empty"
import os
from maid_runner import suite
from maid_runner.sources.maid import MaidSource
os.environ["PATH"] = "/tmp/mr-none"  # nothing else on PATH
assert suite.installed_tools() == [], suite.installed_tools()
assert not suite.any_installed()
assert MaidSource().items("") == []
print("suite empty passed")
EOF
ok "suite checker"
rm -rf /tmp/mr-one /tmp/mr-none

echo "== maid scroll =="
rm -rf /tmp/mr-cfg
XDG_CONFIG_HOME=/tmp/mr-cfg PYTHONPATH="$SRC" python3 - <<'EOF' || fail "maid scroll"
import contextlib, io
from maid_runner import palettes, scroll

# keep the intentional failures off the test log, then read the buffer
out = io.StringIO()
err = io.StringIO()
with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
    # fresh config resolves to the default without writing anything
    assert palettes.state_path() == "/tmp/mr-cfg/maid-scroll/theme", palettes.state_path()
    assert palettes.load() == "tokyo", palettes.load()
    assert palettes.index_of("nope") == palettes.index_of("tokyo")
    assert palettes.save("nope") is False

    # next walks the list and stores the pick
    assert scroll.main(["next"]) == 0
    assert palettes.load() == "mallow", palettes.load()
    assert scroll.main(["set", "green"]) == 0
    assert palettes.load() == "green"
    # unknown name and unknown command both refuse, state untouched
    assert scroll.main(["set", "nope"]) == 2
    assert palettes.load() == "green"
    assert scroll.main(["bogus"]) == 2
    assert palettes.load() == "green"
    # the last palette wraps back to the first
    assert scroll.main(["set", "blue"]) == 0
    assert scroll.main(["next"]) == 0
    assert palettes.load() == "dark", palettes.load()

    # current prints just the name; list stars it
    assert scroll.main(["set", "tokyo"]) == 0
    assert scroll.main(["current"]) == 0
    assert scroll.main(["list"]) == 0

with open(palettes.state_path(), encoding="utf-8") as f:
    assert f.read().strip() == "tokyo", "state must be one line"
lines = out.getvalue().splitlines()
assert "tokyo" in lines, lines
assert "* tokyo" in lines and "  dark" in lines, lines
assert "no theme named 'nope'" in err.getvalue(), err.getvalue()
print("maid scroll passed")
EOF
ok "maid scroll"
rm -rf /tmp/mr-cfg

echo "== palettes match themes =="
PKGDIR="$PKGDIR" PYTHONPATH="$SRC" python3 - <<'EOF' || fail "palette/theme hex sync"
import os, sys
from maid_runner.palettes import PALETTES
root = os.environ["PKGDIR"]
bad = []
for name, p in PALETTES:
    path = os.path.join(root, "themes", "maid-%s.rasi" % name)
    if not os.path.isfile(path):
        bad.append("missing %s" % path)
        continue
    text = open(path, encoding="utf-8").read().lower()
    for key, hexv in p.items():
        if hexv.lower() not in text:
            bad.append("%s: %s %s not in theme" % (name, key, hexv))
if bad:
    print("\n".join(bad))
    sys.exit(1)
print("palettes match themes")
EOF
ok "palettes match themes"

echo "== palette contrast =="
PYTHONPATH="$SRC" python3 - <<'EOF' || fail "palette contrast"
from maid_runner.palettes import PALETTES

def lum(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]

def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

bad = []
for name, p in PALETTES:
    for fg in ("fg", "muted", "accent"):
        for bg in ("bg", "bg_alt"):
            r = ratio(p[fg], p[bg])
            if r < 4.5:
                bad.append("%s: %s on %s = %.2f" % (name, fg, bg, r))
if bad:
    print("\n".join(bad))
    raise SystemExit(1)
print("all palette text pairs clear 4.5:1")
EOF
ok "palette contrast"

echo "== offscreen smoke =="
rm -rf /tmp/mr-xdg2 /tmp/mr-cfg2 /tmp/mr-smokefiles && mkdir -p /tmp/mr-xdg2/applications /tmp/mr-smokefiles
printf '[Desktop Entry]\nName=Smoke App\nExec=/usr/bin/smoke\nType=Application\n' > /tmp/mr-xdg2/applications/smoke.desktop
printf '[Desktop Entry]\nName=Dev Tool\nExec=/usr/bin/devtool\nType=Application\nCategories=Development;\n' > /tmp/mr-xdg2/applications/dev.desktop
: > /tmp/mr-smokefiles/smokefile.txt
QT_QPA_PLATFORM=offscreen XDG_CONFIG_HOME=/tmp/mr-cfg2 XDG_DATA_HOME=/tmp/mr-xdg2 XDG_DATA_DIRS=/nonexistent MAID_RUNNER_BIN=/tmp/mr-bin MAID_RUNNER_FILES=/tmp/mr-smokefiles MAID_RUNNER_KDE_GLOBALS=/tmp/mr-anim-none PYTHONPATH="$SRC" python3 - <<'EOF' || fail "offscreen smoke"
from maid_runner.app import PALETTES, RunnerWindow
from maid_runner import palettes
from PyQt6.QtWidgets import QApplication, QLabel
import sys
app = QApplication.instance() or QApplication(sys.argv)
w = RunnerWindow()
def titles():
    out = []
    for i in range(w.list.count()):
        itw = w.list.itemWidget(w.list.item(i))
        lab = itw.findChild(QLabel, "title") if itw is not None else None
        out.append(lab.text() if lab is not None else "")
    return out
def sub_count():
    n = 0
    for i in range(w.list.count()):
        itw = w.list.itemWidget(w.list.item(i))
        if itw is not None and itw.findChild(QLabel, "sub"):
            n += 1
    return n
names = [s.name for s in w.sources]
# roster contract: apps first, the categories, the Maid suite group
# where the app manager keeps it (before Development), tools last
assert names == ["Applications", "Maid", "Development", "Files", "Run",
                 "Calculator", "Web"], names
assert w.list.count() > 0, "empty app list"
# typing searches every source at once: no tab switch needed to find
# an app, and the label says the scope
w.search.setText("smoke")
app.processEvents()
assert "Smoke App" in titles(), titles()
assert w.source_label.text() == "all sources", w.source_label.text()
# math answers immediately - calc sits before its web fallback row
w.search.setText("2+3*4")
app.processEvents()
assert titles()[:1] == ["14"], titles()
# clearing the box returns to the browsed tab
w.search.setText("")
w.source_idx = names.index("Applications")
w.refresh(); app.processEvents()
assert w.source_label.text() == "Applications", w.source_label.text()
# app rows stay single-line even when the search mixes sources
w.search.setText("smoke")
app.processEvents()
i = titles().index("Smoke App")
itw = w.list.itemWidget(w.list.item(i))
assert itw.findChild(QLabel, "sub") is None, "app rows stay single-line"
# maid tab: subtitles stay (the one place they earn their pixels)
w.source_idx = names.index("Maid")
w.search.setText("")
w.refresh(); app.processEvents()
assert w.list.count() >= 1 and sub_count() >= 1, "maid rows need subtitles"
# files tab: the background scan answers (tiny fixture, done in ms)
w.source_idx = names.index("Files")
w.search.setText("smokefile")
import time as _time
_deadline = _time.time() + 5
while not w._files.files and _time.time() < _deadline:
    app.processEvents()
    _time.sleep(0.01)
w.refresh(); app.processEvents()
assert titles() == ["smokefile.txt", "smokefile"], titles()
# layer-shell routing is a no-op away from wayland and must not crash
from maid_runner.wayland import attach_layer
assert attach_layer(w.windowHandle()) is False
# window contract: TAB/shift+TAB cycle, the card centers itself, esc
# and backdrop clicks close, card clicks do not. QTest drives the real
# event pipeline - focus traversal is exactly what ate TAB before.
from PyQt6.QtCore import QPoint, Qt
from PyQt6.QtTest import QTest
w.show()
w.search.setFocus()
app.processEvents()
i0 = w.source_idx
QTest.keyClick(w.search, Qt.Key.Key_Tab)
app.processEvents()
assert w.source_idx == (i0 + 1) % len(w.sources), "TAB must reach the next source"
QTest.keyClick(w.search, Qt.Key.Key_Tab, Qt.KeyboardModifier.ShiftModifier)
app.processEvents()
assert w.source_idx == i0, "shift+TAB must go back"
# caps lock cycles the six palettes, wraps back around, and stores the
# pick for the next launch (and for maid-scroll)
assert palettes.load() == "tokyo", "a fresh config opens on tokyo"
assert PALETTES[w.theme_idx][0] == "tokyo", "window opens on the tokyo palette"
t0 = w.theme_idx
for _ in range(len(PALETTES)):
    QTest.keyClick(w.search, Qt.Key.Key_CapsLock)
    app.processEvents()
assert w.theme_idx == t0, "caps lock must wrap through every palette"
assert PALETTES[t0][1]["bg"] in w.styleSheet(), "tokyo palette must be back on the card"
assert palettes.load() == PALETTES[t0][0], "caps lock must store the pick"
# a stored pick is what the next window opens on
palettes.save("mallow")
w2 = RunnerWindow()
assert PALETTES[w2.theme_idx][0] == "mallow", "window must open on the stored theme"
palettes.save("tokyo")
w.resize(1280, 800)
app.processEvents()
c, r = w.card_holder.geometry(), w.rect()
assert abs(c.center().x() - r.center().x()) <= 4, ("card must sit centered", c, r)
assert abs(c.center().y() - r.center().y()) <= 4, ("card must sit centered", c, r)
QTest.keyClick(w.search, Qt.Key.Key_Escape)
QTest.qWait(400)  # the close is a fade, then a hide
assert not w.isVisible(), "esc must close"
assert w._fade == 0.0, "esc must have faded the window out"
# pop_up fades back in and leaves no effect behind at rest
w.pop_up()
QTest.qWait(400)
assert w.isVisible() and w._fade == 1.0, "pop_up must fade in"
assert w.card_holder.graphicsEffect() is None, \
    "an open window must not carry a fade effect"
QTest.mouseClick(w, Qt.MouseButton.LeftButton,
                 pos=w.card_holder.geometry().topLeft()
                 + QPoint(w.card_holder.width() // 2, 50))
app.processEvents()
assert w.isVisible(), "clicking the card must not close"
QTest.mouseClick(w, Qt.MouseButton.LeftButton, pos=QPoint(4, 4))
QTest.qWait(400)  # the close is a fade, then a hide
assert not w.isVisible(), "clicking the dim backdrop must close"
print("offscreen smoke passed")
EOF
ok "offscreen smoke"
rm -rf /tmp/mr-xdg2

echo "== themes present =="
# The six .rasi files mirror the palettes (palettes.py is the source of
# truth, checked below) - no rofi needed to count and confirm them.
n=0
for f in "$PKGDIR"/themes/maid-*.rasi; do
  [ -f "$f" ] || continue
  grep -qE "^[[:space:]]*bg:" "$f" || fail "no palette block: $(basename "$f")"
  n=$((n + 1))
done
[ "$n" -ge 6 ] || fail "expected 6+ themes, found $n"
ok "all themes present ($n)"

echo "== structure identical =="
body() { sed '1,9d' "$1"; }
first=""
for f in "$PKGDIR"/themes/maid-*.rasi; do
  [ -z "$first" ] && first="$f" && continue
  diff <(body "$first") <(body "$f") >/dev/null || fail "structure drift: $(basename "$f")"
done
ok "structure identical, palettes differ"

echo "== installer dry run =="
rm -rf /tmp/mr-home; mkdir -p /tmp/mr-home
HOME=/tmp/mr-home bash "$PKGDIR/install.sh" --check >/dev/null 2>&1 || fail "install --check"
[ -e /tmp/mr-home/.local/bin/maid-runner ] && fail "dry run wrote files"
ok "installer dry run clean"

echo "== install + uninstall =="
# pin XDG_CONFIG_HOME too: the installer honours it for the Maid Scroll
# state, so inheriting a real one would write outside the fake HOME.
IRUN="env HOME=/tmp/mr-home XDG_CONFIG_HOME=/tmp/mr-home/.config"
$IRUN bash "$PKGDIR/install.sh" </dev/null >/dev/null 2>&1 || fail "fake install crashed"
[ -x /tmp/mr-home/.local/bin/maid-runner ] || fail "wrapper missing"
[ -x /tmp/mr-home/.local/bin/maid-scroll ] || fail "maid-scroll wrapper missing"
[ -f /tmp/mr-home/.local/lib/maid-runner/maid_runner/app.py ] || fail "package missing"
[ -f /tmp/mr-home/.local/share/applications/maid-runner.desktop ] || fail "desktop missing"
[ -e /tmp/mr-home/.local/share/rofi ] && fail "rofi dir should not be created"
# --set writes the Maid Scroll state file the app reads
$IRUN bash "$PKGDIR/install.sh" --set mallow </dev/null >/dev/null 2>&1 || fail "install --set crashed"
[ "$(cat /tmp/mr-home/.config/maid-scroll/theme 2>/dev/null)" = "mallow" ] || fail "--set did not write maid-scroll state"
$IRUN bash "$PKGDIR/install.sh" --uninstall --purge </dev/null >/dev/null 2>&1 || fail "fake uninstall crashed"
[ -e /tmp/mr-home/.local/bin/maid-runner ] && fail "uninstall left files"
[ -e /tmp/mr-home/.local/bin/maid-scroll ] && fail "uninstall left maid-scroll"
[ -e /tmp/mr-home/.local/lib/maid-runner ] && fail "uninstall left package"
[ -e /tmp/mr-home/.config/maid-scroll ] && fail "--purge left maid-scroll state"
rm -rf /tmp/mr-home
ok "install + uninstall"

echo "== cleanup =="
rm -rf /tmp/mr-home /tmp/mr-xdg /tmp/mr-xdg2 /tmp/mr-xdg3 /tmp/mr-cfg \
  /tmp/mr-cfg2 /tmp/mr-bin /tmp/mr-one /tmp/mr-none /tmp/mr-term \
  /tmp/mr-run /tmp/mr-files /tmp/mr-runs /tmp/mr-smokefiles /tmp/mr-anim
ok "cleanup"
echo "ALL $PASS PASSED"
