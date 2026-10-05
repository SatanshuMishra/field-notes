#!/usr/bin/env bash
set -u
set -o pipefail

config_dir="${FN_CONFIG_DIR:-/home/satanshumishra/.config/field-notes}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
staged=""

. "$script_dir/nas-rsync.sh"

usage() {
  cat >&2 <<USAGE
Usage:
  $0 keys              create any missing NAS key in $nas_keys_dir
  $0 authorized        print the authorized_keys lines for fn-backup on the NAS
  $0 pin-host <file>   pin the NAS host key from the file saved from DSM
USAGE
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [ -n "$staged" ]; then
    rm -f "$staged"
  fi
}
trap cleanup EXIT

write_private() {
  local target="$1"
  local content="$2"
  staged="$(mktemp "$target.XXXXXX")" || die "Could not stage $target."
  printf '%s' "$content" > "$staged" || die "Could not write $target."
  chmod 0600 "$staged" || die "Could not set the mode of $target."
  mv -f "$staged" "$target" || die "Could not write $target."
  staged=""
}

make_keys() {
  local name
  local key
  install -d -m 0700 "$nas_keys_dir" || die "Could not create $nas_keys_dir."
  chmod 0700 "$nas_keys_dir" || die "Could not set the mode of $nas_keys_dir."
  for name in $nas_key_names; do
    key="$nas_keys_dir/$name"
    if [ -e "$key" ]; then
      chmod 0600 "$key" || die "Could not set the mode of $key."
      if [ ! -s "$key.pub" ]; then
        ssh-keygen -y -f "$key" > "$key.pub" || die "Could not read the public half of $key."
      fi
      printf 'kept %s\n' "$name"
    elif [ -e "$key.pub" ]; then
      die "$key.pub exists without its private key. Move it away, then run this again."
    else
      ssh-keygen -q -t ed25519 -N '' -C "fn-backup-$name" -f "$key" </dev/null \
        || die "Could not create $key."
      chmod 0600 "$key" || die "Could not set the mode of $key."
      printf 'created %s\n' "$name"
    fi
  done
}

print_authorized() {
  local name
  local key
  local line
  local command
  local public
  local pinned=""
  local authorized=""
  for name in $nas_key_names; do
    key="$nas_keys_dir/$name"
    [ -r "$key.pub" ] || die "$key.pub is missing. Run $0 keys first."
    public="$(awk 'NR == 1 && $1 == "ssh-ed25519" { print $1 " " $2 }' "$key.pub")"
    [ -n "$public" ] || die "$key.pub does not hold an ed25519 key."
    line="$(nas_pinned_line "$name")" || die "rsync did not show the command it sends for $name. Check that rsync 3.4.0 or newer is installed."
    command="${line#"$name "}"
    pinned="$pinned$line
"
    authorized="${authorized}restrict,from=\"$NAS_ALLOW_FROM\",command=\"$command\" $public fn-backup-$name
"
  done
  write_private "$nas_pinned_file" "$pinned"
  printf '%s' "$authorized"
}

pin_host() {
  local source="$1"
  local key
  local fingerprint
  local hosts=""
  local host
  local probe
  [ -r "$source" ] || die "Cannot read $source."
  key="$(tr -d '\r' < "$source" | awk '$1 == "ssh-ed25519" && $2 ~ /^[A-Za-z0-9+\/]+=*$/ { print $1 " " $2; exit }')"
  [ -n "$key" ] || die "$source holds no ssh-ed25519 host key line."
  probe="$(mktemp "${TMPDIR:-/tmp}/fn-nas-host.XXXXXX")" || die "Could not stage the host key."
  printf '%s\n' "$key" > "$probe"
  fingerprint="$(ssh-keygen -l -f "$probe")"
  rm -f "$probe"
  [ -n "$fingerprint" ] || die "ssh-keygen could not read the host key in $source."
  for host in $NAS_HOSTS; do
    hosts="$hosts${hosts:+,}[$host]:$NAS_SSH_PORT"
    if [ "$NAS_SSH_PORT" = "22" ]; then
      hosts="$hosts,$host"
    fi
  done
  write_private "$nas_known_hosts" "$hosts $key
"
  printf 'NAS host key: %s\n' "$fingerprint"
  printf 'Compare it with the ED25519 fingerprint DSM printed. If they differ, delete %s and stop.\n' "$nas_known_hosts"
  printf 'Pinned for %s in %s\n' "$NAS_HOSTS" "$nas_known_hosts"
}

if [ "$(id -u)" -eq 0 ]; then
  die "Run this as satanshumishra, not with sudo."
fi

nas_load_config
problem="$(nas_config_problem)"
[ -z "$problem" ] || die "Cannot continue: $problem."

case "${1:-}" in
  keys)
    [ "$#" -eq 1 ] || { usage; exit 64; }
    make_keys
    ;;
  authorized)
    [ "$#" -eq 1 ] || { usage; exit 64; }
    print_authorized
    ;;
  pin-host)
    [ "$#" -eq 2 ] || { usage; exit 64; }
    pin_host "$2"
    ;;
  *)
    usage
    exit 64
    ;;
esac
