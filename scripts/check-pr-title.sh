#!/bin/bash
# Fails unless the PR title is a Conventional Commit; squash merges use it as the commit on main.
# Usage: scripts/check-pr-title.sh "<title>"

pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9-]+\))?!?: [^[:space:]].*'
if [[ ! "$1" =~ $pattern ]]; then
  echo "PR title must follow https://www.conventionalcommits.org/, e.g. 'fix(net): …'. Got: $1" >&2
  exit 1
fi
