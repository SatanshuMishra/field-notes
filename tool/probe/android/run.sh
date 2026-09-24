#!/bin/zsh
setopt err_exit no_unset pipe_fail

typeset -g RUN_DIR=${${(%):-%x}:A:h}
typeset -g REPO=${RUN_DIR:h:h:h}
typeset -g DRIVE=$RUN_DIR/drive.sh
typeset -g APKS=$REPO/build/probe/android
typeset -g PROBE_NAME=field_notes_probe
typeset -g PROBE_PACKAGE=dev.satanshumishra.field_notes.probe
typeset -g PROBE_ACTIVITY=dev.satanshumishra.field_notes.MainActivity
typeset -g OWNER_PACKAGE=dev.satanshumishra.field_notes
typeset -g PROBE_BASE=http://127.0.0.1:47111
typeset -g ENTRY=integration_test/probe/composer_probe_main.dart

usage() {
  print -u2 -r -- "usage: run.sh <scenario>|all [--build profile|debug] [--no-build] [--out <dir>] [-d SERIAL] [--allow-emulator]"
  print -u2 -r -- "       run.sh --list"
}

if [[ ${1:-} == --list ]]; then
  zsh $DRIVE --list
  exit 0
fi

if (( $# < 1 )); then
  usage
  exit 2
fi

typeset -g TARGET=$1
shift
typeset -g ONLY_BUILD=
typeset -gi NO_BUILD=0
typeset -g OUT=$REPO/build/probe/results/android
typeset -g SERIAL=${ANDROID_SERIAL:-}
typeset -g ALLOW_EMULATOR=no

while (( $# > 0 )); do
  case $1 in
    --build)
      if [[ ${2:-} != profile && ${2:-} != debug ]]; then
        usage
        exit 2
      fi
      ONLY_BUILD=$2
      shift 2
      ;;
    --no-build)
      NO_BUILD=1
      shift
      ;;
    --out)
      if [[ -z ${2:-} ]]; then
        usage
        exit 2
      fi
      OUT=${2:A}
      shift 2
      ;;
    -d)
      if [[ -z ${2:-} ]]; then
        usage
        exit 2
      fi
      SERIAL=$2
      shift 2
      ;;
    --allow-emulator)
      ALLOW_EMULATOR=yes
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

typeset -ga SCENARIOS=("${(@f)$(zsh $DRIVE --list)}")
typeset -ga SELECTED=()
if [[ $TARGET == all ]]; then
  SELECTED=($SCENARIOS)
elif (( ${SCENARIOS[(Ie)$TARGET]} )); then
  SELECTED=($TARGET)
else
  print -u2 -r -- "run: unknown scenario $TARGET"
  usage
  exit 2
fi

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
    if [[ -x $candidate ]]; then
      print -r -- $candidate
      return 0
    fi
  done
  return 1
}

check_tools() {
  local tool
  for tool in flutter dart git curl awk plutil; do
    if ! command -v $tool >/dev/null 2>&1; then
      print -u2 -r -- "run: $tool is not installed or not on PATH"
      exit 2
    fi
  done
}

typeset -g ADB=

choose_device() {
  if ! ADB=$(resolve_adb); then
    print -u2 -r -- "run: adb not found; install the Android platform-tools or export ANDROID_HOME"
    exit 3
  fi
  "$ADB" start-server >/dev/null 2>&1 || true
  local devices
  devices=$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1 }')
  if [[ -z $devices ]]; then
    print -u2 -r -- "run: no Android device is connected and authorised"
    exit 4
  fi
  if [[ -z $SERIAL ]]; then
    local -i count
    count=$(print -r -- "$devices" | wc -l | tr -d ' ')
    if (( count != 1 )); then
      print -u2 -r -- "run: $count devices are connected; pass -d SERIAL"
      exit 5
    fi
    SERIAL=$devices
  elif ! print -r -- "$devices" | grep -qx -- "$SERIAL"; then
    print -u2 -r -- "run: $SERIAL is not a connected, authorised device"
    exit 5
  fi
  case $SERIAL in
    emulator-*)
      if [[ $ALLOW_EMULATOR != yes ]]; then
        print -u2 -r -- "run: $SERIAL is an emulator; the Android gates run on the physical phone (pass --allow-emulator to override)"
        exit 6
      fi
      ;;
  esac
  export ANDROID_SERIAL=$SERIAL
  export ADB
}

typeset -g SCRATCH=

remove_scratch() {
  if [[ -n $SCRATCH && -d $SCRATCH ]]; then
    git -C $REPO worktree remove --force $SCRATCH >/dev/null 2>&1 || true
  fi
  SCRATCH=
}

