#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: make_dmg.sh <path to Field Notes.app> <output .dmg>" >&2
  exit 64
fi

app="$1"
output="$2"

if [[ ! -d "$app" ]]; then
  echo "No app bundle at $app" >&2
  exit 1
fi

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

ditto "$app" "$stage/$(basename "$app")"
ln -s /Applications "$stage/Applications"

for attempt in 1 2 3; do
  if hdiutil create -volname 'Field Notes' -srcfolder "$stage" -ov -format UDZO "$output"; then
    exit 0
  fi
  echo "hdiutil create failed on attempt $attempt" >&2
  sleep 5
done

exit 1
