# arts agent guide

## mission

- manage image files and metadata from a CLI
- store image metadata in SQLite
- keep content-addressed image files grouped by artist
- provide artist and album views with ordered sequences through chafa

## working style

- keep the main command flow easy to read
- prefer minimal mvp implementations over broad abstractions
- make output readable for operators first
- design changes so they can later support automated checks and record output

## shell compatibility

- keep shell code compatible with `bash`
- support Debian and iSH
- avoid bash 4+ features such as `mapfile`, associative arrays, and `readarray`
- prefer simple loops and explicit data collection over version-specific helpers
- keep application logic in shell scripts and persist metadata with `sqlite3`
- accept image paths expanded by the client shell so wildcard batches stay simple
- do not accept image data from stdin

## shell format

- use `#!/usr/bin/env bash` for executable bash entrypoints
- keep executable command files in this order: shebang, `set -euo pipefail`,
  startup variables such as `ROOT_DIR`, one blank line, then helpers or sourcing
- use `ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` in top-level
  command files that need a repository root
- prefer `source_modules \\` with one module path per continued line when loading
  multiple shell modules
- declare `local` variables at the top of a function
- keep function bodies compact with no extra blank lines between adjacent statements
- keep exactly one blank line between top-level function definitions
- keep one blank line before the final `main "$@"` call in entrypoint scripts
- keep inline `shellcheck` suppressions immediately above the affected command

## project structure

- keep user-facing commands as executable files in the repository root
- keep shared shell modules in `utils/`
- keep Debian and iSH dependency installers in `3rdparty/`
- keep integration checks in `tests/`
- initialize runtime paths and the database through a shared profile module

## storage and data

- default `ARTS_HOME` to `$HOME/.config/arts`
- store the SQLite database and image files below `ARTS_HOME`
- name stored image files by their lowercase SHA-256 digest without an extension
- group stored image files under their artist directory
- validate imported images and record their MIME type with `file`
- treat SQLite constraints and transactions as the source of truth
- quote paths and SQL values defensively

## file ownership

- keep development context in this `AGENTS.md` file
- keep `CLAUDE.md` as a symbolic link to `AGENTS.md`
- do not use a `docs/` directory for project documentation
- do not modify `README.md` unless the user explicitly asks
- do not commit `README.md` unless the user explicitly asks

## naming and output

- keep user-facing log messages in lowercase unless the term is a standard acronym
- readability matters more than clever formatting
- prefer keeping lines within 88 characters when practical
- prefer short names when the meaning is already clear
- write diagnostics to stderr and machine-readable result values to stdout

## commit rules

- make commits in small, meaningful units
- prefer one logical change per commit
- follow google-style commit titles in lowercase
- prefer a title only, without a body, unless more detail is necessary
- use a prefix form such as `add: ...`, `fix: ...`, `refactor: ...`
- if a commit title feels broad, split the work into smaller commits
- amending the last commit is acceptable before push when the message needs correction

## decision rule

when choosing between abstraction and momentum, prefer the version that keeps today's
command flow readable with the fewest moving parts.
