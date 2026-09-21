#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUTPUT="build/note_perf_bench.json"
TARGET="integration_test/note_perf_bench_test.dart"
DRIVER="test_driver/perf_driver.dart"
BUILD_MODE="--profile"
ALLOW_EMULATOR="no"
SERIAL="${BENCH_DEVICE:-}"

usage() {
  cat <<'USAGE'
usage: scripts/android-bench.sh [-d SERIAL] [--allow-emulator] [--debug]

Runs the five note-editor measurements on a connected physical Android phone
and writes them to build/note_perf_bench.json.

  -d SERIAL          run against this adb serial (default: the only connected
                     physical device; also read from $BENCH_DEVICE)
  --allow-emulator   permit an emulator serial; the recorded numbers are then
                     NOT a mid-tier device measurement and must be labelled so
  --debug            run in debug mode instead of profile; debug numbers are
                     several times slower and are not a valid baseline

Requires adb on PATH or under $ANDROID_HOME / $ANDROID_SDK_ROOT /
~/Library/Android/sdk, a phone with USB debugging authorised, and Flutter.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -d) SERIAL="${2:-}"; shift 2 ;;
    --allow-emulator) ALLOW_EMULATOR="yes"; shift ;;
    --debug) BUILD_MODE="--debug"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "android-bench: unknown argument $1" >&2; usage >&2; exit 2 ;;
  esac
done

resolve_adb() {
  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return 0
  fi
  local candidate
  for candidate in \
    "${ANDROID_HOME:-}/platform-tools/adb" \
    "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
    "$HOME/Library/Android/sdk/platform-tools/adb" \
    "$HOME/Android/Sdk/platform-tools/adb"; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

if ! ADB="$(resolve_adb)"; then
  cat >&2 <<'MISSING'
android-bench: adb not found.

Install Android Studio, which ships platform-tools, or the standalone
platform-tools package, then put adb on PATH or export ANDROID_HOME.

This measurement cannot be substituted with a desktop run. The unit exists to
measure the mid-tier Android multiplier; a macOS run measures Apple Silicon.
MISSING
  exit 3
fi

"$ADB" start-server >/dev/null 2>&1 || true

DEVICES="$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')"
NOT_READY="$("$ADB" devices | awk 'NR>1 && NF>1 && $2!="device" {print $1" ("$2")"}')"

if [ -n "$NOT_READY" ]; then
  echo "android-bench: ignoring devices that are not ready:" >&2
  echo "$NOT_READY" | sed 's/^/  /' >&2
fi

if [ -z "$DEVICES" ]; then
  echo "android-bench: no Android device is connected and authorised." >&2
  echo "Plug the phone in, enable USB debugging, accept the RSA prompt." >&2
  exit 4
fi

if [ -z "$SERIAL" ]; then
  COUNT="$(printf '%s\n' "$DEVICES" | wc -l | tr -d ' ')"
  if [ "$COUNT" != "1" ]; then
    echo "android-bench: $COUNT devices are connected; pass -d SERIAL." >&2
    printf '%s\n' "$DEVICES" | sed 's/^/  /' >&2
    exit 5
  fi
  SERIAL="$DEVICES"
elif ! printf '%s\n' "$DEVICES" | grep -qx "$SERIAL"; then
  echo "android-bench: $SERIAL is not a connected, authorised device." >&2
  exit 5
fi

case "$SERIAL" in
  emulator-*)
    if [ "$ALLOW_EMULATOR" != "yes" ]; then
      echo "android-bench: $SERIAL is an emulator." >&2
      echo "An emulator runs on this host's CPU and measures the wrong machine." >&2
      echo "Use a physical mid-tier phone, or pass --allow-emulator and label" >&2
      echo "the recorded numbers as an emulator run." >&2
      exit 6
    fi
    ;;
esac

prop() {
  "$ADB" -s "$SERIAL" shell getprop "$1" 2>/dev/null | tr -d '\r\n' || true
}

MODEL="$(prop ro.product.model)"
RELEASE="$(prop ro.build.version.release)"
SDK="$(prop ro.build.version.sdk)"
HARDWARE="$(prop ro.hardware)"
[ -n "$MODEL" ] || MODEL="unknown"
[ -n "$RELEASE" ] || RELEASE="unknown"
[ -n "$SDK" ] || SDK="unknown"
[ -n "$HARDWARE" ] || HARDWARE="unknown"

FLUTTER_VERSION="$(flutter --version 2>/dev/null | head -1 | awk '{print $2" ("$5" channel)"}')"
[ -n "$FLUTTER_VERSION" ] || FLUTTER_VERSION="unknown"
GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  GIT_SHA="$GIT_SHA-dirty"
fi

MODE_LABEL="${BUILD_MODE#--}"

echo "android-bench: device   $MODEL ($SERIAL, hardware $HARDWARE)"
echo "android-bench: android  $RELEASE (SDK $SDK)"
echo "android-bench: flutter  $FLUTTER_VERSION"
echo "android-bench: commit   $GIT_SHA"
echo "android-bench: mode     $MODE_LABEL"
if [ "$MODE_LABEL" = "debug" ]; then
  echo "android-bench: WARNING debug mode is not a valid performance baseline." >&2
fi
echo

rm -f "$OUTPUT"

set -x
flutter drive \
  --driver="$DRIVER" \
  --target="$TARGET" \
  "$BUILD_MODE" \
  -d "$SERIAL" \
  --dart-define=BENCH_ON_DEVICE=true \
  --dart-define=BENCH_RUN_LABEL="android-$MODE_LABEL" \
  --dart-define=BENCH_DEVICE_MODEL="$MODEL" \
  --dart-define=BENCH_DEVICE_RELEASE="$RELEASE" \
  --dart-define=BENCH_DEVICE_SDK="$SDK" \
  --dart-define=BENCH_FLUTTER_VERSION="$FLUTTER_VERSION" \
  --dart-define=BENCH_GIT_SHA="$GIT_SHA"
set +x

echo
if [ -f "$OUTPUT" ]; then
  echo "android-bench: wrote $REPO_ROOT/$OUTPUT"
  echo "android-bench: paste it into"
  echo "  docs/specs/research/2026-09-20-android-measurement.md"
else
  echo "android-bench: $OUTPUT was not written; the drive run above failed." >&2
  exit 7
fi
