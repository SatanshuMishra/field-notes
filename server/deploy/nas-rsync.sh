nas_env_file="$config_dir/nas.env"
nas_keys_dir="$config_dir/nas-keys"
nas_known_hosts="$config_dir/nas_known_hosts"
nas_pinned_file="$nas_keys_dir/pinned"
nas_key_names="push-field-notes-backup push-field-notes-backup-test pull-field-notes-backup pull-field-notes-backup-test"
nas_shares="field-notes-backup field-notes-backup-test"
nas_args=()

NAS_HOSTS="10.0.0.246 10.0.0.247"
NAS_SSH_PORT=22
NAS_USER=fn-backup
NAS_VOLUME=/volume1
NAS_ALLOW_FROM=10.0.0.0/24

nas_load_config() {
  if [ -r "$nas_env_file" ]; then
    . "$nas_env_file"
  fi
  if [ -n "${FN_NAS_HOSTS:-}" ]; then
    NAS_HOSTS="$FN_NAS_HOSTS"
  fi
}

nas_config_problem() {
  local safe_path='^[A-Za-z0-9._/+@-]+$'
  local host_name='^[A-Za-z0-9.-]+$'
  local user_name='^[a-z_][a-z0-9_.-]*$'
  local volume='^(/[A-Za-z0-9._-]+)+$'
  local allow='^[0-9A-Fa-f.:/,*?!]+$'
  local host
  if [[ ! $config_dir =~ $safe_path ]]; then
    printf 'the config folder %s has characters an SSH option cannot carry' "$config_dir"
    return
  fi
  if [ -z "${NAS_HOSTS// /}" ]; then
    printf 'NAS_HOSTS in %s names no host' "$nas_env_file"
    return
  fi
  for host in $NAS_HOSTS; do
    if [[ ! $host =~ $host_name ]]; then
      printf 'NAS_HOSTS in %s holds %s, which is not a host name or IPv4 address' "$nas_env_file" "$host"
      return
    fi
  done
  if [[ ! $NAS_SSH_PORT =~ ^[0-9]+$ ]] || [ "$NAS_SSH_PORT" -lt 1 ] || [ "$NAS_SSH_PORT" -gt 65535 ]; then
    printf 'NAS_SSH_PORT in %s is not a port number' "$nas_env_file"
  elif [[ ! $NAS_USER =~ $user_name ]]; then
    printf 'NAS_USER in %s is not an account name' "$nas_env_file"
  elif [[ ! $NAS_VOLUME =~ $volume ]]; then
    printf 'NAS_VOLUME in %s is not an absolute path such as /volume1' "$nas_env_file"
  elif [[ ! $NAS_ALLOW_FROM =~ $allow ]]; then
    printf 'NAS_ALLOW_FROM in %s is not an address pattern such as 10.0.0.0/24' "$nas_env_file"
  fi
}

nas_remote() {
  printf '%s@%s:%s/%s/' "$NAS_USER" "$2" "$NAS_VOLUME" "$1"
}

nas_transport() {
  printf 'ssh -p %s -i %s -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=%s -o ConnectTimeout=30' \
    "$NAS_SSH_PORT" "$nas_keys_dir/$1" "$nas_known_hosts"
}

nas_rsync_args() {
  local direction="$1"
  local share="$2"
  local host="$3"
  local transport="$4"
  local remote
  shift 4
  remote="$(nas_remote "$share" "$host")"
  case "$direction" in
    push)
      nas_args=(
        -a --delete --timeout=600
        --exclude='#snapshot/'
        --exclude='@eaDir/'
        --exclude='.uploads/'
        --exclude=relay.sqlite3
        --exclude=relay.sqlite3-wal
        --exclude=relay.sqlite3-shm
        --exclude='*-wal'
        --exclude='*-shm'
        -e "$transport"
        "$@" "$remote"
      )
      ;;
    pull)
      nas_args=(
        -a --no-links --timeout=600
        --exclude='#snapshot/'
        --exclude='@eaDir/'
        -e "$transport"
        "$remote" "$@"
      )
      ;;
    *)
      return 1
      ;;
  esac
}

nas_server_command() {
  local name="$1"
  local direction="${name%%-*}"
  local share="${name#*-}"
  local command_pattern='^rsync [A-Za-z0-9 ._/=,+-]+$'
  local probe
  local command
  probe="$(mktemp -d "${TMPDIR:-/tmp}/fn-nas-probe.XXXXXX")" || return 1
  cat > "$probe/transport" <<'PROBE'
#!/bin/sh
while [ "$#" -gt 0 ]; do
  case "$1" in
    -l)
      [ "$#" -ge 2 ] || exit 1
      shift 2
      ;;
    -*)
      shift
      ;;
    *)
      shift
      break
      ;;
  esac
done
printf '%s\n' "$*" > "$FN_NAS_PROBE_OUT"
exit 1
PROBE
  chmod 0700 "$probe/transport"
  mkdir -m 0700 "$probe/local"
  if nas_rsync_args "$direction" "$share" nas "$probe/transport" "$probe/local/"; then
    FN_NAS_PROBE_OUT="$probe/command" rsync "${nas_args[@]}" >/dev/null 2>&1
  fi
  command="$(cat "$probe/command" 2>/dev/null)"
  rm -rf "$probe"
  if [[ ! $command =~ $command_pattern ]]; then
    return 1
  fi
  printf '%s\n' "$command"
}

nas_pinned_line() {
  local command
  command="$(nas_server_command "$1")" || return 1
  printf '%s %s\n' "$1" "$command"
}

nas_ready_problem() {
  local problem
  local name
  local expected
  local recorded
  problem="$(nas_config_problem)"
  if [ -n "$problem" ]; then
    printf '%s' "$problem"
    return
  fi
  for name in "$@"; do
    if [ ! -r "$nas_keys_dir/$name" ]; then
      printf 'the key %s is missing; run nas-ssh-keys.sh keys and nas-ssh-keys.sh authorized, then update authorized_keys on the NAS' "$nas_keys_dir/$name"
      return
    fi
  done
  if [ ! -s "$nas_known_hosts" ]; then
    printf 'the NAS host key is not pinned in %s; run nas-ssh-keys.sh pin-host' "$nas_known_hosts"
    return
  fi
  for name in "$@"; do
    if ! expected="$(nas_pinned_line "$name")"; then
      printf 'rsync did not show the command it sends for %s' "$name"
      return
    fi
    recorded="$(awk -v name="$name" '$1 == name' "$nas_pinned_file" 2>/dev/null)"
    if [ "$expected" != "$recorded" ]; then
      printf 'the rsync command for %s no longer matches the one pinned in %s; run nas-ssh-keys.sh authorized and update authorized_keys on the NAS' "$name" "$nas_pinned_file"
      return
    fi
  done
}
