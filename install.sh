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
  BINDIR="${DESTDIR:-}$PREFIX/bin"; LIBDIR="${DESTDIR:-}$PREFIX/lib"; SHAREDIR="${DESTDIR:-}$PREFIX/share"; REWRITE=2
fi

say()  { echo "==> $*"; }

# Report the KDE stack so install logs show what this machine runs.
kde_env() {
  local plasma fw qt kc
  plasma=$(plasmashell --version 2>/dev/null | awk 'NR==1{print $2}')
  [ -n "$plasma" ] || plasma=$(kwin_wayland --version 2>/dev/null | awk 'NR==1{print $2}')
  fw=$(kf6-config --version 2>/dev/null)
  [ -n "$fw" ] || fw=$(pkg-config --modversion KF6CoreAddons 2>/dev/null)
  [ -n "$fw" ] || fw=$(rpm -q --qf '%{VERSION}' kf6-kcoreaddons 2>/dev/null)
  [ -n "$fw" ] || fw=$(dpkg-query -W -f='${Version}' libkf6coreaddons6 2>/dev/null)
  [ -n "$fw" ] || fw=$(pacman -Q kf6-kcoreaddons 2>/dev/null | awk '{print $2}')
  qt=$(qmake6 -query QT_VERSION 2>/dev/null)
  [ -n "$qt" ] || qt=$(qtpaths6 --qt-version 2>/dev/null)
  [ -n "$qt" ] || qt=$(pkg-config --modversion Qt6Core 2>/dev/null)
  kc=$(kdeconnectd --version 2>/dev/null | awk 'NR==1{print $NF}')
  [ -n "$kc" ] || kc=$(kdeconnect-cli --version 2>/dev/null | awk 'NR==1{print $NF}')
  KDE_PLASMA="$plasma"
  KDE_FRAMEWORKS="$fw"
  KDE_QT="$qt"
  KDE_CONNECT="$kc"
}
kde_env_line() {
  if [ -z "${KDE_PLASMA:-}${KDE_FRAMEWORKS:-}${KDE_QT:-}${KDE_CONNECT:-}" ]; then
    echo "KDE: not detected (non-KDE session or tools missing)"
  else
    echo "KDE: Plasma ${KDE_PLASMA:-?} | Frameworks ${KDE_FRAMEWORKS:-?} | Qt ${KDE_QT:-?} | KDE Connect ${KDE_CONNECT:-not installed}"
  fi
}
kde_env
say "$(kde_env_line)"

if [ "$UNINST" = "1" ]; then
  rm -f "$BINDIR"/maid-runner
  rm -f "$BINDIR"/maid-scroll
  rm -rf "$LIBDIR"/maid-runner
  rm -rf "$SHAREDIR"/maid-runner
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
    sed -e "s|@HOME@|${HOME//&/\\&}|g" "$src" > "$tmp"
  elif [ "$rewrite" = "2" ]; then
    # system package: bare command names, resolved via PATH
    sed -e "s|@HOME@||g" -e "s|/.local/bin/||g" "$src" > "$tmp"
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

# the kdeconnect early-login fix lives in Maid Helper's `kdeconnect`
# doctor (maid-helper --only kdeconnect --fix); it is not shipped here.
# clean a stale patch copy left by older installs
if [ "$CHECK" = "0" ]; then rm -rf "$SHAREDIR/maid-runner/patches"; fi

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
