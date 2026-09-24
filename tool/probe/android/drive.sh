#!/bin/zsh
setopt err_exit no_unset pipe_fail

typeset -g PROBE_ANDROID_DIR=${${(%):-%x}:A:h}

source ${PROBE_ANDROID_DIR:h}/macos/drive.sh --library

typeset -g ANDROID_PACKAGE=dev.satanshumishra.field_notes.probe
typeset -g ANDROID_ACTIVITY=dev.satanshumishra.field_notes.MainActivity
typeset -g ADB=${ADB:-adb}
typeset -g KEYMAP_DIR=$PROBE_ANDROID_DIR/keymaps
typeset -g KEYMAP_NAME=
typeset -gA KEYMAP=()
typeset -g ANDROID_DPR=
typeset -g FONT_SCALE_SAVED=
typeset -g IME_SAVED=

PROBE_PRIMITIVES+=(plat_swipe_type plat_ime plat_ime_insert_image)

typeset -ga KEYMAP_REQUIRED=(
  a b c d e f g h i j k l m n o p q r s t u v w x y z
  0 1 2 3 4 5 6 7 8 9
  space enter backspace shift symbols emoji clipboard voice
)

typeset -gA ANDROID_KEYCODES=(
  left KEYCODE_DPAD_LEFT right KEYCODE_DPAD_RIGHT up KEYCODE_DPAD_UP down KEYCODE_DPAD_DOWN
  backspace KEYCODE_DEL delete KEYCODE_FORWARD_DEL enter KEYCODE_ENTER return KEYCODE_ENTER
  kp_enter KEYCODE_NUMPAD_ENTER escape KEYCODE_ESCAPE tab KEYCODE_TAB space KEYCODE_SPACE
  home KEYCODE_MOVE_HOME end KEYCODE_MOVE_END pageup KEYCODE_PAGE_UP pagedown KEYCODE_PAGE_DOWN
  '=' KEYCODE_EQUALS '-' KEYCODE_MINUS '[' KEYCODE_LEFT_BRACKET ']' KEYCODE_RIGHT_BRACKET
  ';' KEYCODE_SEMICOLON "'" KEYCODE_APOSTROPHE ',' KEYCODE_COMMA '.' KEYCODE_PERIOD
  '/' KEYCODE_SLASH '\' KEYCODE_BACKSLASH '`' KEYCODE_GRAVE
)

adb_run() {
  "$ADB" "$@"
}

adb_shell() {
  "$ADB" shell "$@"
}

adb_quote() {
  print -rn -- "'${1//\'/\'\\\'\'}'"
}

android_load() {
  origin_load
  if [[ -z $ANDROID_DPR ]]; then
    ANDROID_DPR=$(jget "$(probe_get 'state?text=0')" view.devicePixelRatio) || ANDROID_DPR=1
  fi
}

android_px() {
  print -r -- $(( int(ORIGIN_X + $1 * ANDROID_DPR + 0.5) )) $(( int(ORIGIN_Y + $2 * ANDROID_DPR + 0.5) ))
}

plat_name() {
  print -r -- android
}

plat_launch() {
  adb_shell am start -W -n $ANDROID_PACKAGE/$ANDROID_ACTIVITY >/dev/null
  adb_run forward tcp:47111 tcp:47111 >/dev/null
  probe_wait 90
  ORIGIN_X=
  ORIGIN_Y=
  ANDROID_DPR=
}

plat_kill() {
  if [[ ${1:-} == --hide ]]; then
    adb_shell input keyevent KEYCODE_HOME
    sleep 0.3
    adb_shell am kill $ANDROID_PACKAGE
  else
    adb_shell am force-stop $ANDROID_PACKAGE
  fi
  ORIGIN_X=
  ORIGIN_Y=
  ANDROID_DPR=
}

plat_origin() {
  local frame
  frame=$(adb_shell dumpsys window windows 2>/dev/null | awk -v package=$ANDROID_PACKAGE '
    index($0, package) { inside = 1 }
    inside && match($0, /[fF]rame=\[[0-9-]+,[0-9-]+\]/) {
      value = substr($0, RSTART, RLENGTH)
      sub(/^[^[]*\[/, "", value)
      sub(/\]$/, "", value)
      split(value, parts, ",")
      print parts[1], parts[2]
      exit
    }
  ') || frame=
  print -r -- ${frame:-0 0}
}

plat_click() {
  local hold=${3:-20}
  android_load
  point_inside $1 $2 || return $?
  local point
  point=$(android_px $1 $2)
  if (( hold <= 40 )); then
    adb_shell input tap ${=point}
  else
    adb_shell input swipe ${=point} ${=point} $hold
  fi
}

plat_right_click() {
  android_load
  point_inside $1 $2 || return $?
  local point
  point=$(android_px $1 $2)
  adb_shell input tap ${=point}
  sleep 0.3
  if ! text_present Copy; then
    adb_shell input tap ${=point}
  fi
}

plat_drag() {
  local hover=${6:-0}
  android_load
  point_inside $1 $2 || return $?
  point_inside $3 $4 || return $?
  local start end
  start=$(android_px $1 $2)
  end=$(android_px $3 $4)
  if (( hover <= 0 )); then
    adb_shell input swipe ${=start} ${=end} 600
    return 0
  fi
  local -a from=(${=start}) to=(${=end})
  adb_shell input motionevent DOWN $from
  sleep 0.45
  local -i step
  for (( step = 1; step <= 24; step++ )); do
    adb_shell input motionevent MOVE $(( from[1] + (to[1] - from[1]) * step / 24 )) $(( from[2] + (to[2] - from[2]) * step / 24 ))
  done
  sleep_ms $hover
  adb_shell input motionevent UP $to
}

plat_scroll() {
  android_load
  local point
  point=$(android_px $1 $2)
  local -a from=(${=point})
  local -i end=$(( from[2] + int($3 * ANDROID_DPR) ))
  (( end < 8 )) && end=8
  (( end > from[2] * 2 )) && end=$(( from[2] * 2 ))
  adb_shell input swipe $from[1] $from[2] $from[1] $end 120
}

android_keycode() {
  local name=$1
  if [[ -n ${ANDROID_KEYCODES[$name]:-} ]]; then
    print -r -- ${ANDROID_KEYCODES[$name]}
  elif [[ $name == [a-z] || $name == [0-9] ]]; then
    print -r -- KEYCODE_${(U)name}
  else
    return 1
  fi
}

plat_key() {
  local combo=$1 name=${1##*+}
  local -a mods=() codes=()
  [[ $combo == *+* ]] && mods=(${(s:+:)${combo%+*}})
  local mod
  for mod in $mods; do
    case $mod in
      cmd|ctrl) codes+=(KEYCODE_CTRL_LEFT) ;;
      shift) codes+=(KEYCODE_SHIFT_LEFT) ;;
      opt) codes+=(KEYCODE_ALT_LEFT) ;;
      *) print -u2 -r -- "drive: unknown modifier $mod in $combo"; return 2 ;;
    esac
  done
  local code
  code=$(android_keycode $name) || { print -u2 -r -- "drive: unknown key $combo"; return 2; }
  if (( ${#codes} == 0 )); then
    adb_shell input keyevent $code
  else
    adb_shell input keycombination $codes $code
  fi
}

keymap_load() {
  local keyboard=$1 file=$KEYMAP_DIR/$1.json
  KEYMAP=()
  KEYMAP_NAME=
  [[ -f $file ]] || return 1
  local json
  json=$(<$file)
  local key x y
  for key in $KEYMAP_REQUIRED; do
    x=$(jget "$json" keys.$key.0) && y=$(jget "$json" keys.$key.1) || continue
    KEYMAP[$key]="$x $y"
  done
  KEYMAP_NAME=$keyboard
}

keymap_tap() {
  local point=${KEYMAP[$1]:-}
  [[ -n $point ]] || return 1
  adb_shell input tap ${=point}
}

plat_type() {
  local text=$1
  if [[ -n $KEYMAP_NAME ]]; then
    local -i index
    local char
    for (( index = 1; index <= ${#text}; index++ )); do
      char=${text[index]}
      case $char in
        ' ') keymap_tap space ;;
        [a-z0-9]) keymap_tap $char ;;
        [A-Z]) keymap_tap shift && keymap_tap ${(L)char} ;;
        *) adb_shell input text $(adb_quote "$char") ;;
      esac
    done
    return 0
  fi
  adb_shell input text $(adb_quote "${text// /%s}")
}

plat_timed_type() {
  local text=$1
  local -a codes=()
  local -i index
  local char
  for (( index = 1; index <= ${#text}; index++ )); do
    char=${text[index]}
    case $char in
      ' ') codes+=(KEYCODE_SPACE) ;;
      [a-z0-9]) codes+=(KEYCODE_${(U)char}) ;;
      *) codes+=($(android_keycode $char)) ;;
    esac
  done
  adb_shell input keyevent $codes >/dev/null
}

plat_swipe_type() {
  local word=$1
  if [[ -z $KEYMAP_NAME ]]; then
    print -u2 -r -- 'drive: key map not recorded'
    return 1
  fi
  local first=${KEYMAP[${word[1]}]:-}
  [[ -n $first ]] || return 1
  adb_shell input motionevent DOWN ${=first}
  local -i index
  for (( index = 1; index <= ${#word}; index++ )); do
    local point=${KEYMAP[${word[index]}]:-}
    [[ -n $point ]] || continue
    adb_shell input motionevent MOVE ${=point}
    sleep 0.02
  done
  adb_shell input motionevent UP ${=${KEYMAP[${word[-1]}]}}
}

plat_clock_pair() {
  return 0
}

plat_cpu() {
  adb_shell cat /proc/$1/stat | tr -d '\r'
}

plat_cpu_format() {
  local ticks
  ticks=$(adb_shell getconf CLK_TCK 2>/dev/null | tr -d '\r') || ticks=
  [[ $ticks == <-> ]] || ticks=100
  print -r -- "procstat $ticks"
}

plat_rss() {
  local kilobytes
  kilobytes=$(adb_shell dumpsys meminfo $1 | tr -d '\r' | awk '
    /TOTAL RSS:/ { for (i = 1; i <= NF; i++) if ($i == "RSS:") { print $(i + 1); exit } }
  ')
  print -r -- $(( ${kilobytes:-0} * 1024 ))
}

plat_text_scales() {
  print -rl -- 1.0 1.3 2.0
}

plat_set_text_scale() {
  if [[ -z $FONT_SCALE_SAVED ]]; then
    FONT_SCALE_SAVED=$(adb_shell settings get system font_scale | tr -d '\r')
  fi
  adb_shell settings put system font_scale $1
  sleep 1
  ORIGIN_X=
  ORIGIN_Y=
  ANDROID_DPR=
}

plat_front() {
  return 0
}

ime_restore() {
  if [[ -n $IME_SAVED && $IME_SAVED != null ]]; then
    adb_shell ime set $IME_SAVED >/dev/null 2>&1 || true
  fi
}

font_scale_restore() {
  if [[ -n $FONT_SCALE_SAVED && $FONT_SCALE_SAVED != null ]]; then
    adb_shell settings put system font_scale $FONT_SCALE_SAVED >/dev/null 2>&1 || true
  else
    adb_shell settings delete system font_scale >/dev/null 2>&1 || true
  fi
}

plat_columns() {
  probe_post "settings?textSize=$1" >/dev/null
  sleep 0.3
  jget "$(probe_get 'state?text=0')" column
}

plat_reveal_budget_ms() {
  print -r -- 300
}

plat_paste_image() {
  local file=$1 type=$2
  local target=/sdcard/Download/field_notes_probe_paste.$type
  adb_run push $file $target >/dev/null
  plat_owner_step "open the Files app, long-press Download/field_notes_probe_paste.$type, copy it to the clipboard, then return to the probe"
  local state center
  state=$(state_get text=0)
  if center=$(rect_center "$state" caret); then
    plat_click ${center%% *} ${center##* } 700
    sleep 0.5
  fi
  local found
  found=$(probe_get 'find?text=Paste')
  if center=$(rect_center "$found" rects.0); then
    plat_click ${center%% *} ${center##* } 20
  fi
  adb_shell rm -f $target >/dev/null 2>&1 || true
}

plat_paste_files() {
  reported_sample GR7 'file url paste' 'not applicable on Android'
}

plat_paste_mixed() {
  reported_sample GR7 'mixed text and file paste' 'not applicable on Android'
}

plat_drop_files() {
  reported_sample GR7 'file drop' 'not applicable on Android'
}

plat_ime() {
  local keyboard=$1 pattern
  case $keyboard in
    gboard) pattern='com.google.android.inputmethod.latin' ;;
    samsung) pattern='com.samsung.android.honeyboard' ;;
    *) print -u2 -r -- "drive: unknown keyboard $keyboard"; return 2 ;;
  esac
  local id
  id=$(adb_shell ime list -s | tr -d '\r' | grep -m1 -- $pattern) || { print -u2 -r -- "drive: $keyboard is not installed"; return 1; }
  adb_shell ime set $id >/dev/null
  keymap_load $keyboard || true
}

plat_ime_insert_image() {
  local keyboard=$1
  plat_ime $keyboard
  if [[ -z $KEYMAP_NAME ]]; then
    return 1
  fi
  keymap_tap emoji
  plat_owner_step "open the image or GIF tab of the $keyboard keyboard and choose any image"
}

plat_speech_last() {
  adb_run logcat -d -v raw -s TalkBack:V 2>/dev/null | tr -d '\r' | grep -i 'speak' | tail -1 | sed -e 's/^.*[Ss]peak[a-zA-Z]*[^:]*: *//'
}

keymap_missing_sample() {
  local row=$1 name=$2
  expect_sample $row "$name" '{"keyMap":true}' '{"keyMap":false,"reason":"key map not recorded"}'
}

plat_ime_cases() {
  local keyboard
  for keyboard in gboard samsung; do
    if ! plat_ime $keyboard; then
      expect_sample GB7 "$keyboard keyboard" '{"installed":true}' '{"installed":false}'
      continue
    fi
    if [[ -z $KEYMAP_NAME ]]; then
      local name
      for name in 'on-screen key taps' 'autocorrect' 'suggestion strip' 'long-press accents' 'swipe typing' 'japanese composition' 'chinese composition' 'voice typing'; do
        keymap_missing_sample GB7 "$keyboard $name"
      done
      continue
    fi
    ime_fixture
    probe_get 'log?clear=1' >/dev/null
    plat_type harbour
    sleep 0.4
    ime_expect "$keyboard on-screen key taps" 'fog harbour'
    ime_fixture
    probe_get 'log?clear=1' >/dev/null
    plat_type 'teh '
    sleep 0.4
    ime_committed_expect "$keyboard autocorrect"
    ime_fixture
    probe_get 'log?clear=1' >/dev/null
    plat_type harb
    plat_owner_step "tap the first word in the $keyboard suggestion strip"
    sleep 0.4
    ime_committed_expect "$keyboard suggestion strip"
    ime_fixture
    probe_get 'log?clear=1' >/dev/null
    local point=${KEYMAP[e]}
    adb_shell input swipe ${=point} ${=point} 900
    plat_owner_step "choose any accented e in the $keyboard long-press popup"
    sleep 0.4
    ime_committed_expect "$keyboard long-press accents" non-ascii
    ime_fixture
    probe_get 'log?clear=1' >/dev/null
    plat_swipe_type harbour
    sleep 0.6
    ime_committed_expect "$keyboard swipe typing"
    plat_owner_step "switch the $keyboard keyboard to Japanese"
    ime_fixture
    probe_get 'log?clear=1' >/dev/null
    plat_type nihongo
    plat_owner_step 'convert and commit the composition'
    sleep 0.4
    ime_committed_expect "$keyboard japanese composition" non-ascii
    plat_owner_step "switch the $keyboard keyboard to Chinese (Pinyin)"
    ime_fixture
    probe_get 'log?clear=1' >/dev/null
    plat_type womenzaihaibian
    plat_owner_step 'choose the conversion and commit it'
    sleep 0.4
    ime_committed_expect "$keyboard chinese composition" non-ascii
    plat_owner_step "switch the $keyboard keyboard back to English"
    ime_fixture
    probe_get 'log?clear=1' >/dev/null
    keymap_tap voice
    plat_owner_step 'speak the five-sentence script, then stop voice typing'
    sleep 1
    ime_committed_expect "$keyboard voice typing"
  done
}

plat_image_insert_cases() {
  local caret_case=$1 png=$PROBE_WORK/insert.png
  probe_get shot > $png
  gr7_prepare "$caret_case"
  gr7_begin
  plat_paste_image $png png
  gr7_finish "$caret_case clipboard image uri" 1 ''
  local keyboard
  for keyboard in gboard samsung; do
    gr7_prepare "$caret_case"
    gr7_begin
    if plat_ime_insert_image $keyboard; then
      gr7_finish "$caret_case $keyboard image insertion" 1 ''
    else
      keymap_missing_sample GR7 "$caret_case $keyboard image insertion"
    fi
  done
}

plat_a11y_cases() {
  plat_owner_step 'enable TalkBack and its speech output logging (TalkBack settings, Advanced, Developer settings, Log speech output)'
  a11y_open $'# Harbour day\nThe **fog** lifted at noon.\n\n- [ ] passport\n\n![Low tide](photo/'"$(fixture_ref 1)"$' "right medium")\n\nLast line.' 0 '["Photo, Low tide"]' '["passport"]'
  plat_owner_step 'use TalkBack read from top (swipe down then right) and wait until it finishes'
  a11y_expect 'read the note' 'Harbour day'
  a11y_select 14
  plat_owner_step 'with TalkBack reading controls set to characters, swipe down once'
  a11y_expect 'move by character' 'h'
  plat_owner_step 'set the reading control to words and swipe down once'
  a11y_expect 'move by word' 'fog'
  a11y_select 0
  plat_owner_step 'set the reading control to lines and swipe down once'
  a11y_expect 'move by line' 'The fog lifted at noon.' reported
  a11y_select 14
  plat_owner_step 'select the next word with the TalkBack selection gesture'
  a11y_expect 'select a word' 'The'
  plat_key backspace
  plat_type Grey
  a11y_expect 'delete and type a word' 'Grey'
  plat_owner_step 'swipe right to the passport checkbox and double-tap it'
  a11y_expect 'toggle a checkbox' 'passport'
  plat_owner_step 'swipe right to the photo and double-tap it'
  a11y_expect 'reach and select a photo' 'Photo, Low tide'
  plat_owner_step 'turn TalkBack off'
}

touch_device() {
  adb_shell getevent -p | tr -d '\r' | awk '
    /^add device/ { device = $NF }
    /ABS_MT_POSITION_X|0035/ { if (device != "") { print device; exit } }
  '
}

axis_max() {
  local device=$1 axis=$2
  adb_shell getevent -p $device | tr -d '\r' | awk -v axis=$axis '
    $0 ~ axis { for (i = 1; i <= NF; i++) if ($i == "max") { value = $(i + 1); sub(/,$/, "", value); print value; exit } }
  '
}

record_keymap() {
  local keyboard=$1
  case $keyboard in
    gboard|samsung) ;;
    *) print -u2 -r -- 'usage: drive.sh record-keymap gboard|samsung'; return 2 ;;
  esac
  local device max_x max_y size width height model
  device=$(touch_device)
  [[ -n $device ]] || { print -u2 -r -- 'drive: no touchscreen found in getevent -p'; return 1; }
  max_x=$(axis_max $device '0035|ABS_MT_POSITION_X')
  max_y=$(axis_max $device '0036|ABS_MT_POSITION_Y')
  size=$(adb_shell wm size | tr -d '\r' | awk -F': ' '/Physical size/ { print $2 }')
  width=${size%x*}
  height=${size#*x}
  model=$(adb_shell getprop ro.product.model | tr -d '\r')
  plat_ime $keyboard || return 1
  local capture=${TMPDIR:-/tmp}/field_notes_keymap.$$
  local -a entries=()
  local key
  for key in $KEYMAP_REQUIRED; do
    : > $capture
    adb_shell getevent -lt $device > $capture 2>/dev/null &
    local reader=$!
    plat_owner_step "with the $keyboard keyboard open in portrait, tap the key: $key"
    kill $reader 2>/dev/null || true
    wait $reader 2>/dev/null || true
    local raw_x raw_y
    raw_x=$(tr -d '\r' < $capture | awk '/ABS_MT_POSITION_X/ { value = $NF } END { print value }')
    raw_y=$(tr -d '\r' < $capture | awk '/ABS_MT_POSITION_Y/ { value = $NF } END { print value }')
    if [[ -z $raw_x || -z $raw_y ]]; then
      print -u2 -r -- "drive: no touch was recorded for $key"
      return 1
    fi
    local -i x=$(( 16#$raw_x * width / (max_x + 1) )) y=$(( 16#$raw_y * height / (max_y + 1) ))
    entries+=("$(json_str $key):[$x,$y]")
  done
  rm -f $capture
  mkdir -p $KEYMAP_DIR
  print -r -- "{\"keyboard\":$(json_str $keyboard),\"device\":$(json_str "$model"),\"screen\":[$width,$height],\"orientation\":\"portrait\",\"keys\":{${(j:,:)entries}}}" > $KEYMAP_DIR/$keyboard.json
  print -r -- "drive: wrote $KEYMAP_DIR/$keyboard.json"
}

android_main() {
  case ${1:-} in
    --list|--check|--library)
      drive_main "$@"
      return $?
      ;;
    record-keymap)
      record_keymap ${2:-}
      return $?
      ;;
  esac
  if (( $# == 3 )) && (( ${PROBE_SCENARIOS[(Ie)$1]} )); then
    FONT_SCALE_SAVED=$(adb_shell settings get system font_scale | tr -d '\r') || FONT_SCALE_SAVED=
    IME_SAVED=$(adb_shell settings get secure default_input_method | tr -d '\r') || IME_SAVED=
    local -i android_status=0
    {
      drive_main "$@" &
      wait $! || android_status=$?
    } always {
      font_scale_restore
      ime_restore
    }
    return $android_status
  fi
  drive_main "$@"
}

if [[ ${1:-} == --library ]]; then
  return 0
fi

android_main "$@"
exit $?
