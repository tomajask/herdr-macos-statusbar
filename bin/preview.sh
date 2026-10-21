#!/bin/bash
# Prints the four segments joined the way herdr shows them, plus the width they take.
# Usage: bin/preview.sh [--graph] [--text]
# Flags apply to every segment. Takes about 2 s, because the CPU segment samples top.
# Uses the separator configure sets; a user's own tab_bar_right_separator would differ.
set -o pipefail

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=bin/configure.sh
source "$dir/configure.sh" # SEGMENTS and SEPARATOR, as configure writes them

bar=""
for segment in $SEGMENTS; do
  # herdr shows the last line and hides an entry that exits non-zero or prints nothing.
  text=$("$dir/statusbar.sh" "$segment" "$@" | tail -n 1) || continue
  [ -n "$text" ] || continue
  bar="${bar:+$bar$SEPARATOR}$text"
done

echo "$bar"
printf '%s' "$bar" | perl -CSD -ne 'printf "%d code points of the tab row (wide glyphs such as the bolt take 2 columns); tabs get the rest\n", length'
