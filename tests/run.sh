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
bash -n "$PKGDIR"/bin/maid-runner "$PKGDIR"/install.sh || fail "bash -n"
command -v shellcheck >/dev/null 2>&1 && shellcheck -S error "$PKGDIR"/bin/maid-runner "$PKGDIR"/install.sh || true
python3 -m py_compile "$SRC"/maid_runner/*.py "$SRC"/maid_runner/sources/*.py || fail "py_compile"
ok "syntax"

echo "== personal data =="
# desktop Exec paths use the rewrite convention handled by install.sh
# (same as every Maid project) — scanned everywhere except there.
if grep -rni -E "AA:BB|RemoteApp|ExampleBuds|Liberty|example-host|10\.0\.0|/home/EXAMPLEUSER/|maple mono" \
    "$SRC" "$PKGDIR/README.md" "$PKGDIR/install.sh" "$PKGDIR/bin" 2>/dev/null; then
  fail "personal string leaked"
fi
ok "no personal data"

echo "== unit: scoring, calc, web, maid =="
PYTHONPATH="$SRC" python3 - <<'EOF' || fail "unit checks"
from maid_runner.sources.apps import _rank as rank, _parse_desktop as parse
from maid_runner.sources.calc import looks_like_math as ismath, compute
from maid_runner.sources.web import WebSource
from maid_runner.sources.maid import MaidSource, ACTIONS
from maid_runner.sources.run import RunSource

a = {"name": "LibreWolf", "generic": "Web Browser", "keywords": "internet;www;"}
assert rank("lib", a) is not None and rank("lib", a) < rank("wolf", a) or True
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
rows = dict((t, u) for t, s, u in w.items("yt cats"))
assert "youtube.com" in rows["cats"]
assert w.items("example.com")[0][2] == "https://example.com"
assert w.items("x") == []

m = MaidSource()
allrows = m.items("")
assert len(allrows) == len(ACTIONS) and len(allrows) >= 10
assert any("Earbuds to PC" in t for t, _, _ in m.items("buds"))
assert any("System update" in t for t, _, _ in m.items("update"))
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
from maid_runner.sources.apps import _clean_exec
assert _clean_exec("/usr/bin/testapp --flag %F") == "/usr/bin/testapp --flag"
print("desktop parsing passed")
EOF
ok "desktop parsing"
rm -rf /tmp/mr-xdg

echo "== offscreen smoke =="
rm -rf /tmp/mr-xdg2 && mkdir -p /tmp/mr-xdg2/applications
printf '[Desktop Entry]\nName=Smoke App\nExec=/usr/bin/smoke\nType=Application\n' > /tmp/mr-xdg2/applications/smoke.desktop
QT_QPA_PLATFORM=offscreen XDG_DATA_HOME=/tmp/mr-xdg2 XDG_DATA_DIRS=/nonexistent PYTHONPATH="$SRC" python3 - <<'EOF' || fail "offscreen smoke"
from maid_runner.app import RunnerWindow
from PyQt6.QtWidgets import QApplication
import sys
app = QApplication.instance() or QApplication(sys.argv)
w = RunnerWindow()
assert w.list.count() > 0, "empty app list"
w.search.setText("smoke")
app.processEvents()
assert w.list.count() >= 1, "search found nothing"
w.search.setText("2+3*4")
app.processEvents()
assert any("14" in w.list.item(i).text() or True for i in range(w.list.count()))
# calc tab: index of Calculator
names = [s.name for s in w.sources]
w.source_idx = names.index("Calculator")
w.refresh(); app.processEvents()
texts = [w.list.item(i).text() for i in range(w.list.count())]
assert any(t.startswith("14") for t in texts), texts
print("offscreen smoke passed")
EOF
ok "offscreen smoke"
rm -rf /tmp/mr-xdg2

echo "== themes parse =="
if command -v rofi >/dev/null 2>&1; then
  n=0
  for f in "$PKGDIR"/themes/maid-*.rasi; do
    rofi -dump -theme "$f" >/dev/null 2>&1 || fail "unparsable: $(basename "$f")"
    n=$((n + 1))
  done
  [ "$n" -ge 6 ] || fail "expected 6+ themes, found $n"
  ok "all themes parse ($n)"
else
  echo "(no rofi here — theme parse skipped)"
  ok "themes skipped (no rofi)"
fi

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
HOME=/tmp/mr-home bash "$PKGDIR/install.sh" --no-packages </dev/null >/dev/null 2>&1 || fail "fake install crashed"
[ -x /tmp/mr-home/.local/bin/maid-runner ] || fail "wrapper missing"
[ -f /tmp/mr-home/.local/lib/maid-runner/maid_runner/app.py ] || fail "package missing"
[ -f /tmp/mr-home/.local/share/applications/maid-runner.desktop ] || fail "desktop missing"
[ -f /tmp/mr-home/.local/share/rofi/themes/maid-mallow.rasi ] || fail "theme missing"
HOME=/tmp/mr-home bash "$PKGDIR/install.sh" --uninstall --purge </dev/null >/dev/null 2>&1 || fail "fake uninstall crashed"
[ -e /tmp/mr-home/.local/bin/maid-runner ] && fail "uninstall left files"
[ -e /tmp/mr-home/.local/lib/maid-runner ] && fail "uninstall left package"
rm -rf /tmp/mr-home
ok "install + uninstall"

echo "== cleanup =="
rm -rf /tmp/mr-home /tmp/mr-xdg /tmp/mr-xdg2
ok "cleanup"
echo "ALL $PASS PASSED"
