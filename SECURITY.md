# security

Maid Runner is a launcher. how it is kept safe:

- the calculator parses arithmetic with an AST allowlist. there is no
  `eval`; only numbers and `+ - * / % // **` pass.
- direct launches use argv lists (no shell string). Terminal command wrapping uses a quoted `/bin/sh -c` command so POSIX quoting is applied safely.
- it launches your applications and opens search URLs in your browser when requested. The installer/update flow may download release tarballs when you run it.

to report a problem, open an issue on the repository.
