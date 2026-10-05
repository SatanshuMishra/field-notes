#!/usr/bin/env bash
set -u
set -o pipefail

config_dir="${FN_CONFIG_DIR:-/home/satanshumishra/.config/field-notes}"
relay_root="${FN_RELAY_ROOT:-/srv/field-notes-relay}"
test_relay_root="${FN_TEST_RELAY_ROOT:-/srv/field-notes-relay-test}"
retry_delay="${FN_RETRY_DELAY:-600}"
keep_snapshots="${FN_KEEP_SNAPSHOTS:-7}"
relay_binary="${FN_RELAY_BINARY:-/app/bin/relay}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
alert="$script_dir/alert.sh"
heartbeat_file="$config_dir/heartbeat.env"
ping_url=""
failed_steps=""

. "$script_dir/nas-rsync.sh"

log() {
  printf '%s nightly-copy: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

refuse_config() {
  log "refused: $1"
  "$alert" "nightly copy failed" "The nightly copy did not run and connected to nothing. Failed step: check $1."
  exit 1
}

config_problem="$(nas_private_file_problem "$heartbeat_file")"
if [ -n "$config_problem" ]; then
  refuse_config "$config_problem"
fi
if [ -r "$heartbeat_file" ]; then
  . "$heartbeat_file"
  ping_url="${FN_NIGHTLY_PING_URL:-}"
fi

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
  local share="$2"
  local host
  for host in $NAS_HOSTS; do
    nas_rsync_args push "$share" "$host" "$(nas_transport "push-$share")" \
      "$root/backup" "$root/media"
    if rsync "${nas_args[@]}"; then
      log "copied $root to $host:$NAS_VOLUME/$share"
      return 0
    fi
    log "rsync to $host failed"
  done
  return 1
}

copy_relay() {
  local service="$1"
  local root="$2"
  local share="$3"
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
  if ! sync_to_nas "$root" "$share"; then
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
config_problem="$(nas_private_file_problem "$nas_env_file")"
if [ -n "$config_problem" ]; then
  ping_heartbeat /fail
  refuse_config "$config_problem"
fi
nas_load_config
nas_problem="$(nas_ready_problem push-field-notes-backup push-field-notes-backup-test)"
if [ -n "$nas_problem" ]; then
  log "the NAS connection is not ready: $nas_problem"
  ping_heartbeat /fail
  "$alert" "nightly copy failed" "The nightly copy did not run and connected to nothing. Failed step: check the NAS connection ($nas_problem)."
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
