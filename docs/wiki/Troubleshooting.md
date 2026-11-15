# Troubleshooting

## Runner does not open
- Run `maid-runner` from a terminal to see errors
- Ensure you are in a graphical session (Wayland/X11)
- Check if another resident instance/socket is stale; try `maid-runner --quit` then relaunch

## Shortcut/toggle not working
- Verify the keybinding command is `maid-runner --toggle` (correct path in your environment)
- Test the command manually first
- Some desktops/WMs require re-login/reload for new shortcuts

## Search/web results issues
- Confirm network access and default browser behavior
- Override SearXNG instance with `MAID_RUNNER_SEARX` if needed

## Visual/session glitches after big upgrades
- If system libraries were upgraded during an active session, log out/in to avoid mixed Qt/graphics/runtime state issues.
