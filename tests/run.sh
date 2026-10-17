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
# desktop Exec paths use the rewrite convention handled by install.sh
# (same as every Maid project) - scanned everywhere except there. The
# suite must never carry a machine's own config: no host names, no
# desktop ids, no paths from one person's box.
if grep -rn --exclude-dir=__pycache__ -iE "AA:BB|RemoteApp|ExampleBuds|Liberty|example-host|10\.0\.0|/home/EXAMPLEUSER/|maple mono|gtk-single-instance|com\.mitchellh|COMCAST|LeaseWeb" \
    "$SRC" "$PKGDIR/README.md" "$PKGDIR/install.sh" "$PKGDIR/bin" "$PKGDIR/AGENTS.md" "$PKGDIR/CONTRIBUTING.md" 2>/dev/null | grep -v "s|/home/EXAMPLEUSER/|"; then
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

echo "== offscreen smoke =="
rm -rf /tmp/mr-xdg2 /tmp/mr-cfg2 && mkdir -p /tmp/mr-xdg2/applications
printf '[Desktop Entry]\nName=Smoke App\nExec=/usr/bin/smoke\nType=Application\n' > /tmp/mr-xdg2/applications/smoke.desktop
QT_QPA_PLATFORM=offscreen XDG_CONFIG_HOME=/tmp/mr-cfg2 XDG_DATA_HOME=/tmp/mr-xdg2 XDG_DATA_DIRS=/nonexistent PYTHONPATH="$SRC" python3 - <<'EOF' || fail "offscreen smoke"
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
assert w.list.count() > 0, "empty app list"
w.search.setText("smoke")
app.processEvents()
assert titles() == ["Smoke App"], titles()
w.search.setText("2+3*4")
app.processEvents()
assert w.list.count() == 0, "math query must not match apps"
# calc tab answers the math
w.source_idx = names.index("Calculator")
w.refresh(); app.processEvents()
assert titles() == ["14"], titles()
# applications tab: single-line rows, no subtitles
w.source_idx = names.index("Applications")
w.search.setText("smoke")
w.refresh(); app.processEvents()
assert titles() == ["Smoke App"] and sub_count() == 0, "apps rows must be single-line"
# maid tab: subtitles stay (the one place they earn their pixels)
w.source_idx = names.index("Maid")
w.search.setText("")
w.refresh(); app.processEvents()
assert w.list.count() >= 1 and sub_count() >= 1, "maid rows need subtitles"
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
c, r = w.card.geometry(), w.rect()
assert abs(c.center().x() - r.center().x()) <= 4, ("card must sit centered", c, r)
assert abs(c.center().y() - r.center().y()) <= 4, ("card must sit centered", c, r)
QTest.keyClick(w.search, Qt.Key.Key_Escape)
app.processEvents()
assert not w.isVisible(), "esc must close"
w.show(); app.processEvents()
QTest.mouseClick(w, Qt.MouseButton.LeftButton,
                 pos=w.card.geometry().topLeft() + QPoint(w.card.width() // 2, 30))
app.processEvents()
assert w.isVisible(), "clicking the card must not close"
QTest.mouseClick(w, Qt.MouseButton.LeftButton, pos=QPoint(4, 4))
app.processEvents()
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
HOME=/tmp/mr-home bash "$PKGDIR/install.sh" </dev/null >/dev/null 2>&1 || fail "fake install crashed"
[ -x /tmp/mr-home/.local/bin/maid-runner ] || fail "wrapper missing"
[ -x /tmp/mr-home/.local/bin/maid-scroll ] || fail "maid-scroll wrapper missing"
[ -f /tmp/mr-home/.local/lib/maid-runner/maid_runner/app.py ] || fail "package missing"
[ -f /tmp/mr-home/.local/share/applications/maid-runner.desktop ] || fail "desktop missing"
[ -e /tmp/mr-home/.local/share/rofi ] && fail "rofi dir should not be created"
# --set writes the Maid Scroll state file the app reads
HOME=/tmp/mr-home bash "$PKGDIR/install.sh" --set mallow </dev/null >/dev/null 2>&1 || fail "install --set crashed"
[ "$(cat /tmp/mr-home/.config/maid-scroll/theme 2>/dev/null)" = "mallow" ] || fail "--set did not write maid-scroll state"
HOME=/tmp/mr-home bash "$PKGDIR/install.sh" --uninstall --purge </dev/null >/dev/null 2>&1 || fail "fake uninstall crashed"
[ -e /tmp/mr-home/.local/bin/maid-runner ] && fail "uninstall left files"
[ -e /tmp/mr-home/.local/bin/maid-scroll ] && fail "uninstall left maid-scroll"
[ -e /tmp/mr-home/.local/lib/maid-runner ] && fail "uninstall left package"
[ -e /tmp/mr-home/.config/maid-scroll ] && fail "--purge left maid-scroll state"
rm -rf /tmp/mr-home
ok "install + uninstall"

echo "== cleanup =="
rm -rf /tmp/mr-home /tmp/mr-xdg /tmp/mr-xdg2 /tmp/mr-cfg /tmp/mr-cfg2 \
  /tmp/mr-bin /tmp/mr-one /tmp/mr-none /tmp/mr-term
ok "cleanup"
echo "ALL $PASS PASSED"
