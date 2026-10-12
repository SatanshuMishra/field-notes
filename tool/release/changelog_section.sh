#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: changelog_section.sh <version> <changelog file>" >&2
  exit 64
fi

version="$1"
changelog="$2"

if [[ ! -f "$changelog" ]]; then
  echo "::error::No changelog at $changelog." >&2
  exit 1
fi

status=0
CHANGELOG_HEADING="## [$version]" awk '
  BEGIN { heading = ENVIRON["CHANGELOG_HEADING"] }
  {
    sub(/\r$/, "")
    trimmed = $0
    sub(/[ \t]+$/, "", trimmed)
  }
  found && /^## / { exit }
  found { lines[++count] = $0; next }
  trimmed == heading || index(trimmed, heading " - ") == 1 { found = 1 }
  END {
    if (!found) exit 3
    first = 1
    while (first <= count && lines[first] ~ /^[ \t]*$/) first++
    last = count
    while (last >= first && lines[last] ~ /^[ \t]*$/) last--
    for (at = first; at <= last; at++) print lines[at]
  }
' "$changelog" || status=$?

if [[ $status -eq 3 ]]; then
  echo "::error::CHANGELOG.md has no section for $version." >&2
  exit 1
fi
exit "$status"
