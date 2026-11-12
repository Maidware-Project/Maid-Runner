#!/usr/bin/env bash
# this is truly my power
# Maid Runner installer: Qt search app + six Maid Scroll palettes.
# Copies files (no symlinks). Usage: ./install.sh [--check] [--no-packages]
#   [--set NAME] [--uninstall [--purge]] [--prefix=DIR]
# --set stores NAME as the active Maid Scroll palette (writes the state
# file the app and maid-scroll cli read). --no-packages is accepted for
# suite installs (Runner has no package dependencies). --prefix installs
# elsewhere (packaging).
set -u
PKGDIR="$(cd "$(dirname "$0")" && pwd)" 2>/dev/null || PKGDIR=""
if [ ! -f "$PKGDIR/install.sh" ]; then
  # piped install (bash <(curl -fsSL ...)): the script is a /dev/fd
  # stream, so there is no package tree next to it. Fetch the repo
  # tarball and continue from there.
  FETCH_TMP="$(mktemp -d /tmp/maidrunner-fetch.XXXXXX)"
  trap 'rm -rf "$FETCH_TMP"' INT TERM
  REPO="Maidware-Project/Maid-Runner"
  LATEST_TAG="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  _fetched=0
  _urls=()
  if [ -n "$LATEST_TAG" ]; then
    _urls+=("https://github.com/$REPO/archive/refs/tags/$LATEST_TAG.tar.gz")
    _urls+=("https://codeberg.org/Maidware_Project/Maid-Runner/archive/${LATEST_TAG}.tar.gz")
  fi
  _urls+=("https://github.com/$REPO/archive/refs/heads/main.tar.gz")
  _urls+=("https://codeberg.org/Maidware_Project/Maid-Runner/archive/main.tar.gz")
  for _url in "${_urls[@]}"; do
    if curl -fsSL "$_url" -o "$FETCH_TMP/repo.tgz" 2>/dev/null && tar -xzf "$FETCH_TMP/repo.tgz" -C "$FETCH_TMP" 2>/dev/null; then
      PKGDIR="$(find "$FETCH_TMP" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
      [ -f "$PKGDIR/install.sh" ] && { _fetched=1; break; }
    fi
    rm -rf "$FETCH_TMP"/* 2>/dev/null || true
  done
  [ "$_fetched" = "1" ] || { echo "could not download the Maid Runner package tree (tried GitHub and Codeberg)" >&2; exit 1; }
fi
BACKUP_TS="$(date +%Y%m%d-%H%M%S)"
CHECK=0; UNINST=0; PURGE=0; PREFIX=""; SET=""
for a in "$@"; do
  case "$a" in
    --check) CHECK=1 ;;
    --uninstall) UNINST=1 ;;
    --purge) PURGE=1 ;;
    --no-config|--no-packages) ;;
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
session_env_line() {
  local de="${XDG_CURRENT_DESKTOP:-}" sess="${XDG_SESSION_DESKTOP:-}" dses="${DESKTOP_SESSION:-}"
  local label="unknown"
  case "$de $sess $dses" in
    *[Pp]lasma*|*[Kk][Dd][Ee]*) label="KDE Plasma" ;;
    *[Gg][Nn][Oo][Mm][Ee]*) label="GNOME" ;;
    *[Xx][Ff][Cc][Ee]*) label="XFCE" ;;
    *[Mm][Aa][Tt][Ee]*) label="MATE" ;;
    *[Cc]innamon*) label="Cinnamon" ;;
    *[Ll][Xx][Qq]t*) label="LXQt" ;;
    *[Hh]yprland*) label="Hyprland" ;;
    *[Ss]way*) label="Sway" ;;
    *[Ii]3*) label="i3" ;;
    *) [ -n "${de:-}${sess:-}${dses:-}" ] && label="$de" || label="unknown" ;;
  esac
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -x gpuishell >/dev/null 2>&1 && label="$label (+ GPUIShell/gpuishell)"
    pgrep -x horizon >/dev/null 2>&1 && label="$label (+ Event Horizon)"
    pgrep -x kineticwe >/dev/null 2>&1 && label="$label (+ KineticWE)"
  fi
  echo "Session: $label | XDG_CURRENT_DESKTOP=${de:-n/a} | DESKTOP_SESSION=${dses:-n/a} | WAYLAND=${WAYLAND_DISPLAY:+yes}${WAYLAND_DISPLAY:-no} | X11=${DISPLAY:+yes}${DISPLAY:-no}"
}
distro_env_line() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "Distro: ${PRETTY_NAME:-${NAME:-unknown}} (id=${ID:-?}${ID_LIKE:+ like=${ID_LIKE}})"
  elif [ "$(uname -s 2>/dev/null)" = "Linux" ]; then
    echo "Distro: Linux (unidentified)"
  else
    echo "Distro: $(uname -s 2>/dev/null || echo unknown)"
  fi
}
kde_env
say "$(kde_env_line)"
say "$(session_env_line)"
say "$(distro_env_line)"

if [ "$UNINST" = "1" ]; then
  rm -f "$BINDIR"/maid-runner
  rm -f "$BINDIR"/maid-scroll
  rm -f "$BINDIR"/maid-suite-update
  rm -rf "$LIBDIR"/maid-runner
  rm -rf "$SHAREDIR"/maid-runner
  rm -f "$SHAREDIR"/applications/maid-runner.desktop
  rm -f "$SHAREDIR"/applications/maid-suite-update.desktop
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

# the applications-menu updater: pulls every maid tool from github and
# redeploys (machinery lives in Maid AU; this only points the menu at
# it). missing Maid AU says so in the wrapper instead of a dead click.
copy_one "$PKGDIR/bin/maid-suite-update" "$BINDIR/maid-suite-update"
[ "$CHECK" = "0" ] && chmod +x "$BINDIR"/maid-suite-update 2>/dev/null || true
copy_one "$PKGDIR/desktop/maid-suite-update.desktop" \
  "$SHAREDIR/applications/maid-suite-update.desktop" $REWRITE

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
