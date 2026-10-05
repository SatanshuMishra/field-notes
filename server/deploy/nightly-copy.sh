#!/usr/bin/env bash
set -u
set -o pipefail

config_dir="${FN_CONFIG_DIR:-/home/satanshumishra/.config/field-notes}"
relay_root="${FN_RELAY_ROOT:-/srv/field-notes-relay}"
test_relay_root="${FN_TEST_RELAY_ROOT:-/srv/field-notes-relay-test}"
nas_hosts="${FN_NAS_HOSTS:-10.0.0.246 10.0.0.247}"
retry_delay="${FN_RETRY_DELAY:-600}"
keep_snapshots="${FN_KEEP_SNAPSHOTS:-7}"
relay_binary="${FN_RELAY_BINARY:-/app/bin/relay}"
live_database="relay.sqlite3"
script_dir="$(cd "$(dirname "$0")" && pwd)"
alert="$script_dir/alert.sh"
password_file="$config_dir/nas-rsync.pass"
heartbeat_file="$config_dir/heartbeat.env"
ping_url=""
failed_steps=""

if [ -r "$heartbeat_file" ]; then
  . "$heartbeat_file"
  ping_url="${FN_NIGHTLY_PING_URL:-}"
fi

log() {
  printf '%s nightly-copy: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

ping_heartbeat() {
  if [ -z "$ping_url" ]; then
    return 0
  fi
  curl -fsS -m 10 --retry 3 -o /dev/null "$ping_url$1" || log "heartbeat $1 did not answer"
}

fail_step() {
  if [ -n "$failed_steps" ]; then
    failed_steps="$failed_steps; $1"
  else
    failed_steps="$1"
  fi
  log "failed: $1"
}

rsync_version() {
  rsync --version 2>/dev/null \
    | sed -n '1s/^rsync[[:space:]]\{1,\}version[[:space:]]\{1,\}v\{0,1\}\([0-9][0-9.]*\).*/\1/p'
}

rsync_is_current() {
  local major="${1%%.*}"
  local minor="${1#*.}"
  minor="${minor%%.*}"
  case "$major.$minor" in
    *[!0-9.]* | .* | *.) return 1 ;;
  esac
  [ "$major" -gt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -ge 4 ]; }
}

container_for() {
  docker ps --quiet --filter "label=com.docker.compose.service=$1" | head -n 1
}

prune_snapshots() {
  local backup_dir="$1"
  ls -1 "$backup_dir" \
    | grep -E '^relay-[0-9]{4}-[0-9]{2}-[0-9]{2}\.sqlite3$' \
    | sort -r \
    | tail -n "+$((keep_snapshots + 1))" \
    | while read -r old; do
        rm -f "$backup_dir/$old" "$backup_dir/$old.manifest"
      done
}

sync_to_nas() {
  local root="$1"
  local module="$2"
  local host
  for host in $nas_hosts; do
    if rsync -a --delete \
      --contimeout=30 \
      --timeout=600 \
      --password-file="$password_file" \
      --exclude='#snapshot/' \
      --exclude='@eaDir/' \
      --exclude='.uploads/' \
      --exclude="$live_database" \
      --exclude="$live_database-wal" \
      --exclude="$live_database-shm" \
      --exclude='*-wal' \
      --exclude='*-shm' \
      "$root/backup" "$root/media" \
      "rsync://fn-backup@$host/$module/"; then
      log "copied $root to $host/$module"
      return 0
    fi
    log "rsync to $host failed"
  done
  return 1
}

copy_relay() {
  local service="$1"
  local root="$2"
  local module="$3"
  local container
  local target
  container="$(container_for "$service")"
  if [ -z "$container" ]; then
    fail_step "find the $service container"
    return 1
  fi
  target="$root/backup/relay-$(date -u +%Y-%m-%d).sqlite3"
  if ! mkdir -p "$root/backup" "$root/media"; then
    fail_step "prepare the $service backup folder"
    return 1
  fi
  rm -f "$target" "$target.manifest"
  if ! docker exec "$container" "$relay_binary" snapshot-db --to "$target"; then
    fail_step "snapshot of $service"
    return 1
  fi
  prune_snapshots "$root/backup"
  if ! sync_to_nas "$root" "$module"; then
    fail_step "copy of $service to the NAS"
    return 1
  fi
  return 0
}

copy_everything() {
  failed_steps=""
  copy_relay fn-relay "$relay_root" field-notes-backup
  copy_relay fn-relay-test "$test_relay_root" field-notes-backup-test
  [ -z "$failed_steps" ]
}

ping_heartbeat /start
found_rsync="$(rsync_version)"
if ! rsync_is_current "$found_rsync"; then
  log "rsync ${found_rsync:-of an unknown version} is older than 3.4.0"
  ping_heartbeat /fail
  "$alert" "nightly copy failed" "The nightly copy did not run. Failed step: check rsync (found ${found_rsync:-an unknown version}, need 3.4.0 or newer)."
  exit 1
fi
if copy_everything; then
  ping_heartbeat ""
  log "finished"
  exit 0
fi
log "retrying in $retry_delay seconds"
sleep "$retry_delay"
if copy_everything; then
  ping_heartbeat ""
  log "finished on the second try"
  exit 0
fi
ping_heartbeat /fail
"$alert" "nightly copy failed" "The nightly copy to the NAS failed twice. Failed step: $failed_steps."
exit 1
