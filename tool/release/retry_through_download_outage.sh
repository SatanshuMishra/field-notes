#!/usr/bin/env bash
set -u

seconds_between_attempts=60
server_failure='Server returned HTTP response code: 5[0-9][0-9]|Received status code 5[0-9][0-9]'
attempt_log="$(mktemp)"
trap 'rm -f "$attempt_log"' EXIT

while true; do
  "$@" 2>&1 | tee "$attempt_log"
  status="${PIPESTATUS[0]}"
  if [[ "$status" -eq 0 ]]; then
    exit 0
  fi
  if ! grep -Eq "$server_failure" "$attempt_log"; then
    exit "$status"
  fi
  echo "::warning::A download failed because the server had a problem. Trying the build again in $seconds_between_attempts seconds."
  sleep "$seconds_between_attempts"
done
