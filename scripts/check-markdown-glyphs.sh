#!/bin/bash
# Fails if a Markdown file has a Nerd Font glyph, which GitHub shows as an empty box,
# or invalid UTF-8, or can't be read. Prints file:line for each, and the file count on success.
# Usage: scripts/check-markdown-glyphs.sh [file.md ...]   (default: every tracked *.md in the repo)

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/glyphs.sh
source "$dir/glyphs.sh"

files=()
if [ $# -eq 0 ]; then
  root=$(git rev-parse --show-toplevel) || exit 1
  cd "$root" || exit 1
  while IFS= read -r -d '' file; do files+=("$file"); done < <(git ls-files -z '*.md')
  if [ ${#files[@]} -eq 0 ]; then
    echo "no tracked Markdown files in $root" >&2
    exit 1
  fi
else
  files=("$@")
fi

missing=0
for file in "${files[@]}"; do
  if [ ! -r "$file" ]; then
    echo "$file: cannot read" >&2
    missing=1
  fi
done
[ "$missing" = 0 ] || exit 1

perl -MEncode -ne '
  BEGIN { $glyph = qr/$ENV{NERD_FONT_GLYPH}/ }
  my $text = eval { Encode::decode("UTF-8", $_, Encode::FB_CROAK) };
  if (!defined $text) { print "$ARGV:$.: invalid UTF-8\n"; $bad = 1 }
  elsif ($text =~ $glyph) { print "$ARGV:$.: Nerd Font glyph\n"; $bad = 1 }
  if (eof) { $files++; close ARGV }
  END {
    if ($bad) { $? = 1 } else { print "$files Markdown files checked\n" }
  }' "${files[@]}"
