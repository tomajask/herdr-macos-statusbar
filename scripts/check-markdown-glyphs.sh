#!/bin/bash
# Fails if a Markdown file has a Nerd Font glyph, which GitHub shows as an empty box,
# or invalid UTF-8. Prints file:line for each.
# Usage: scripts/check-markdown-glyphs.sh [file.md ...]   (default: every tracked *.md)

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/glyphs.sh
source "$dir/glyphs.sh"

if [ $# -eq 0 ]; then
  git ls-files -z '*.md' | xargs -0 "$0" || exit 1
  exit 0
fi

perl -MEncode -ne '
  BEGIN { $glyph = qr/$ENV{NERD_FONT_GLYPH}/ }
  my $text = eval { Encode::decode("UTF-8", $_, Encode::FB_CROAK) };
  if (!defined $text) { print "$ARGV:$.: invalid UTF-8\n"; $bad = 1 }
  elsif ($text =~ $glyph) { print "$ARGV:$.: Nerd Font glyph\n"; $bad = 1 }
  close ARGV if eof;
  END { $? = 1 if $bad }' "$@"
