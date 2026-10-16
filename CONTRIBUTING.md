# contributing

small, reviewable changes only - one logical change per pull request.
split anything that grows into a story. read AGENTS.md first; it applies
to humans and AI assistants alike. maintained by Maidware Project.

## commits

- short lowercase summaries with a prefix: `fix:`, `feat:`, `docs:`,
  `tests:`, `chore:` - e.g. `fix: stop the rofi fallback closing on an
  empty query`
- sign off every commit (`git commit -s` appends it):
  `Signed-off-by: Your Name <you@example.com>` - the developer's
  certificate of origin, your word that you may contribute it
- AI-assisted work gets an `Assisted-by:` trailer naming the tool, e.g.
  `Assisted-by: opencode (muse-spark)`. the kernel requires it; so do we.
  a claimed test that didn't run is worse than no test.
- bug fixes name what they fix: `Fixes: #123` or `Closes: #123`

## before opening anything

- `bash tests/run.sh` green, output pasted in the pull request. it's
  headless: python unit tests for the sources and scoring, one offscreen
  Qt launch, a parse of all six themes, a check that their structure still
  matches, and a fake-HOME install/uninstall.
- `bash install.sh --check` writes nothing
- CI must be green before review - a green run on your machine is the
  start, not the finish
- changed a theme? keep it a palette-only diff and say which one you
  looked at on screen
- no personal data anywhere. the suite scans for it, minus the desktop
  Exec paths install.sh rewrites by design

## know your patch

know what every line does, assistant-written ones included. if you can't
explain it, don't send it.

basic linux expected: the terminal, permissions, sudo, `~/.config`. not an
expert, but this launcher runs on other people's machines, so guessing
isn't contributing.

reviewers here are people, not bots: expect to answer questions about your
patch, and don't open one you can't back up. unattended drive-by or bot
PRs get closed.

## issues

use the bug report template with the diagnostics it asks for, minus
anything personal. "it doesn't work" with no detail gets closed with a
pointer back here.

behavior: CODE_OF_CONDUCT.md (technical scope only, no politics,
stay neutral).
