#!/bin/bash
# Fails if a `path:line` or `path:start-end` citation in docs/herdr.md names a file missing
# from herdr, or lines outside it. A bare `:N` follows the last path on the same line, and
# bare `.mdx` names live in herdr's docs folder. Prints the citation count on success.
# The content of each range still needs a reader.
#
# Usage: scripts/check-herdr-citations.sh [doc]   (default: docs/herdr.md)
# Fetches herdr at HERDR_COMMIT, or uses the tree in $HERDR_CHECKOUT when set.

# The herdr release docs/herdr.md describes. Bump both together, then rerun this script.
HERDR_VERSION=v0.9.5
HERDR_COMMIT=2ecf19a92fc3a7fff75b6ce3655ef04f4625ec01
HERDR_REPO=https://github.com/ogulcancelik/herdr.git

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
doc="${1:-$dir/../docs/herdr.md}"

if [ ! -r "$doc" ]; then
  echo "$doc: cannot read" >&2
  exit 1
fi
if ! grep -q "herdr $HERDR_VERSION" "$doc"; then
  echo "$doc must say which herdr it describes as \"herdr $HERDR_VERSION\", the release this script checks against" >&2
  exit 1
fi

herdr="$HERDR_CHECKOUT"
if [ -z "$herdr" ]; then
  herdr=$(mktemp -d) || exit 1
  trap '/bin/rm -rf "$herdr"' EXIT
  git -C "$herdr" init -q &&
    git -C "$herdr" fetch -q --depth 1 "$HERDR_REPO" "$HERDR_COMMIT" &&
    git -C "$herdr" checkout -q FETCH_HEAD || exit 1
fi
if [ ! -d "$herdr" ]; then
  echo "$herdr: no herdr checkout" >&2
  exit 1
fi

HERDR_ROOT="$herdr" HERDR_VERSION="$HERDR_VERSION" perl -ne '
  BEGIN { $docs = "docs/next/website/src/content/docs" }
  my $doc_line = $.;  # $. follows whichever file was read last
  my $last;           # a bare :N refers to a path earlier on the same line
  while (/`([^`]+)`/g) {
    my $span = $1;
    my ($path, $from, $to);
    if ($span =~ m{^((?:[\w.-]+/)*[\w.-]+\.(?:rs|mdx)):(\d+)(?:-(\d+))?$}) {
      ($path, $from, $to) = ($1, $2, $3);
      $path = "$docs/$path" if $path !~ m{/} && $path =~ /\.mdx$/;
      $last = $path;
    } elsif ($span =~ /^:(\d+)(?:-(\d+))?$/) {
      if (!defined $last) { print "$ARGV:$doc_line: `$span` has no path earlier on its line\n"; $bad = 1; next }
      ($path, $from, $to) = ($last, $1, $2);
    } else { next }
    $count++;
    $to = $from unless defined $to;
    my $range = "$path:$from" . ($to != $from ? "-$to" : "");
    my $file = "$ENV{HERDR_ROOT}/$path";
    if (!-f $file) { print "$ARGV:$doc_line: $range: no such file in herdr\n"; $bad = 1; next }
    open my $fh, "<", $file or die "$file: $!";
    my @all = <$fh>; close $fh; my $lines = @all;  # reading into $_ would end the citation loop
    if ($from < 1 || $to > $lines || $from > $to) {
      print "$ARGV:$doc_line: $range: file has lines 1-$lines\n"; $bad = 1;
    }
  }
  END {
    if (!$count) { print "$ARGV: no citations found\n"; $bad = 1 }
    if ($bad) { $? = 1 } else { print "$count citations checked against herdr $ENV{HERDR_VERSION}\n" }
  }' "$doc"
