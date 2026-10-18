# Maid Runner - search everything from one key

a launcher and search box (Qt) for kde plasma: a centered search card over a dimmed backdrop. type, hit enter. typing searches every source at once - all applications, the maid suite, files, run, calculator and web - so nothing needs a tab switch first; with the box empty, tab moves between tabs that mirror your app menu (all applications, then the menu's groups: internet, games, multimedia, ...). caps lock cycles the six Maid Scroll palettes. native wayland, no taskbar icon, no accounts, no telemetry.

```
src/maid_runner/             the Qt app (window + one module per source)
src/maid_runner/palettes.py  the six palettes (Maid Scroll source of truth)
src/maid_runner/scroll.py    list/scroll/set the palette, no display needed
bin/maid-runner              entry: the Qt app
bin/maid-scroll              terminal entry for the palettes
themes/maid-*.rasi           the same six palettes as drun themes (fallback)
desktop/                     launcher icon (pin it, bind a key to it)
install.sh                   installer (files only, no packages)
```

## quick start

```sh
bash install.sh            # app + palettes + launcher
```

bind `maid-runner --toggle` to a key (below), or run it from your
apps menu - it *is* an application entry itself.

## keybinding 

the repo never sets keybinds - that's personal config and stays on
your machine. to bind it on Plasma:

1. Settings → Keyboard → Shortcuts → Custom Shortcuts
2. Add → Command/URL, command: `~/.local/bin/maid-runner --toggle`
3. set whatever key feels right (Meta+Space is the classic runner key)

with `--toggle` one key both opens and closes the window; plain
`maid-runner` always opens it. typing finds things from every source
at once - no tab switch needed; with the box empty, TAB browses the
tabs (shift+TAB goes back). enter runs, esc - or a click outside the
card - closes. caps lock cycles the six palettes and stores the pick,
so the next launch opens on it. empty query on Maid lists every
suite action. opening and closing is a short fade at your desktop's
animation speed (Plasma: animations set off means an instant swap).

## resident

the first launch stays around: closing the window hides it, and every
later open is a repaint - instant - not a start. a second launch just
hands over a word over a unix socket
(`$XDG_RUNTIME_DIR/maid-runner.sock`) and exits.

- `maid-runner`           open the window (starts the resident if none)
- `maid-runner --toggle`  open if hidden, close if open - the keybind command
- `maid-runner --service` start hidden and wait (autostart at login, your call)
- `maid-runner --quit`    stop the resident

on KWin the window is a wayland layer surface, so it never shows in
the taskbar or alt-tab.

## sources

- **Applications** - parsed from the same XDG menu data KDE shows
  (honors NoDisplay/Hidden/TryExec, flatpak exports included).
  terminal apps open in your terminal.
- **the menu's groups** - internet, games, multimedia, graphics,
  office, utilities, development, system, help: one tab per group that
  has apps here, in the app manager's order. an app that honestly
  sits in two categories sits in both tabs.
- **Maid** - full use of the suite: earbuds to PC/phone/off/radio,
  system check/update, share to phone, receive from phone, helper
  check/fix. anything printing runs in a terminal; instant actions
  run silent. the tab appears once at least one Maid tool is
  installed.
- **Files** - your files by name, from your home folder. scanned in
  the background while the runner is up, answered from memory; no
  database, nothing stored.
- **Run** - PATH binaries, always in a terminal so CLI tools work.
- **Calculator** - safe arithmetic only (AST allowlist, never eval);
  enter copies the result.
- **Web** - `yt`/`wiki`/`gh`/`g`/`ddg`/`aw`/`aur`/`so` prefixes,
  `!bang` goes to duckduckgo, bare URLs open directly, anything else
  asks SearXNG. every result opens in your default browser, never
  inside the runner.

## search

bare text goes to [SearXNG](https://github.com/searxng/searxng), a free
and open source metasearch engine. it is the official search behind
Maid Runner on purpose: no profiles, no ad tracking, results pulled
from many engines at once, so your searches stay yours. whatever you
open - a search or a URL - opens in your default browser; the runner
itself makes no network calls.

the default instance is `search.jeremyh.xyz`. it is open source, so
any public instance works - point the runner at another one with
`MAID_RUNNER_SEARX`:

```sh
MAID_RUNNER_SEARX=https://searxng.site maid-runner   # use another instance
```

## weight

the whole cost is one qt process. measured on a plasma wayland
session: about 40 MB of its own while it waits before the first open
(raw process size ~80 MB; the rest is qt6, shared with the rest of
your desktop), about 75 MB of its own once the window has been built
(raw ~135 MB). nothing else grows between opens. no database and no
second process: the file list lives in memory while the runner does,
and is gone when it is.

## why not krunner / rofi / albert?

krunner is plugins-in-process and does what Plasma says. rofi is
superb but dumb (and themed separately). Maid Runner is one focused
search box whose best source - the Maid tab - knows *your* system:
earbuds state, pending updates, share targets.

## themes

six palettes ship in the app: `dark` (breeze match), `light`, `tokyo`
(the default), `mallow`, `green`, `blue`. the chosen one is one line of
state under `~/.config/maid-scroll/`, written by the app (caps lock) and
by `maid-scroll`:

```sh
maid-scroll list         # every palette, star on the current one
maid-scroll next         # advance one, keep it
maid-scroll set mallow   # jump straight to one
```

the installer can set the active palette at install time:

```sh
bash install.sh --set mallow      # store mallow as the active palette
```

## uninstall

```sh
bash install.sh --uninstall            # app + entry out
```

your Maid Scroll state is left in `~/.config/maid-scroll/`.

## License

MIT - see LICENSE. a Maidware Project, Forkable open source tools served to help
