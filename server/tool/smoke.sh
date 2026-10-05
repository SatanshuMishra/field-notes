#!/usr/bin/env bash
set -euo pipefail

image="${1:?usage: smoke.sh <image>}"
attempts="${SMOKE_ATTEMPTS:-30}"
name="fn-relay-smoke-$$"
data="$(mktemp -d)"
chmod 0777 "$data"

cleanup() {
  docker rm --force "$name" >/dev/null 2>&1 || true
  docker run --rm --user 0:0 --entrypoint /bin/rm --volume "$data:/smoke" \
    "$image" -rf /smoke/relay >/dev/null 2>&1 || true
  rm -rf "$data" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --detach --name "$name" \
  --user 1000:1000 --read-only --tmpfs /tmp \
  --cap-drop ALL --security-opt no-new-privileges:true \
  --env RELAY_DATABASE=/smoke/relay/relay.sqlite3 \
  --env RELAY_MEDIA_DIR=/smoke/relay/media \
  --volume "$data:/smoke" \
  --publish 127.0.0.1::8080 \
  "$image" >/dev/null

port="$(docker port "$name" 8080/tcp | head -n 1 | sed 's/.*://')"
attempt=0
while [ "$attempt" -lt "$attempts" ]; do
  attempt=$((attempt + 1))
  status="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/health" || true)"
  if [ "$status" = "200" ]; then
    echo "The relay image answered /health with 200."
    exit 0
  fi
  sleep 1
done

echo "The relay image never answered /health with 200." >&2
docker logs "$name" >&2 || true
exit 1
