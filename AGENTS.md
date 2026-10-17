# AGENTS.md - Maid Runner (for AI assistants; humans see README.md)

One maintainer, a couple of friends, and six Maid Scroll palettes. Keep
changes small enough to review, and ask before adding a dependency. The
six themes are user-tweaked forks: keep the shared structure identical
across all six, palette block aside, so diffs stay readable.

Say what you actually did, not what you were asked to do. A UI bug hides
well in a diff, so if you didn't launch the app or dump every theme, say
so instead of ticking the box.

The assistant helps, a person decides. Comment for whoever debugs this
next, not for the model that suggested it.

## What you can't do here

- The app is Qt. A real look at it needs PyQt6 and a display; the suite
  runs an offscreen smoke test, which is not the same as using the window.
- Themes are dumped and checked, not seen. A theme can dump clean and
  still look wrong on screen.
- Source actions call out to real system tools (bluetooth, package
  managers, kdeconnect). The suite fakes those, so it proves the wiring,
  not the outcome.

## Layout

- `src/maid_runner/` the Qt app (app window + per-source modules)
- `bin/maid-runner` entry: the Qt app (needs PyQt6 + a display)
- `bin/maid-scroll` entry: list/set the palette, no display needed
- `themes/maid-*.rasi` six theme mirrors (same layout, six palettes;
  `palettes.py` is the source of truth and tests keep the hex in sync)
- `desktop/` launcher, `install.sh` file copier + optional palette
  activation, `tests/` suite (unit + offscreen smoke + installer)

## Rules

- No personal data in repo (no font names that assume a setup -
  themes use system monospace; document font overrides in README).
- Palette-only diffs between themes: never restructure one file
  without the other five.
- Installer copies, never symlinks, backs up overwritten files.
- CODE_OF_CONDUCT.md applies to code, comments, and docs:
  technical scope, no politics, stay neutral.
- Commit style: short lowercase summaries with a prefix (`fix:`,
  `feat:`, `docs:`, `tests:`, `chore:`), one logical change each.
  Sign off - the trailer is exactly `Signed-off-by: visa`, no email.

## Principles

Keep it simple ([KISS](https://en.wikipedia.org/wiki/KISS_principle)) and
boring. In practice:

- The smallest change that solves the problem; nothing added "for later"
  (YAGNI).
- One place owns each fact; no repeated logic (DRY).
- Each tool does one thing well and composes (unix philosophy, rule of
  least power).
- Readable beats clever; less is more (worse is better).
- Delete what nothing needs instead of keeping it around.

## Never

- Never push. The maintainer pushes; commits stay local until asked.
- Never restructure one theme without the other five; palettes are the
  only intended difference.
- Never assume a font or a machine setup; themes use system monospace.
- Never report a launched app or a dumped theme you did not run.

## Boundaries (do not touch)

- The shared structure of the six `themes/maid-*.rasi` files.
- The installer contract: copies, never symlinks, backs up.

## Verify

- `bash tests/run.sh` - pure-python unit tests, offscreen app smoke
  test, theme presence + hex sync, fake-HOME install/uninstall.
  needs PyQt6 only (CI has it).
- `bash install.sh --check` - dry run, must write nothing.
- Personal-data grep lives in tests/run.sh - keep it green
  (notably: no font names assuming a setup, no machine specifics).

## Making a change

1. `git status -sb` first. A commit or a sync can land while you work,
   and amending something already pushed leaves duplicate commits.
2. Make the smallest diff that solves the stated problem.
3. Run `bash tests/run.sh` and `bash install.sh --check`.
4. If it shows in the app or a theme, look at it - offscreen, or on your
   desktop - and say which it was.
5. Pass `docs/REVIEW.md`, then commit with a sign-off. Do not push.

## References

- `README.md` - what it does, themes, keybinds, font overrides
- `docs/REVIEW.md` - the checklist to pass before a change ships
- `CONTRIBUTING.md` - how to take part
- `CODE_OF_CONDUCT.md` - scope, and what stays out of the repo
- `SECURITY.md` - how to report a security problem
