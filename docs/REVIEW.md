# Review checklist — pass all five before any change ships

1. **Plain words.** Could a non-technical friend follow the README
   diff with no help? No jargon without an explanation next to it.
2. **Off by default.** Installing never activates a theme unless
   asked (`--set` or a yes). Non-interactive runs change no config.
3. **Proven, not claimed.** `bash tests/run.sh` green (every theme
   parses under `rofi -dump`).
4. **Docs match code.** README lists exactly the shipped themes.
   No personal data anywhere.
5. **Uninstall story intact.** `--uninstall` removes theme files,
   warns about re-pointing `@theme`. Tested with a fake HOME.
