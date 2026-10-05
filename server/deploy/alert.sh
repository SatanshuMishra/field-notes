#!/usr/bin/env bash
set -u

recipient="satanshumishra@outlook.com"
subject="${1:-${SMARTD_SUBJECT:-Field Notes server alert}}"
body="${2:-${SMARTD_FULLMESSAGE:-${SMARTD_MESSAGE:-No details were given.}}}"
host="$(hostname 2>/dev/null || echo server)"
stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
  printf 'To: %s\n' "$recipient"
  printf 'Subject: [Field Notes] %s (%s)\n' "$subject" "$host"
  printf 'Content-Type: text/plain; charset=UTF-8\n'
  printf '\n'
  printf '%s\n' "$body"
  printf '\n'
  printf 'Host: %s\n' "$host"
  printf 'Time: %s\n' "$stamp"
} | msmtp -t
