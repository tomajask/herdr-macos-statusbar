#!/usr/bin/env bats
# The scripts CI runs, tested on crafted inputs.

SCRIPTS="$BATS_TEST_DIRNAME/../scripts"

setup() {
  cd "$BATS_TEST_TMPDIR" || return 1
}

# --- check-markdown-glyphs.sh ---------------------------------------------

@test "markdown: clean files pass" {
  printf 'BAT 66%% │ CPU 13%% ⚡\n' > clean.md
  run "$SCRIPTS/check-markdown-glyphs.sh" clean.md
  [ "$status" -eq 0 ]
}

@test "markdown: a plane-15 Nerd Font glyph fails with file and line" {
  printf 'ok\nx \xf3\xb0\xbb\xa0\n' > icon.md
  run "$SCRIPTS/check-markdown-glyphs.sh" icon.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"icon.md:2"* ]]
}

@test "markdown: a BMP private-use glyph fails" {
  printf 'x \xef\x8b\x9b\n' > bmp.md
  run "$SCRIPTS/check-markdown-glyphs.sh" bmp.md
  [ "$status" -eq 1 ]
}

@test "markdown: every kind of invalid UTF-8 fails" {
  for bytes in '\xff' '\x80' '\xc3'; do
    printf "bad $bytes\n" > bad.md
    run "$SCRIPTS/check-markdown-glyphs.sh" bad.md
    [ "$status" -eq 1 ]
  done
}

@test "markdown: a later file is still checked after a clean one, and paths may have spaces" {
  printf 'clean\n' > a.md
  printf 'x \xf3\xb0\xbb\xa0\n' > 'with space.md'
  run "$SCRIPTS/check-markdown-glyphs.sh" a.md 'with space.md'
  [ "$status" -eq 1 ]
  [[ "$output" == *"with space.md:1"* ]]
}

# --- check-pr-title.sh -------------------------------------------------------

@test "pr title: Conventional Commits pass" {
  for title in 'ci: run tests' 'feat(net)!: drop kB/s' 'fix(batt): hide 0:00' 'docs: add AGENTS.md'; do
    run "$SCRIPTS/check-pr-title.sh" "$title"
    [ "$status" -eq 0 ]
  done
}

@test "pr title: anything else fails" {
  for title in 'README: show preview' 'Add CI: x' 'feat:   ' 'feat: ' 'feat:x' 'Feat: x' 'feat(Net): x' ''; do
    run "$SCRIPTS/check-pr-title.sh" "$title"
    [ "$status" -eq 1 ]
  done
}

# --- check-herdr-citations.sh -------------------------------------------------

herdr_tree() {
  mkdir -p herdr/src/app herdr/docs/next/website/src/content/docs
  seq 1 50 > herdr/src/app/status.rs
  seq 1 20 > herdr/docs/next/website/src/content/docs/plugins.mdx
}

@test "citations: paths and line ranges that exist pass, including :N follow-ups and short .mdx names" {
  herdr_tree
  printf -- '- runs (`src/app/status.rs:3-9`, `:40`, `:41-50`)\n- docs (`plugins.mdx:20`)\n' > doc.md
  run "$SCRIPTS/check-herdr-citations.sh" herdr doc.md
  [ "$status" -eq 0 ]
}

@test "citations: a missing file fails" {
  herdr_tree
  printf -- '- (`src/app/api/status.rs:3`)\n' > doc.md
  run "$SCRIPTS/check-herdr-citations.sh" herdr doc.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"src/app/api/status.rs"* ]]
}

@test "citations: a line range past the end of the file fails" {
  herdr_tree
  printf -- '- (`src/app/status.rs:3`, `:45-51`)\n' > doc.md
  run "$SCRIPTS/check-herdr-citations.sh" herdr doc.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"src/app/status.rs:45-51"* ]]
}
