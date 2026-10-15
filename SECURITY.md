# security

Maid Runner is a launcher. how it is kept safe:

- the calculator parses arithmetic with an AST allowlist. there is no
  `eval`; only numbers and `+ - * / % // **` pass.
- every external command runs with an argv list, never a shell string, so
  a search query cannot become a command.
- it launches your applications and opens search URLs in your browser. it
  downloads nothing on its own.
- no telemetry, no accounts, nothing phones home.

to report a problem, open an issue on the repository.
