#!/bin/zsh
setopt err_exit no_unset pipe_fail

typeset -g RUN_DIR=${${(%):-%x}:A:h}
typeset -g REPO=${RUN_DIR:h:h:h}
typeset -g DRIVE=$RUN_DIR/drive.sh
typeset -g BIN=$REPO/build/probe/bin
typeset -g APPS=$REPO/build/probe/macos
typeset -g PROBE_NAME=field_notes_probe
typeset -g PROBE_BUNDLE_ID=dev.satanshumishra.fieldNotes.probe
typeset -g PROBE_BASE=http://127.0.0.1:47111
typeset -g ENTRY=integration_test/probe/composer_probe_main.dart

probe_binary_pattern() {
  print -r -- "/$PROBE_NAME\\.app/Contents/MacOS/$PROBE_NAME( |$)"
}

probe_pids() {
  pgrep -u $UID -f -- "$(probe_binary_pattern)" 2>/dev/null || true
}

reap_probes() {
  local -a pids=(${(f)"$(probe_pids)"})
  (( ${#pids} > 0 )) || return 0
  kill $pids 2>/dev/null || true
  local -i waited=0
  while (( waited < 50 )) && [[ -n $(probe_pids) ]]; do
    sleep 0.1
    (( waited += 1 ))
  done
  pids=(${(f)"$(probe_pids)"})
  (( ${#pids} > 0 )) && kill -9 $pids 2>/dev/null
  return 0
}

if [[ ${1:-} == --library ]]; then
  return 0
fi

usage() {
  print -u2 -r -- "usage: run.sh <scenario>|all [--build profile|debug] [--no-build] [--out <dir>]"
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
typeset -g OUT=$REPO/build/probe/results/macos

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

check_tools() {
  local tool
  for tool in flutter dart swiftc git curl osascript awk plutil; do
    if ! command -v $tool >/dev/null 2>&1; then
      print -u2 -r -- "run: $tool is not installed or not on PATH"
      exit 2
    fi
  done
}

compile_helpers() {
  mkdir -p $BIN
  local name
  for name in inp pasteboard drag_files; do
    if [[ ! -x $BIN/$name || $RUN_DIR/$name.swift -nt $BIN/$name ]]; then
      print -r -- "run: compiling $name"
      swiftc -O $RUN_DIR/$name.swift -o $BIN/$name
    fi
  done
}

typeset -g SCRATCH=

remove_scratch() {
  if [[ -n $SCRATCH && -d $SCRATCH ]]; then
    git -C $REPO worktree remove --force $SCRATCH >/dev/null 2>&1 || true
  fi
  SCRATCH=
}

rename_probe() {
  local config=$SCRATCH/macos/Runner/Configs/AppInfo.xcconfig
  sed -i '' \
    -e "s/^PRODUCT_NAME = .*/PRODUCT_NAME = $PROBE_NAME/" \
    -e "s/^PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $PROBE_BUNDLE_ID/" \
    $config
  if ! grep -qx "PRODUCT_NAME = $PROBE_NAME" $config || ! grep -qx "PRODUCT_BUNDLE_IDENTIFIER = $PROBE_BUNDLE_ID" $config; then
    print -u2 -r -- "run: could not rename the probe in $config"
    exit 1
  fi
}

build_probes() {
  local dirty
  dirty=$(git -C $REPO status --porcelain)
  if [[ -n $dirty ]]; then
    print -u2 -r -- "run: warning: the probe is built from HEAD, so these uncommitted changes are not in it:"
    print -u2 -r -- "$dirty"
  fi
  local sha
  sha=$(git -C $REPO rev-parse HEAD)
  local parent
  parent=$(mktemp -d "${TMPDIR:-/tmp}/field_notes_probe_build.XXXXXX")
  SCRATCH=$parent/field_notes
  trap remove_scratch EXIT
  git -C $REPO worktree add --detach $SCRATCH HEAD >/dev/null
  rename_probe
  (cd $SCRATCH && { flutter pub get --offline >/dev/null || flutter pub get >/dev/null; })
  local build product
  for build in profile debug; do
    product=${(C)build}
    print -r -- "run: building the $build probe at ${sha[1,12]}"
    (cd $SCRATCH && flutter build macos --$build -t $ENTRY)
    local built=$SCRATCH/build/macos/Build/Products/$product/$PROBE_NAME.app
    if [[ ! -d $built ]]; then
      print -u2 -r -- "run: flutter did not produce $built"
      exit 1
    fi
    rm -rf $APPS/$build
    mkdir -p $APPS/$build
    cp -R $built $APPS/$build/$PROBE_NAME.app
    print -r -- $sha > $APPS/$build/COMMIT
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

quit_probe() {
  local pid=$1
  kill $pid 2>/dev/null || true
  local -i waited=0
  while (( waited < 50 )) && kill -0 $pid 2>/dev/null; do
    sleep 0.1
    (( waited += 1 ))
  done
  kill -9 $pid 2>/dev/null || true
}

typeset -ga SUMMARY=()
typeset -gi FAILED=0

run_scenario() {
  local scenario=$1 build=$2
  local app=$APPS/$build/$PROBE_NAME.app
  if [[ ! -x $app/Contents/MacOS/$PROBE_NAME ]]; then
    print -u2 -r -- "run: no $build probe at $app; run without --no-build first"
    SUMMARY+=("$scenario $build ERROR no probe")
    FAILED=1
    return 0
  fi
  local sha
  sha=$(<$APPS/$build/COMMIT)
  local result=$OUT/$sha/$scenario-$build.json
  mkdir -p ${result:h}
  print -r -- "run: $scenario ($build)"
  reap_probes
  $app/Contents/MacOS/$PROBE_NAME >/dev/null 2>&1 &
  local pid=$!
  if ! probe_ready; then
    print -u2 -r -- "run: the probe did not answer within 90 s"
    quit_probe $pid
    reap_probes
    SUMMARY+=("$scenario $build ERROR probe did not start")
    FAILED=1
    return 0
  fi
  local served
  served=$(curl -sS -f --max-time 2 $PROBE_BASE/pid | plutil -extract pid raw -o - - 2>/dev/null) || served=
  if [[ $served != $pid ]]; then
    print -u2 -r -- "run: port 47111 answers for pid ${served:-unknown}, not the probe run.sh started ($pid)"
    quit_probe $pid
    reap_probes
    SUMMARY+=("$scenario $build ERROR another probe held the port")
    FAILED=1
    return 0
  fi
  curl -sS -f --max-time 60 -X POST "$PROBE_BASE/scenario?name=$scenario&fresh=1" >/dev/null
  osascript -e "tell application \"System Events\" to tell process \"$PROBE_NAME\" to set position of window 1 to {40, 40}" \
    -e "tell application \"System Events\" to tell process \"$PROBE_NAME\" to set size of window 1 to {1280, 860}" >/dev/null
  local -i drive_status=0
  PROBE_BUILD=$build zsh $DRIVE $scenario $build $result || drive_status=$?
  quit_probe $pid
  reap_probes
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
compile_helpers
(( NO_BUILD )) || build_probes

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
