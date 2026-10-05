#!/usr/bin/env bash
set -u
set -o pipefail

config_dir="${FN_CONFIG_DIR:-/home/satanshumishra/.config/field-notes}"
nas_hosts="${FN_NAS_HOSTS:-10.0.0.246 10.0.0.247}"
module="${FN_DRILL_MODULE:-field-notes-backup}"
drill_root="${FN_DRILL_ROOT:-/var/tmp/field-notes-drill}"
image="${FN_RELAY_IMAGE:-ghcr.io/satanshumishra/field-notes-relay:main}"
health_attempts="${FN_HEALTH_ATTEMPTS:-30}"
health_delay="${FN_HEALTH_DELAY:-2}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
alert="$script_dir/alert.sh"
password_file="$config_dir/nas-rsync.pass"
heartbeat_file="$config_dir/heartbeat.env"
ping_url=""
scratch=""
container=""

if [ -r "$heartbeat_file" ]; then
  . "$heartbeat_file"
  ping_url="${FN_DRILL_PING_URL:-}"
fi

log() {
  printf '%s restore-drill: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

ping_heartbeat() {
  if [ -z "$ping_url" ]; then
    return 0
  fi
  curl -fsS -m 10 --retry 3 -o /dev/null "$ping_url$1" || log "heartbeat $1 did not answer"
}

cleanup() {
  if [ -n "$container" ]; then
    docker rm --force "$container" >/dev/null 2>&1 || true
  fi
  if [ -n "$scratch" ]; then
    rm -rf "$scratch"
  fi
}
trap cleanup EXIT

fail() {
  log "failed: $1"
  ping_heartbeat /fail
  "$alert" "restore drill failed" "The monthly restore drill failed. Failed step: $1."
  exit 1
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

private_root() {
  [ -n "$(find "$drill_root" -maxdepth 0 -type d -user "$(id -u)" -perm 0700 2>/dev/null)" ]
}

pull_copy() {
  local host
  for host in $nas_hosts; do
    if rsync -a --no-links \
      --contimeout=30 \
      --timeout=600 \
      --password-file="$password_file" \
      --exclude='#snapshot/' \
      --exclude='@eaDir/' \
      "rsync://fn-backup@$host/$module/" "$scratch/"; then
      return 0
    fi
    log "rsync from $host failed"
  done
  return 1
}

ping_heartbeat /start
found_rsync="$(rsync_version)"
if ! rsync_is_current "$found_rsync"; then
  fail "check rsync (found ${found_rsync:-an unknown version}, need 3.4.0 or newer)"
fi
if [ ! -e "$drill_root" ] && [ ! -L "$drill_root" ]; then
  mkdir -m 0700 "$drill_root" || fail "create the scratch root $drill_root"
fi
if ! private_root; then
  fail "check the scratch root $drill_root, which must be a folder owned by $(id -un) with mode 0700"
fi
scratch="$(mktemp -d "$drill_root/drill.XXXXXX")" || fail "create the scratch folder"
pull_copy || fail "pull the latest copy from the NAS"

latest="$(ls -1 "$scratch/backup" 2>/dev/null | grep -E '^relay-[0-9]{4}-[0-9]{2}-[0-9]{2}\.sqlite3$' | sort | tail -n 1)"
if [ -z "$latest" ]; then
  fail "find a database copy"
fi
copy="$scratch/backup/$latest"
mkdir -p "$scratch/media" || fail "prepare the scratch media folder"

docker run --rm --network none --user 1000:1000 \
  --volume "$scratch:$scratch" \
  "$image" verify-copy --db "$copy" --media "$scratch/media" --manifest "$copy.manifest" \
  || fail "verify-copy of $latest"

mkdir -p "$scratch/data" && cp "$copy" "$scratch/data/relay.sqlite3" \
  || fail "prepare the scratch relay"

container="fn-restore-drill-$$"
docker run --detach --name "$container" --network none \
  --user 1000:1000 --read-only --tmpfs /tmp \
  --cap-drop ALL --security-opt no-new-privileges:true \
  --volume "$scratch:$scratch" \
  --env "RELAY_DATABASE=$scratch/data/relay.sqlite3" \
  --env "RELAY_MEDIA_DIR=$scratch/media" \
  "$image" >/dev/null \
  || fail "start the scratch relay"

healthy="no"
attempt=0
while [ "$attempt" -lt "$health_attempts" ]; do
  attempt=$((attempt + 1))
  status="$(docker exec "$container" curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/health 2>/dev/null || true)"
  if [ "$status" = "200" ]; then
    healthy="yes"
    break
  fi
  sleep "$health_delay"
done
if [ "$healthy" != "yes" ]; then
  fail "health check of the scratch relay"
fi

ping_heartbeat ""
log "passed with $latest"
exit 0
