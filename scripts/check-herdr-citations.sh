#!/bin/bash
# Fails if a `path:line` or `path:start-end` citation in docs/herdr.md names a file that is
# missing from the herdr checkout, or lines past its end. A bare `:N` follows the last path;
# `plugins.mdx` and other bare .mdx names live in herdr's docs folder.
# The content of each range still needs a reader.
# Usage: scripts/check-herdr-citations.sh <herdr checkout> [doc]   (default doc: docs/herdr.md)

herdr="${1:?usage: check-herdr-citations.sh <herdr checkout> [doc]}"
doc="${2:-docs/herdr.md}"

HERDR_ROOT="$herdr" perl -ne '
  BEGIN { $docs = "docs/next/website/src/content/docs" }
  my $doc_line = $.;  # $. follows whichever file was read last
  while (/`([^`]+)`/g) {
    my $span = $1;
    my ($path, $from, $to);
    if ($span =~ m{^((?:[\w.-]+/)*[\w.-]+\.(?:rs|mdx)):(\d+)(?:-(\d+))?$}) {
      ($path, $from, $to) = ($1, $2, $3);
      $path = "$docs/$path" if $path !~ m{/} && $path =~ /\.mdx$/;
      $last = $path;
    } elsif ($span =~ /^:(\d+)(?:-(\d+))?$/ && defined $last) {
      ($path, $from, $to) = ($last, $1, $2);
    } else { next }
    $to = $from unless defined $to;
    my $range = "$path:$from" . ($to != $from ? "-$to" : "");
    my $file = "$ENV{HERDR_ROOT}/$path";
    if (!-f $file) { print "$ARGV:$doc_line: $range: no such file in herdr\n"; $bad = 1; next }
    open my $fh, "<", $file or die "$file: $!";
    my @all = <$fh>; close $fh; my $lines = @all;  # reading into $_ would end the citation loop
    if ($to > $lines || $from > $to) {
      print "$ARGV:$doc_line: $range: file has $lines lines\n"; $bad = 1;
    }
  }
  END { $? = 1 if $bad }' "$doc"
