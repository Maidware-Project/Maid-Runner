# Maid Runner - search everything from one key

category: launcher

a small Qt search app for KDE Plasma: type, hit enter. TAB cycles
sources - Applications (straight from the KDE menu data), Maid
(every suite action), Run (PATH commands), Calculator, Web. no
accounts, no daemons, no indexing service.

```
src/maid_runner/      the Qt app (window + one module per source)
bin/maid-runner       entry: Qt app when PyQt6 + display exist,
                      rofi combi fallback otherwise
themes/maid-*.rasi    six drun themes for the fallback (same layout)
desktop/              launcher icon (pin it, bind a key to it)
install.sh            installer (files only, no packages)
```

## quick start

```sh
bash install.sh            # app + themes + launcher
```

bind `maid-runner` to a key, or run it from rofi/dash once - it
*is* an application entry itself.

## keybinding (your keys, your business)

the repo never sets keybinds - that's personal config and stays on
your machine. to bind it on Plasma:

1. Settings → Keyboard → Shortcuts → Custom Shortcuts
2. Add → Command/URL, command: `~/.local/bin/maid-runner`
3. set whatever key feels right (Meta+Space is the classic runner key)

rofi fallback users: same steps with whatever rofi command you run.

type to filter, TAB to change source, enter to run, esc to close.
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
  bare URLs open directly, anything else asks DuckDuckGo.

## why not krunner / rofi / albert?

krunner is plugins-in-process and does what Plasma says. rofi is
superb but dumb (and themed separately). Maid Runner is one focused
search box whose best source - the Maid tab - knows *your* system:
earbuds state, pending updates, share targets. plus: six matching
rofi themes included for when PyQt6 isn't around.

tested on openSUSE Tumbleweed (KDE Plasma 6, Wayland) with PyQt6 +
Qt 6.

## themes

same comfortable drun layout in six palettes (only colors differ,
so diffs stay readable): `maid-dark` (breeze match), `maid-light`,
`maid-tokyo`, `maid-mallow`, `maid-green`, `maid-blue`.

```sh
bash install.sh --set mallow      # copy + activate maid-mallow
```

or copy any file to `~/.config/rofi/themes/` and point `@theme`
at it by hand. font line in each file is system monospace - set
your own in one line.

## uninstall

```sh
bash install.sh --uninstall            # app, themes, entry out
```

your rofi config is untouched (re-point `@theme` yourself if it
named a maid theme).

## License

MIT - see LICENSE. a Maidware Project, Forkable open source tools served to help
