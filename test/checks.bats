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
    printf 'bad %b\n' "$bytes" > bad.md
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

@test "markdown: a missing file fails" {
  printf 'clean\n' > a.md
  run "$SCRIPTS/check-markdown-glyphs.sh" a.md gone.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"gone.md"* ]]
}

@test "markdown: clean files report how many were checked" {
  printf 'clean\n' > a.md
  printf 'clean\n' > b.md
  run "$SCRIPTS/check-markdown-glyphs.sh" a.md b.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 Markdown files checked"* ]]
}

@test "markdown: with no arguments it checks the whole repo, even from a subdirectory" {
  git init -q repo
  mkdir repo/sub
  printf 'x \xf3\xb0\xbb\xa0\n' > repo/README.md
  printf 'clean\n' > repo/sub/notes.md
  git -C repo add README.md sub/notes.md
  cd repo/sub
  run "$SCRIPTS/check-markdown-glyphs.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"README.md:1"* ]]
}

@test "markdown: with no arguments outside a git repo it fails" {
  mkdir not-a-repo
  cd not-a-repo
  GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run "$SCRIPTS/check-markdown-glyphs.sh"
  [ "$status" -eq 1 ]
}

# --- check-pr-title.sh -------------------------------------------------------

@test "pr title: Conventional Commits pass and say so" {
  for title in 'ci: run tests' 'feat(net)!: drop kB/s' 'fix(batt): hide 0:00' 'docs: add AGENTS.md'; do
    run "$SCRIPTS/check-pr-title.sh" "$title"
    [ "$status" -eq 0 ]
    [[ "$output" == "ok: $title" ]]
  done
}

@test "pr title: anything else fails" {
  for title in 'README: show preview' 'Add CI: x' 'feat:   ' 'feat: ' 'feat:x' 'Feat: x' 'feat(Net): x' ''; do
    run "$SCRIPTS/check-pr-title.sh" "$title"
    [ "$status" -eq 1 ]
  done
}

# --- check-herdr-citations.sh -------------------------------------------------
# HERDR_CHECKOUT points the script at a local tree, so these tests need no network.

herdr_tree() {
  mkdir -p herdr/src/app herdr/docs/next/website/src/content/docs
  seq 1 50 > herdr/src/app/status.rs
  seq 1 20 > herdr/docs/next/website/src/content/docs/plugins.mdx
}

# $1: citation lines. The first line names the herdr version the script pins.
herdr_doc() {
  printf 'Facts read from the herdr v0.9.5 source.\n%s\n' "$1" > doc.md
}

check_citations() {
  HERDR_CHECKOUT=herdr run "$SCRIPTS/check-herdr-citations.sh" "$@"
}

@test "citations: paths and line ranges that exist pass, including :N follow-ups and short .mdx names" {
  herdr_tree
  herdr_doc $'- runs (`src/app/status.rs:3-9`, `:40`, `:41-50`)\n- docs (`plugins.mdx:20`)'
  check_citations doc.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"4 citations checked"* ]]
}

@test "citations: a missing file fails" {
  herdr_tree
  herdr_doc '- (`src/app/api/status.rs:3`)'
  check_citations doc.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"src/app/api/status.rs"* ]]
}

@test "citations: a line range past the end of the file fails" {
  herdr_tree
  herdr_doc '- (`src/app/status.rs:3`, `:45-51`)'
  check_citations doc.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"src/app/status.rs:45-51"* ]]
}

@test "citations: line 0 fails" {
  herdr_tree
  herdr_doc '- (`src/app/status.rs:0`)'
  check_citations doc.md
  [ "$status" -eq 1 ]
}

@test "citations: a :N with no path earlier on its line fails" {
  herdr_tree
  herdr_doc $'- (`src/app/status.rs:3`)\n- (`:40`)'
  check_citations doc.md
  [ "$status" -eq 1 ]
  [[ "$output" == *":40"* ]]
}

@test "citations: a doc it cannot read fails" {
  herdr_tree
  check_citations gone.md
  [ "$status" -eq 1 ]
}

@test "citations: a doc with no citations fails, so a renamed or emptied doc can't pass" {
  herdr_tree
  herdr_doc 'no citations here'
  check_citations doc.md
  [ "$status" -eq 1 ]
}

@test "citations: a doc describing another herdr version fails" {
  herdr_tree
  printf 'Facts read from the herdr v0.9.4 source.\n- (`src/app/status.rs:3`)\n' > doc.md
  check_citations doc.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"v0.9.5"* ]]
}
