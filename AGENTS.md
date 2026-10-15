# AGENTS.md — Maid Runner (for AI assistants; humans see README.md)

One maintainer plus friends helping out — keep every change small,
reviewable, and justified. Theme files are user-tweaked forks: keep
the shared structure identical across all six (palette block only
differs) so diffs stay readable.

Honesty is non-negotiable: say what you actually did versus what you
were asked to do. Never claim a test ran or a look was verified
unless it truly happened in this session.

## Layout

- `src/maid_runner/` the Qt app (app window + per-source modules)
- `bin/maid-runner` entry: Qt app when PyQt6 + display exist, rofi
  combi fallback otherwise
- `themes/maid-*.rasi` six drun themes (same layout, six palettes)
- `desktop/` launcher, `install.sh` file copier + optional theme
  activation, `tests/` suite (unit + offscreen smoke + installer)

## Rules

- No personal data in repo (no font names that assume a setup —
  themes use system monospace; document font overrides in README).
- Palette-only diffs between themes: never restructure one file
  without the other five.
- Installer copies, never symlinks, backs up overwritten files.
- CODE_OF_CONDUCT.md applies to code, comments, and docs:
  technical scope, no politics, stay neutral.
- Commit style: short lowercase summaries with a prefix (`fix:`,
  `feat:`, `docs:`, `tests:`, `chore:`), one logical change each.
  Sign off (`git commit -s`); AI work adds `Assisted-by:`.

## Verify

- `bash tests/run.sh` — pure-python unit tests, offscreen app smoke
  test, rofi -dump on every theme, fake-HOME install/uninstall.
  needs PyQt6 + rofi installed (CI has both).
- `bash install.sh --check` — dry run, must write nothing.
- Personal-data grep lives in tests/run.sh — keep it green
  (notably: no font names assuming a setup, no machine specifics).

Before finishing: pass docs/REVIEW.md.
