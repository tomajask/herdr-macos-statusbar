# herdr-macos-statusbar

A herdr plugin that adds macOS status segments to the tab bar. It runs on the system `/bin/bash` 3.2 and BSD tools, with nothing else to install.

## Map

- `bin/statusbar.sh`: one `render_<segment>` per segment. Each reads raw tool output on stdin, so tests feed it fixtures. `main` collects the live output.
- `bin/configure.sh`: `config_add` and `config_remove` are pure (`config.toml` text in on stdin, out on stdout). `main` does the backup, atomic write, reload and rollback.
- `test/*.bats` with `test/fixtures/`. `test/fixtures/README.md` says which samples are real captures.
- `docs/herdr.md`: how herdr runs status commands and plugins. Read it before changing output format, intervals, install paths or `configure`.
- `bin/preview.sh [--graph] [--text]`: prints the bar the way herdr joins it, with its length.

## Checks

Run `bats test/` and `shellcheck bin/*.sh`. The CI job `checks` is required on `main`. It also asserts that tests run on bash 3.2, validates `herdr-plugin.toml`, and checks that Markdown has no Nerd Font glyphs and that the PR title is a Conventional Commit.

## Gotchas

- **bash 3.2 and BSD userland:**
  - No `declare -A`, no `mapfile`, no `${x,,}`.
  - BSD awk takes no newlines in `-v` values, so pass them through `ENVIRON`.
  - `sed -i ''`.
- **Nerd Font icons:** write them as escapes, e.g. `perl -CSD -pi -e 's/…/\x{F0EE0}/'`. Use the plane-15 `nf-md-*` range: a BMP private-use glyph (U+E000–F8FF) got lost once when a tool rewrote the file. Markdown uses text only, because GitHub shows these glyphs as boxes.

## Contributing

- Every change goes on a branch and through a PR, and `main` accepts only squash merges.
- Commits and PR titles follow [Conventional Commits](https://www.conventionalcommits.org/), because the squash commit takes the PR title. Review comments follow [Conventional Comments](https://conventionalcomments.org/).
- Commits and PR descriptions carry only the change itself. No `Co-Authored-By` trailers and no "generated with" footers.
