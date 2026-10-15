# review checklist

run through these before you open the pull request.

1. plain words. could a non-technical friend follow the README diff with
   no help? no jargon without an explanation next to it.
2. off by default. installing never activates a theme unless asked
   (`--set` or a yes). non-interactive runs change no config.
3. proven, not claimed. `bash tests/run.sh` green (every theme parses
   under `rofi -dump`).
4. docs match code. README lists exactly the shipped themes. no personal
   data anywhere.
5. uninstall story intact. `--uninstall` removes theme files, warns about
   re-pointing `@theme`. tested with a fake HOME.