rename_probe() {
  local gradle=$SCRATCH/android/app/build.gradle.kts
  local manifest=$SCRATCH/android/app/src/main/AndroidManifest.xml
  sed -i '' -e "s/applicationId = \"$OWNER_PACKAGE\"/applicationId = \"$PROBE_PACKAGE\"/" $gradle
  sed -i '' -e "s/android:label=\"field_notes\"/android:label=\"$PROBE_NAME\"/" $manifest
  if ! grep -q "applicationId = \"$PROBE_PACKAGE\"" $gradle || ! grep -q "android:label=\"$PROBE_NAME\"" $manifest; then
    print -u2 -r -- "run: could not rename the probe in the scratch worktree"
    exit 1
  fi
}

build_apks() {
  local dirty
  dirty=$(git -C $REPO status --porcelain)
  if [[ -n $dirty ]]; then
    print -u2 -r -- "run: warning: the probe is built from HEAD, so these uncommitted changes are not in it:"
    print -u2 -r -- "$dirty"
  fi
  local sha
  sha=$(git -C $REPO rev-parse HEAD)
  local parent
  parent=$(mktemp -d "${TMPDIR:-/tmp}/field_notes_probe_apk.XXXXXX")
  SCRATCH=$parent/field_notes
  trap remove_scratch EXIT
  git -C $REPO worktree add --detach $SCRATCH HEAD >/dev/null
  rename_probe
  (cd $SCRATCH && { flutter pub get --offline >/dev/null || flutter pub get >/dev/null; })
  local build
  for build in profile debug; do
    print -r -- "run: building the $build probe APK at ${sha[1,12]}"
    (cd $SCRATCH && flutter build apk --$build -t $ENTRY)
    local built=$SCRATCH/build/app/outputs/flutter-apk/app-$build.apk
    if [[ ! -f $built ]]; then
      print -u2 -r -- "run: flutter did not produce $built"
      exit 1
    fi
    rm -rf $APKS/$build
    mkdir -p $APKS/$build
    cp $built $APKS/$build/$PROBE_NAME.apk
    print -r -- $sha > $APKS/$build/COMMIT
  done
  remove_scratch
  rm -rf $parent
  trap - EXIT
}

probe_ready() {
  local -i waited=0
  while (( waited < 900 )); do
    if curl -sS -f --max-time 2 $PROBE_BASE/pid >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
    (( waited += 1 ))
  done
  return 1
}

typeset -ga SUMMARY=()
typeset -gi FAILED=0

run_scenario() {
  local scenario=$1 build=$2
  local apk=$APKS/$build/$PROBE_NAME.apk
  if [[ ! -f $apk ]]; then
    print -u2 -r -- "run: no $build probe APK at $apk; run without --no-build first"
    SUMMARY+=("$scenario $build ERROR no probe")
    FAILED=1
    return 0
  fi
  local sha
  sha=$(<$APKS/$build/COMMIT)
  local result=$OUT/$sha/$scenario-$build.json
  mkdir -p ${result:h}
  print -r -- "run: $scenario ($build) on $SERIAL"
  "$ADB" install -r $apk >/dev/null
  "$ADB" forward tcp:47111 tcp:47111 >/dev/null
  "$ADB" shell am start -W -n $PROBE_PACKAGE/$PROBE_ACTIVITY >/dev/null
  if ! probe_ready; then
    print -u2 -r -- "run: the probe did not answer within 90 s"
    "$ADB" shell am force-stop $PROBE_PACKAGE >/dev/null 2>&1 || true
    SUMMARY+=("$scenario $build ERROR probe did not start")
    FAILED=1
    return 0
  fi
  curl -sS -f --max-time 60 -X POST "$PROBE_BASE/scenario?name=$scenario&fresh=1" >/dev/null
  local -i drive_status=0
  PROBE_BUILD=$build zsh $DRIVE $scenario $build $result || drive_status=$?
  "$ADB" shell am force-stop $PROBE_PACKAGE >/dev/null 2>&1 || true
  local -i evaluate_status=0
  (cd $REPO && dart run tool/probe/lib/gates.dart evaluate $result) || evaluate_status=$?
  if (( drive_status != 0 )); then
    SUMMARY+=("$scenario $build ERROR the driver exited $drive_status")
    FAILED=1
  elif (( evaluate_status == 0 )); then
    SUMMARY+=("$scenario $build PASS")
  elif (( evaluate_status == 1 )); then
    SUMMARY+=("$scenario $build FAIL")
    FAILED=1
  else
    SUMMARY+=("$scenario $build ERROR the result could not be evaluated")
    FAILED=1
  fi
}

check_tools
choose_device
(( NO_BUILD )) || build_apks

for scenario in $SELECTED; do
  typeset -a builds=("${(@f)$(cd $REPO && dart run tool/probe/lib/gates.dart builds $scenario)}")
  for build in $builds; do
    if [[ -n $ONLY_BUILD && $build != $ONLY_BUILD ]]; then
      continue
    fi
    run_scenario $scenario $build
  done
done

print -r -- ''
print -r -- 'run: summary'
print -rl -- $SUMMARY
exit $FAILED
