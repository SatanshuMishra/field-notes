#!/usr/bin/env bash
set -u
set -o pipefail

repository="ghcr.io/satanshumishra/field-notes-relay"
repository_digest_pattern='^ghcr\.io/satanshumishra/field-notes-relay@sha256:[0-9a-f]{64}$'
tag_pattern='^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$'
digest_pattern='^sha256:[0-9a-f]{64}$'
issuer="https://token.actions.githubusercontent.com"
identity='^https://github\.com/(?i:satanshumishra)/field-notes/\.github/workflows/relay-image\.yml@refs/heads/main$'
workflow_repository="SatanshuMishra/field-notes"
workflow_ref="refs/heads/main"
commit_pattern='^[0-9a-f]{40}$'
config_dir="${FN_CONFIG_DIR:-/home/satanshumishra/.config/field-notes}"
image_file="$config_dir/relay-image.env"
history_file="$config_dir/relay-image.history"
script_dir="$(cd "$(dirname "$0")" && pwd)"
alert="$script_dir/alert.sh"
staged=""

log() {
  printf '%s relay-update: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

cleanup() {
  if [ -n "$staged" ]; then
    rm -f "$staged"
  fi
}
trap cleanup EXIT

fail() {
  log "failed: $1"
  "$alert" "relay update failed" "The relay image update stopped and changed nothing, so the relays keep running the image they run now. Failed step: $1."
  exit 1
}

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as satanshumishra, not with sudo." >&2
  exit 1
fi
if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [tag or sha256:digest], for example $0 main or $0 sha-0123456789ab" >&2
  exit 64
fi

wanted="${1:-main}"
if [[ $wanted =~ $digest_pattern ]]; then
  reference="$repository@$wanted"
elif [[ $wanted =~ $tag_pattern ]]; then
  reference="$repository:$wanted"
else
  fail "read $wanted, which is neither an image tag nor a sha256 digest"
fi

docker pull --quiet "$reference" >/dev/null || fail "pull $reference"

pinned="$(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$reference" 2>/dev/null \
  | grep -E "$repository_digest_pattern" \
  | head -n 1)"
if [ -z "$pinned" ]; then
  fail "read the repository digest of $reference"
fi
digest="${pinned#*@}"
if [[ $wanted =~ $digest_pattern ]] && [ "$digest" != "$wanted" ]; then
  fail "match the pulled digest $digest to the requested $wanted"
fi

if [[ ! $wanted =~ $digest_pattern ]] && [ -s "$history_file" ]; then
  recorded="$(grep -oE 'sha256:[0-9a-f]{64}' "$history_file")"
  newest="$(tail -n 1 <<< "$recorded")"
  if [ "$digest" != "$newest" ] && grep -qxF "$digest" <<< "$recorded"; then
    fail "accept $reference, which resolves to $digest, an older image in $history_file than the newest one; to roll back on purpose, run $0 $digest"
  fi
fi

log "verifying the signature of $pinned"
verification="$(cosign verify \
  --certificate-oidc-issuer "$issuer" \
  --certificate-identity-regexp "$identity" \
  --certificate-github-workflow-repository "$workflow_repository" \
  --certificate-github-workflow-ref "$workflow_ref" \
  --output json \
  "$pinned")" \
  || fail "verify the signature of $pinned, which this repository's image workflow on main did not sign"
commit="$(printf '%s' "$verification" \
  | jq -r '[.[] | .optional.githubWorkflowSha // empty] | unique | if length == 1 then .[0] else empty end' 2>/dev/null)"
if [[ ! $commit =~ $commit_pattern ]]; then
  fail "read the commit $pinned was built from, which its signature must name once"
fi
log "$pinned was built from commit $commit"

if [ ! -d "$config_dir" ]; then
  mkdir -p -m 0700 "$config_dir" || fail "create $config_dir"
fi
line="RELAY_IMAGE=$pinned"
staged="$(mktemp "$config_dir/.relay-image.env.XXXXXX")" || fail "stage $image_file"
printf '%s\n' "$line" > "$staged" || fail "write $image_file"
chmod 0600 "$staged" || fail "set the mode of $image_file"
(umask 077; printf '%s %s %s\n' "$digest" "$commit" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$history_file") \
  || fail "record $pinned in $history_file"
mv -f "$staged" "$image_file" || fail "write $image_file"
staged=""

printf '%s\n' "$line"
cat <<NEXT

Verified $reference as $pinned, built from commit $commit, and saved it in $image_file.
Next steps:
  1. In Dokploy, open the Field Notes project, the relay compose app, then Environment, set
     RELAY_TEST_IMAGE=$pinned
     and deploy. On the very first deploy, set RELAY_IMAGE to the same value too: the compose
     file refuses to deploy while either one is missing.
  2. Check the test relay: curl -fsS https://sync-test.satanshu.tech/health prints ok.
  3. Set RELAY_IMAGE=$pinned the same way and deploy again.
NEXT
