# herdr-macos-statusbar

A herdr plugin: macOS status segments for the tab bar. It targets the system `/bin/bash` 3.2 and BSD tools.

- `bin/statusbar.sh`: each `render_<segment>` reads raw tool output on stdin, and `test/statusbar.bats` feeds them `test/fixtures/` (whose README says which samples are real captures).
- `bin/configure.sh`: `config_add` and `config_remove` are pure, `config.toml` text in on stdin and out on stdout. `main` does the backup, the write, the reload and the rollback.
- `docs/herdr.md`: how herdr runs status commands and plugins. Read it before changing output, intervals, install paths or `configure`.
- `bin/preview.sh [--graph] [--text]` prints the bar the way herdr joins it.
- `scripts/`: the checks CI runs, each tested in `test/checks.bats`. Change a check there, test first, rather than in the workflow YAML.
- **bash 3.2 and BSD:** use indexed arrays and `while read`, and write `sed -i ''`. Pass multi-line awk input through `ENVIRON`, because BSD awk rejects newlines in `-v` values.
- **Nerd Font icons:** write them as escapes from the plane-15 `nf-md-*` range, e.g. `perl -CSD -pi -e 's/…/\x{F0EE0}/'`. A BMP private-use glyph (U+E000–F8FF) once vanished when a tool rewrote the file; plane-15 glyphs came through intact.
- **Commits and PR titles:** [Conventional Commits](https://www.conventionalcommits.org/). **Review comments:** [Conventional Comments](https://conventionalcomments.org/).
- **Commit messages and PR descriptions:** they describe only the change, with no AI co-author trailers or generated-by footers.
