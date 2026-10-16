#!/usr/bin/env bash
# Maid Runner installer: Qt search app + six rofi drun themes.
# Copies files (no symlinks). Usage: ./install.sh [--check]
#   [--set NAME] [--uninstall [--purge]] [--prefix=DIR]
# --set picks the active rofi theme (else asks on a tty, skips otherwise).
# --prefix installs elsewhere (packaging).
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
    *) echo "unknown option: $a (see header)" >&2; exit 2 ;;
  esac
done
if [ -z "$PREFIX" ]; then PREFIX="$HOME/.local"; fi
if [ "$PREFIX" = "$HOME/.local" ]; then
  BINDIR="$HOME/.local/bin"; LIBDIR="$HOME/.local/lib"; SHAREDIR="$HOME/.local/share"; REWRITE=1
else
  BINDIR="${DESTDIR:-}$PREFIX/bin"; LIBDIR="${DESTDIR:-}$PREFIX/lib"; SHAREDIR="${DESTDIR:-}$PREFIX/share"; REWRITE=1
fi
THEMEDIR="$SHAREDIR/rofi/themes"

say()  { echo "==> $*"; }

if [ "$UNINST" = "1" ]; then
  rm -f "$THEMEDIR"/maid-*.rasi
  rm -f "$BINDIR"/maid-runner
  rm -rf "$LIBDIR"/maid-runner
  rm -f "$SHAREDIR"/applications/maid-runner.desktop
  say "uninstalled (app, themes, entry out; your rofi config untouched - re-point @theme if it named a maid theme)"
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
    sed -e "s|/home/EXAMPLEUSER/|${HOME//&/\\&}|g" "$src" > "$tmp"
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

for f in "$PKGDIR"/themes/maid-*.rasi; do
  [ -f "$f" ] || continue
  copy_one "$f" "$THEMEDIR/$(basename "$f")"
done
copy_one "$PKGDIR/bin/maid-runner" "$BINDIR/maid-runner"
[ "$CHECK" = "0" ] && chmod +x "$BINDIR"/maid-runner 2>/dev/null || true
# app package (Qt sources); the wrapper resolves it via ../lib
[ "$CHECK" = "1" ] || mkdir -p "$LIBDIR/maid-runner"
cd "$PKGDIR/src" || { say "missing src tree: $PKGDIR/src"; exit 1; }
while IFS= read -r -d '' f; do
  copy_one "$PKGDIR/src/$f" "$LIBDIR/maid-runner/$f"
done < <(find maid_runner -name "*.py" -print0)
copy_one "$PKGDIR/desktop/maid-runner.desktop" \
  "$SHAREDIR/applications/maid-runner.desktop" $REWRITE
[ "$CHECK" = "1" ] && { say "(check only, nothing changed)"; exit 0; }

# activate one theme by pointing config.rasi at it (backs config up first)
pick=""
if [ -n "$SET" ]; then
  pick="$SET"
elif [ -t 0 ]; then
  echo "available: $(cd "$THEMEDIR" && ls maid-*.rasi | sed 's/^maid-//;s/\.rasi$//' | tr '\n' ' ')"
  printf 'Set one as your rofi theme now? [name/empty to skip]: '
  read -r pick
fi
if [ -n "$pick" ]; then
  themefile="$THEMEDIR/maid-$pick.rasi"
  [ "$pick" = "${pick#maid-}" ] || themefile="$THEMEDIR/$pick.rasi"
  if [ -f "$themefile" ]; then
    conf="$HOME/.config/rofi/config.rasi"
    if [ -f "$conf" ] && grep -q "@theme" "$conf"; then
      cp -a "$conf" "${conf}.bak-${BACKUP_TS}"
      # shellcheck disable=SC2086
      sed -i -e "s|^\(\s*\)@theme.*|\1@theme \"${themefile//&/\\&}\"|" "$conf"
      say "theme set: $pick (config backed up)"
    else
      say "no @theme line in $conf - set it by hand to: $themefile"
    fi
  else
    say "no such theme: $pick (see list above)"
  fi
else
  say "no theme activated (point @theme at one file under $THEMEDIR when ready)"
fi
say "done."
