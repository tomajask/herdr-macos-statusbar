#!/bin/bash
# Prints the four segments joined the way herdr shows them, plus the width they take.
# Usage: bin/preview.sh [--graph] [--text]
# Flags apply to every segment. Takes about 2 s, because the CPU segment samples top.

set -o pipefail

SEPARATOR=" │ " # what configure sets as tab_bar_right_separator

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bar=""
for segment in batt cpu mem net; do
  # herdr shows the last line and hides an entry that exits non-zero or prints nothing.
  text=$("$dir/statusbar.sh" "$segment" "$@" | tail -n 1) || continue
  [ -n "$text" ] || continue
  bar="${bar:+$bar$SEPARATOR}$text"
done

echo "$bar"
printf '%s' "$bar" | perl -CSD -ne 'printf "%d characters (herdr caps each entry at 80)\n", length'
