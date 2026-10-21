#!/bin/bash
# Prints the four segments joined the way herdr shows them, plus the width they take.
# Usage: bin/preview.sh [--graph] [--text]
# Flags apply to every segment. Takes about 2 s, because the CPU segment samples top.
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
printf '%s' "$bar" | perl -CSD -ne 'printf "%d characters of the tab row; tabs get the rest\n", length'
