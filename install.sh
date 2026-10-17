#!/usr/bin/env bash
# Maid Runner installer: Qt search app + six Maid Scroll palettes.
# Copies files (no symlinks). Usage: ./install.sh [--check]
#   [--set NAME] [--uninstall [--purge]] [--prefix=DIR]
# --set stores NAME as the active Maid Scroll palette (writes the state
# file the app and maid-scroll cli read). --prefix installs elsewhere
# (packaging).
set -u
PKGDIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_TS="$(date +%Y%m%d-%H%M%S)"
CHECK=0; UNINST=0; PURGE=0; PREFIX=""; SET=""
for a in "$@"; do
  case "$a" in
    --check) CHECK=1 ;;
    --uninstall) UNINST=1 ;;
    --purge) PURGE=1 ;;
    --no-config) ;;
    --prefix=*) PREFIX="${a#--prefix=}" ;;
    --set=*) SET="${a#--set=}" ;;
    --set) SET_NEXT=1 ;;
    *) if [ "${SET_NEXT:-0}" = "1" ]; then SET="$a"; SET_NEXT=0
       else echo "unknown option: $a (see header)" >&2; exit 2; fi ;;
  esac
done
[ "${SET_NEXT:-0}" = "1" ] && { echo "--set needs a name" >&2; exit 2; }
if [ -z "$PREFIX" ]; then PREFIX="$HOME/.local"; fi
if [ "$PREFIX" = "$HOME/.local" ]; then
  BINDIR="$HOME/.local/bin"; LIBDIR="$HOME/.local/lib"; SHAREDIR="$HOME/.local/share"; REWRITE=1
else
  BINDIR="${DESTDIR:-}$PREFIX/bin"; LIBDIR="${DESTDIR:-}$PREFIX/lib"; SHAREDIR="${DESTDIR:-}$PREFIX/share"; REWRITE=1
fi

say()  { echo "==> $*"; }

if [ "$UNINST" = "1" ]; then
  rm -f "$BINDIR"/maid-runner
  rm -f "$BINDIR"/maid-scroll
  rm -rf "$LIBDIR"/maid-runner
  rm -f "$SHAREDIR"/applications/maid-runner.desktop
  rm -f "$SHAREDIR"/rofi/themes/maid-*.rasi
  if [ "$PURGE" = "1" ]; then
    rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/maid-scroll"
    say "uninstalled (app + entry out; Maid Scroll state purged)"
  else
    say "uninstalled (app + entry out; Maid Scroll state left in ~/.config/maid-scroll)"
  fi
  exit 0
fi

copy_one() {
  local src="$1" dest="$2" tmp="" rewrite="${3:-0}"
  if [ "$CHECK" = "1" ]; then echo "COPY $dest"; return 0; fi
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp)" || return 1
  trap 'rm -f "$tmp"' RETURN
  if [ "$rewrite" = "1" ]; then
    # escape & (sed replacement metachar) in $HOME
    sed -e "s|/home/visa|${HOME//&/\\&}|g" "$src" > "$tmp"
  else
    cp -a "$src" "$tmp"
  fi
  if [ -e "$dest" ] && ! cmp -s "$tmp" "$dest"; then
    cp -a "$dest" "${dest}.bak-${BACKUP_TS}"
    say "backed up $dest"
  fi
  cat "$tmp" > "$dest"
  echo "installed $dest"
}

copy_one "$PKGDIR/bin/maid-runner" "$BINDIR/maid-runner"
[ "$CHECK" = "0" ] && chmod +x "$BINDIR"/maid-runner 2>/dev/null || true
copy_one "$PKGDIR/bin/maid-scroll" "$BINDIR/maid-scroll"
[ "$CHECK" = "0" ] && chmod +x "$BINDIR"/maid-scroll 2>/dev/null || true
# app package (Qt sources); the wrapper resolves it via ../lib
[ "$CHECK" = "1" ] || mkdir -p "$LIBDIR/maid-runner"
cd "$PKGDIR/src" || { say "missing src tree: $PKGDIR/src"; exit 1; }
while IFS= read -r -d '' f; do
  copy_one "$PKGDIR/src/$f" "$LIBDIR/maid-runner/$f"
done < <(find maid_runner -name "*.py" -print0)
copy_one "$PKGDIR/desktop/maid-runner.desktop" \
  "$SHAREDIR/applications/maid-runner.desktop" $REWRITE
[ "$CHECK" = "1" ] && { say "(check only, nothing changed)"; exit 0; }

# --set NAME stores a palette in the Maid Scroll state file (the same
# one the app's caps lock and `maid-scroll set` write). No rofi, no
# config editing - just the active palette name.
if [ -n "$SET" ]; then
  STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/maid-scroll"
  [ "$CHECK" = "0" ] && mkdir -p "$STATE_DIR"
  echo "activate: $SET"
  [ "$CHECK" = "0" ] && printf '%s\n' "$SET" > "$STATE_DIR/theme"
  say "maid scroll palette set: $SET (state: $STATE_DIR/theme)"
else
  say "no palette set (run: maid-scroll set NAME, or install.sh --set NAME)"
fi
say "done."
