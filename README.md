# Maid Runner - search everything from one key

a launcher and search box (Qt) for kde plasma: a centered search card over a dimmed backdrop. type, hit enter. tab cycles sources - applications (from kde menu), maid (suite actions), run (path commands), calculator, web. caps lock cycles the six Maid Scroll palettes. no accounts, no daemons, no indexing service.

```
src/maid_runner/             the Qt app (window + one module per source)
src/maid_runner/palettes.py  the six palettes (Maid Scroll source of truth)
src/maid_runner/scroll.py    list/scroll/set the palette, no display needed
bin/maid-runner              entry: the Qt app (rofi combi fallback otherwise)
bin/maid-scroll              terminal entry for the palettes
themes/maid-*.rasi           the same six palettes as drun themes (fallback)
desktop/                     launcher icon (pin it, bind a key to it)
install.sh                   installer (files only, no packages)
```

## quick start

```sh
bash install.sh            # app + palettes + launcher
```

bind `maid-runner` to a key, or run it from your apps menu once - it
*is* an application entry itself.

## keybinding 

the repo never sets keybinds - that's personal config and stays on
your machine. to bind it on Plasma:

1. Settings → Keyboard → Shortcuts → Custom Shortcuts
2. Add → Command/URL, command: `~/.local/bin/maid-runner`
3. set whatever key feels right (Meta+Space is the classic runner key)

type to filter, TAB to change source (shift+TAB goes back), enter to
run, esc - or a click outside the card - closes. caps lock cycles the
six palettes and stores the pick, so the next launch opens on it.
empty query on Maid lists every suite action.

## sources

- **Applications** - parsed from the same XDG menu data KDE shows
  (honors NoDisplay/Hidden/TryExec, flatpak exports included).
  terminal apps open in your terminal.
- **Maid** - full use of the suite: earbuds to PC/phone/off/radio,
  system check/update, share to phone, receive from phone, helper
  check/fix. anything printing runs in a terminal; instant actions
  run silent.
- **Run** - PATH binaries, always in a terminal so CLI tools work.
- **Calculator** - safe arithmetic only (AST allowlist, never eval);
  enter copies the result.
- **Web** - `yt query`, `wiki query`, `gh query`, `g/ddg query`,
  bare URLs open directly, anything else asks SearXNG.

## search

bare text goes to [searxng](https://github.com/searx/searxng), a free
and open source metasearch engine. it is the official search behind
Maid Runner on purpose: no profiles, no ad tracking, results pulled
from many engines at once, so your searches stay yours.

the default instance is `search.jeremyh.xyz`. it is open source, so
any public instance works - point the runner at another one with
`MAID_RUNNER_SEARX`:

```sh
MAID_RUNNER_SEARX=https://searxng.site maid-runner   # use another instance
```

## why not krunner / rofi / albert?

krunner is plugins-in-process and does what Plasma says. rofi is
superb but dumb (and themed separately). Maid Runner is one focused
search box whose best source - the Maid tab - knows *your* system:
earbuds state, pending updates, share targets. plus: six matching
rofi themes included for when PyQt6 isn't around.

## themes

six palettes ship in the app and as matching drun themes (only the
palette block differs, so diffs stay readable): `dark` (breeze match),
`light`, `tokyo` (the default), `mallow`, `green`, `blue`. the chosen
one is one line of state under `~/.config/maid-scroll/`, written by the
app (caps lock) and by `maid-scroll`:

```sh
maid-scroll list         # every palette, star on the current one
maid-scroll next         # advance one, keep it
maid-scroll set mallow   # jump straight to one
```

the drun themes are the fallback for when PyQt6 or a display is
missing; each uses system monospace - set your own in one line. the
installer can point the fallback at one:

```sh
bash install.sh --set mallow      # copy + activate maid-mallow
```

## uninstall

```sh
bash install.sh --uninstall            # app, themes, entry out
```

your rofi config is untouched (re-point `@theme` yourself if it
named a maid theme).

## License

MIT - see LICENSE. a Maidware Project, Forkable open source tools served to help
