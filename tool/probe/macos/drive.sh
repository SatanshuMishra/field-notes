#!/bin/zsh
setopt err_exit no_unset pipe_fail

zmodload zsh/datetime
zmodload zsh/mathfunc

typeset -g PROBE_MACOS_DIR=${${(%):-%x}:A:h}
typeset -g PROBE_REPO=${PROBE_MACOS_DIR:h:h:h}
typeset -g PROBE_BIN=${PROBE_BIN:-$PROBE_REPO/build/probe/bin}
typeset -g PROBE_APPS=${PROBE_APPS:-$PROBE_REPO/build/probe/macos}
typeset -g PROBE_BASE=${PROBE_BASE:-http://127.0.0.1:47111}
typeset -g CORPUS_DIR=$PROBE_REPO/integration_test/probe/corpus
typeset -g PROBE_PROCESS=field_notes_probe
typeset -g PROBE_BUILD=${PROBE_BUILD:-profile}
typeset -g PROBE_WORK=${PROBE_WORK:-}
typeset -g ORIGIN_X=
typeset -g ORIGIN_Y=
typeset -g VIEW_W=
typeset -g VIEW_H=
typeset -g PROBE_PID=
typeset -g PROBE_TTY=${PROBE_TTY:-/dev/tty}
typeset -g OPENED_ENTRY=
typeset -g OPENED_COUNT=
typeset -g RESULT_FILE=
typeset -gi RESULT_COUNT=0
typeset -gi RESULT_DISCARD=0
typeset -g REPLY=

typeset -ga PROBE_SCENARIOS=(
  table-matrix
  spell-matrix
  perf-keystroke
  perf-scroll
  perf-idle
  perf-open
  styling-ceiling
  round-trip
  side-edit-audit
  held-clicks
  monkey
  undo-matrix
  photo-move-matrix
  photo-insert-matrix
  draft-recovery
  caret-audit
  selection-audit
  click-sweep
  vertical-sweep
  placement-matrix
  keyboard-matrix
  ime-matrix
  a11y-matrix
  window-scale-matrix
  reader-parity
  toolbar-placement
  perf-memory
)

typeset -ga PROBE_PRIMITIVES=(
  plat_name
  plat_launch
  plat_kill
  plat_origin
  plat_click
  plat_right_click
  plat_drag
  plat_scroll
  plat_key
  plat_type
  plat_timed_type
  plat_clock_pair
  plat_cpu
  plat_cpu_format
  plat_rss
  plat_paste_image
  plat_paste_files
  plat_paste_mixed
  plat_drop_files
  plat_owner_step
  plat_front
  plat_speech_last
  plat_text_scales
  plat_set_text_scale
  plat_columns
  plat_reveal_budget_ms
)

typeset -ga PROBE_CASE_HOOKS=(
  plat_ime_cases
  plat_image_insert_cases
  plat_a11y_cases
)

typeset -g PROBE_TYPING_UNIT='the tide came in slowly over the flat grey sand and the gulls lifted from the pier '
typeset -g PROBE_TYPING_TEXT=${${:-$PROBE_TYPING_UNIT$PROBE_TYPING_UNIT$PROBE_TYPING_UNIT$PROBE_TYPING_UNIT}[1,264]}

typeset -gA MAC_KEYCODES=(
  a 0 s 1 d 2 f 3 h 4 g 5 z 6 x 7 c 8 v 9 b 11 q 12 w 13 e 14 r 15
  y 16 t 17 1 18 2 19 3 20 4 21 6 22 5 23 '=' 24 9 25 7 26 '-' 27 8 28
  0 29 ']' 30 o 31 u 32 '[' 33 i 34 p 35 l 37 j 38 "'" 39 k 40 ';' 41
  '\' 42 ',' 43 '/' 44 n 45 m 46 '.' 47 '`' 50
  enter 36 return 36 tab 48 space 49 backspace 51 escape 53 kp_enter 76
  delete 117 home 115 end 119 pageup 116 pagedown 121
  left 123 right 124 down 125 up 126
)

plat_name() {
  print -r -- macos
}

plat_launch() {
  local build=${1:-$PROBE_BUILD}
  local app=$PROBE_APPS/$build/$PROBE_PROCESS.app/Contents/MacOS/$PROBE_PROCESS
  if [[ ! -x $app ]]; then
    print -u2 -r -- "drive: no $build probe at $app"
    return 2
  fi
  "$app" >/dev/null 2>&1 &!
  probe_wait 90
  ORIGIN_X=
  ORIGIN_Y=
  PROBE_PID=
}

plat_kill() {
  local pid
  pid=$(probe_get pid | json_get pid) || return 0
  if [[ ${1:-} == --hide ]]; then
    osascript -e "tell application \"System Events\" to set visible of process \"$PROBE_PROCESS\" to false" >/dev/null 2>&1 || true
  fi
  kill -9 $pid 2>/dev/null || true
  local -i tries=0
  while (( tries < 50 )) && kill -0 $pid 2>/dev/null; do
    sleep 0.1
    (( tries += 1 ))
  done
  ORIGIN_X=
  ORIGIN_Y=
  PROBE_PID=
}

plat_origin() {
  local bounds view_height
  bounds=$(osascript -e "tell application \"System Events\" to tell process \"$PROBE_PROCESS\" to get {position, size} of window 1")
  view_height=$(probe_get 'state?text=0' | json_get view.height) || return 1
  local -a parts=(${(s:, :)bounds})
  local -F title=$(( parts[4] - view_height ))
  print -r -- "$parts[1] $(( parts[2] + title ))"
}

plat_click() {
  local x=$1 y=$2 hold=${3:-20} count=${4:-1} mods=${5:-none}
  origin_load
  point_inside $x $y || return $?
  "$PROBE_BIN/inp" click $(( ORIGIN_X + x )) $(( ORIGIN_Y + y )) $count ${mods:-none} $hold
}

plat_right_click() {
  origin_load
  point_inside $1 $2 || return $?
  "$PROBE_BIN/inp" rightclick $(( ORIGIN_X + $1 )) $(( ORIGIN_Y + $2 ))
}

plat_drag() {
  local mods=${5:-none} hover=${6:-0}
  origin_load
  point_inside $1 $2 || return $?
  point_inside $3 $4 || return $?
  "$PROBE_BIN/inp" drag $(( ORIGIN_X + $1 )) $(( ORIGIN_Y + $2 )) $(( ORIGIN_X + $3 )) $(( ORIGIN_Y + $4 )) ${mods:-none} 60 $hover
}

plat_scroll() {
  origin_load
  "$PROBE_BIN/inp" scroll $(( ORIGIN_X + $1 )) $(( ORIGIN_Y + $2 )) $3
}

plat_key() {
  probe_require_front || return $?
  local combo=$1 name=${1##*+} using=
  local -a mods=()
  [[ $combo == *+* ]] && mods=(${(s:+:)${combo%+*}})
  local mod
  for mod in $mods; do
    case $mod in
      cmd) using+="${using:+, }command down" ;;
      shift) using+="${using:+, }shift down" ;;
      opt) using+="${using:+, }option down" ;;
      ctrl) using+="${using:+, }control down" ;;
      *) print -u2 -r -- "drive: unknown modifier $mod in $combo"; return 2 ;;
    esac
  done
  local code=${MAC_KEYCODES[$name]:-}
  if [[ -z $code ]]; then
    print -u2 -r -- "drive: unknown key $combo"
    return 2
  fi
  if [[ -n $using ]]; then
    osascript -e "tell application \"System Events\" to key code $code using {$using}" >/dev/null
  else
    osascript -e "tell application \"System Events\" to key code $code" >/dev/null
  fi
}

plat_type() {
  probe_require_front || return $?
  osascript -e 'on run argv' -e 'tell application "System Events" to keystroke (item 1 of argv)' -e 'end run' -- "$1" >/dev/null
}

plat_timed_type() {
  probe_require_front || return $?
  "$PROBE_BIN/inp" type "$1"
}

plat_clock_pair() {
  local before after probe
  before=$("$PROBE_BIN/inp" now)
  probe=$(probe_get clock | json_get now) || return 1
  after=$("$PROBE_BIN/inp" now)
  print -r -- "$(( (before + after) / 2 )) $probe"
}

plat_cpu() {
  ps -o cputime= -p $1 | tr -d ' '
}

plat_cpu_format() {
  print -r -- ps
}

plat_rss() {
  local kilobytes
  kilobytes=$(ps -o rss= -p $1 | tr -d ' ')
  print -r -- $(( kilobytes * 1024 ))
}

plat_paste_image() {
  "$PROBE_BIN/pasteboard" image "$1" "$2"
  plat_key cmd+v
}

plat_paste_files() {
  "$PROBE_BIN/pasteboard" files "$@"
  plat_key cmd+v
}

plat_paste_mixed() {
  local text=$1
  shift
  "$PROBE_BIN/pasteboard" mixed "$text" "$@"
  plat_key cmd+v
}

plat_drop_files() {
  local x=$1 y=$2
  shift 2
  origin_load
  "$PROBE_BIN/drag_files" drag $(( ORIGIN_X - 30 )) $(( ORIGIN_Y + y )) $(( ORIGIN_X + x )) $(( ORIGIN_Y + y )) --hover 400 "$@"
}

plat_owner_step() {
  print -r -- "owner step: $1" >>$PROBE_TTY
  print -rn -- "press Enter when done " >>$PROBE_TTY
  local answer
  read -r answer <$PROBE_TTY
  plat_front
}

plat_front() {
  probe_activate && return 0
  print -u2 -r -- 'drive: the probe could not be brought to the front'
  return 3
}

pid_load() {
  [[ -n $PROBE_PID ]] && return 0
  local pid
  pid=$(probe_get pid | json_get pid) || return 1
  PROBE_PID=$pid
}

probe_frontmost() {
  pid_load || return 1
  local front
  front=$(lsappinfo info -only pid "$(lsappinfo front)" 2>/dev/null) || return 1
  [[ ${front##*=} == $PROBE_PID ]]
}

probe_activate() {
  pid_load || return 1
  osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $PROBE_PID) to true" >/dev/null 2>&1 || true
  local -i tries
  for (( tries = 0; tries < 20; tries++ )); do
    probe_frontmost && return 0
    sleep 0.1
  done
  return 1
}

probe_require_front() {
  probe_frontmost && return 0
  probe_activate && return 0
  print -u2 -r -- 'drive: the probe is not the frontmost app, so no key was sent'
  return 3
}

plat_speech_last() {
  osascript -e 'tell application "VoiceOver" to return content of last phrase' 2>/dev/null
}

plat_text_scales() {
  print -rl -- 1.0 2.0
}

plat_set_text_scale() {
  if [[ $1 == 1 || $1 == 1.0 ]]; then
    probe_post 'flags?scaler=off' >/dev/null
  else
    probe_post "flags?scaler=$1" >/dev/null
  fi
  ORIGIN_X=
  ORIGIN_Y=
}

plat_columns() {
  case $1 in
    small) print -rl -- 560 600 648 ;;
    medium) print -rl -- 560 600 648 688 720 ;;
    large) print -rl -- 560 600 648 688 720 768 828 ;;
    *) print -u2 -r -- "drive: unknown text size $1"; return 2 ;;
  esac
}

plat_reveal_budget_ms() {
  print -r -- 150
}

plat_ime_cases() {
  local -a dead=(
    'acute|opt+e|e|é'
    'grave|opt+`|e|è'
    'circumflex|opt+i|e|ê'
    'umlaut|opt+u|u|ü'
    'tilde|opt+n|n|ñ'
  )
  local entry name combo letter accent
  for entry in $dead; do
    IFS='|' read -r name combo letter accent <<< "$entry"
    ime_fixture
    probe_get 'log?clear=1' >/dev/null
    plat_key $combo
    plat_key $letter
    sleep 0.3
    ime_expect "dead key $name" "fog $accent"
  done
  ime_fixture
  probe_require_front
  "$PROBE_BIN/inp" key ${MAC_KEYCODES[e]} none 900 >/dev/null
  sleep 0.3
  plat_key 2
  sleep 0.3
  ime_expect 'press and hold accent' $'fog é'
  plat_owner_step 'switch the input source to Japanese (Romaji)'
  ime_fixture
  probe_get 'log?clear=1' >/dev/null
  plat_type 'nihongowobenkyousuru'
  plat_key space
  plat_key space
  plat_key enter
  sleep 0.5
  ime_committed_expect 'japanese multi-phrase conversion' non-ascii
  plat_owner_step 'switch the input source to Chinese (Pinyin - Simplified)'
  ime_fixture
  probe_get 'log?clear=1' >/dev/null
  plat_type 'womenzaihaibian'
  plat_key space
  sleep 0.5
  ime_committed_expect 'pinyin multi-phrase conversion' non-ascii
  plat_owner_step 'switch the input source back to ABC or U.S.'
  ime_fixture
  probe_get 'log?clear=1' >/dev/null
  plat_key ctrl+cmd+space
  plat_owner_step 'pick any emoji in the emoji picker'
  sleep 0.5
  ime_committed_expect 'emoji picker' non-ascii
  ime_fixture
  probe_get 'log?clear=1' >/dev/null
  plat_owner_step 'start dictation (press the dictation key twice), speak the five-sentence script, then stop dictation'
  sleep 1
  ime_committed_expect 'dictation script'
}

plat_image_insert_cases() {
  local caret_case=$1 png=$PROBE_WORK/insert.png
  probe_get shot > $png
  local format
  for format in png tiff jpeg heic; do
    local file=$PROBE_WORK/insert.$format
    [[ $format == png ]] || sips -s format $format $png --out $file >/dev/null
    gr7_prepare $caret_case
    gr7_begin
    plat_paste_image $file $format
    gr7_finish "$caret_case pasteboard $format" 1 ''
  done
  gr7_prepare $caret_case
  gr7_begin
  plat_paste_files $png
  gr7_finish "$caret_case file url paste" 1 ''
  gr7_prepare $caret_case
  gr7_begin
  plat_paste_mixed 'ignored text' $png
  gr7_finish "$caret_case mixed text and file paste" 1 ''
  local note=$PROBE_WORK/skipped.txt
  print -r -- 'not a photo' > $note
  cp $png $PROBE_WORK/second.png
  cp $png $PROBE_WORK/third.png
  gr7_prepare $caret_case
  gr7_begin
  gr7_drop_target
  plat_drop_files $GR7_DROP_X $GR7_DROP_Y $png
  gr7_finish "$caret_case finder drop of one image" 1 '' drop
  gr7_prepare $caret_case
  gr7_begin
  gr7_drop_target
  plat_drop_files $GR7_DROP_X $GR7_DROP_Y $png $PROBE_WORK/second.png $PROBE_WORK/third.png $note
  gr7_finish "$caret_case finder drop of three images and a text file" 3 '1 file skipped' drop
}

plat_a11y_cases() {
  plat_owner_step 'enable VoiceOver (Cmd+F5) and allow VoiceOver to be controlled with AppleScript'
  a11y_open $'# Harbour day\nThe **fog** lifted at noon.\n\n- [ ] passport\n\n![Low tide](photo/'"$(fixture_ref 1)"$' "right medium")\n\nLast line.' 0 '["Photo, Low tide"]' '["passport"]'
  plat_key ctrl+opt+a
  sleep 4
  a11y_expect 'read the note' 'Harbour day'
  a11y_select 14
  plat_key right
  a11y_expect 'move by character' 'h'
  plat_key opt+right
  a11y_expect 'move by word' 'fog'
  a11y_select 0
  plat_key down
  a11y_expect 'move by line' 'The fog lifted at noon.'
  a11y_select 14
  plat_key shift+opt+right
  a11y_expect 'select a word' 'The'
  plat_key backspace
  plat_type 'Grey'
  a11y_expect 'delete and type a word' 'Grey'
  plat_key ctrl+opt+right
  plat_key ctrl+opt+space
  a11y_expect 'toggle a checkbox' 'passport'
  plat_key ctrl+opt+right
  plat_key ctrl+opt+space
  a11y_expect 'reach and select a photo' 'Photo, Low tide'
  plat_owner_step 'turn VoiceOver off (Cmd+F5)'
}

probe_get() {
  curl -sS -f --max-time 60 -- "$PROBE_BASE/$1"
}

probe_post() {
  if (( $# >= 2 )); then
    curl -sS -f --max-time 60 -X POST -H 'Content-Type: text/plain; charset=utf-8' --data-binary "@$2" -- "$PROBE_BASE/$1"
  else
    curl -sS -f --max-time 60 -X POST -- "$PROBE_BASE/$1"
  fi
}

json_get() {
  plutil -extract "$1" raw -o - - 2>/dev/null
}

jget() {
  print -r -- "$1" | json_get "$2"
}

jget_exact() {
  local out
  out=$(print -r -- "$1" | json_get "$2" && print -n x) || return 1
  out=${out%x}
  REPLY=${out%$'\n'}
}

jcount() {
  local count
  if count=$(jget "$1" "$2"); then
    print -r -- $count
  else
    print -r -- 0
  fi
}

json_str() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  s=${s//$'\b'/\\b}
  s=${s//$'\f'/\\f}
  if [[ $s == *[[:cntrl:]]* ]]; then
    local out= char
    local -i index
    for (( index = 1; index <= ${#s}; index++ )); do
      char=${s[index]}
      if [[ $char == [[:cntrl:]] ]]; then
        out+=$(printf '\\u%04x' "'$char")
      else
        out+=$char
      fi
    done
    s=$out
  fi
  print -rn -- "\"$s\""
}

url_encode() {
  local LC_ALL=C text=$1 out= char
  local -i index
  for (( index = 1; index <= ${#text}; index++ )); do
    char=${text[index]}
    case $char in
      [a-zA-Z0-9._~-]) out+=$char ;;
      *) out+=$(printf '%%%02X' "'$char") ;;
    esac
  done
  print -rn -- $out
}

json_lines_array() {
  local -a items=("${(@f)1}")
  local joined=${(j:,:)items}
  print -rn -- "[$joined]"
}

probe_wait() {
  local -i limit=${1:-90} waited=0
  while (( waited < limit * 10 )); do
    if probe_get pid >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
    (( waited += 1 ))
  done
  print -u2 -r -- "drive: the probe did not answer within $limit s"
  return 1
}

origin_load() {
  if [[ -z $ORIGIN_X || -z $ORIGIN_Y ]]; then
    local origin
    origin=$(plat_origin)
    ORIGIN_X=${origin%% *}
    ORIGIN_Y=${origin##* }
    VIEW_W=
    VIEW_H=
  fi
}

view_load() {
  [[ -n $VIEW_W && -n $VIEW_H ]] && return 0
  local state width height
  state=$(probe_get 'state?text=0') || return 1
  width=$(jget "$state" view.width) && height=$(jget "$state" view.height) || return 1
  VIEW_W=$width
  VIEW_H=$height
}

point_inside() {
  view_load || return 1
  local -F x=$1 y=$2
  if (( x < 0 || y < 0 || x >= VIEW_W || y >= VIEW_H )); then
    print -u2 -r -- "drive: refusing to press at $x $y, outside the ${VIEW_W} x ${VIEW_H} probe window"
    return 3
  fi
}

sleep_ms() {
  sleep $(( $1 / 1000.0 ))
}

now_ms() {
  print -r -- $(( int(EPOCHREALTIME * 1000) ))
}

state_get() {
  probe_get "state${1:+?$1}"
}

rect_json() {
  local l t w h
  l=$(jget "$1" "$2.0") && t=$(jget "$1" "$2.1") && w=$(jget "$1" "$2.2") && h=$(jget "$1" "$2.3") || return 1
  print -rn -- "[$l,$t,$w,$h]"
}

rect_center() {
  local l t w h
  l=$(jget "$1" "$2.0") && t=$(jget "$1" "$2.1") && w=$(jget "$1" "$2.2") && h=$(jget "$1" "$2.3") || return 1
  print -r -- "$(( l + w / 2.0 )) $(( t + h / 2.0 ))"
}

key_center() {
  local keys
  keys=$(probe_get "keys?prefix=$(url_encode $1)") || return 1
  rect_center "$keys" "$1"
}

press_key() {
  local center
  center=$(key_center $1) || return 1
  plat_click ${center%% *} ${center##* } ${2:-110}
}

key_present() {
  local found
  found=$(probe_get "find?key=$(url_encode $1)") || return 1
  (( $(jcount "$found" rects) > 0 ))
}

text_present() {
  local found
  found=$(probe_get "find?text=$(url_encode $1)") || return 1
  (( $(jcount "$found" rects) > 0 ))
}

bool_json() {
  if "$@"; then
    print -rn -- true
  else
    print -rn -- false
  fi
}

errors_total() {
  local errors
  errors=$(probe_get ${1:-errors}) || return 1
  print -r -- $(( $(jcount "$errors" errors) + $(jcount "$errors" drops) ))
}

is_phone_column() {
  local state column em
  state=$(state_get text=0)
  column=$(jget "$state" column) && em=$(jget "$state" em) || return 1
  (( column < 30 * em ))
}

fixture_ref() {
  awk -v want=${1:-1} '
    /^## Media/ { media = 1; next }
    /^## / { media = 0 }
    media && /^\| [0-9a-f]+ \|/ { count++; if (count == want) { print $2; exit } }
  ' $CORPUS_DIR/README.md
}

fixture_media() {
  awk '
    /^## Media/ { media = 1; next }
    /^## / { media = 0 }
    media && /^\| [0-9a-f]+ \|/ { entries = entries (entries == "" ? "" : ",") $2 ":" $4 ":" $6 }
    END { print entries }
  ' $CORPUS_DIR/README.md
}

photo_line() {
  print -rn -- "![${3:-}](photo/$(fixture_ref ${1:-1})${2:+ \"$2\"})"
}

write_text() {
  print -rn -- "$2" > $1
}

open_text() {
  local surface=$1 text=$2 file=$PROBE_WORK/open.md reply
  write_text $file "$text"
  reply=$(probe_post "open?surface=$surface&id=fixture&media=$(fixture_media)" $file)
  opened_from "$reply"
}

open_entry() {
  local surface=$1 id=$2 reply
  reply=$(probe_post "open?surface=$surface&entry=$(url_encode $id)&media=$(fixture_media)")
  opened_from "$reply"
}

opened_from() {
  local reply=$1
  OPENED_ENTRY=$(jget "$reply" entryId) || OPENED_ENTRY=
  OPENED_COUNT=$(jget "$reply" entryCount) || OPENED_COUNT=
  ORIGIN_X=
  ORIGIN_Y=
}

open_note() {
  local id=$1 surface=${2:-composer} media=${3:-}
  local file=$PROBE_WORK/$id.md
  corpus_note $id $file
  [[ -n $media ]] || media=$(corpus_media $id)
  probe_post "open?surface=$surface&id=$id&media=$media" $file >/dev/null
  ORIGIN_X=
  ORIGIN_Y=
}

set_text() {
  local file=$PROBE_WORK/set.md
  write_text $file "$1"
  if [[ -n ${2:-} ]]; then
    probe_post "set?base=$2&extent=${3:-$2}" $file >/dev/null
  else
    probe_post set $file >/dev/null
  fi
}

select_range() {
  probe_post "select?base=$1&extent=${2:-$1}&affinity=${3:-downstream}" >/dev/null
}

focus_editor() {
  probe_post focus >/dev/null
}

select_photo() {
  local state center
  state=$(state_get text=0)
  center=$(rect_center "$state" "photos.${1:-0}.rect") || return 1
  plat_click ${center%% *} ${center##* } 60
  sleep 0.2
}

corpus_ids() {
  awk '
    /^## Index/ { index_table = 1; next }
    /^## / { index_table = 0 }
    index_table && /^\|/ {
      split($0, cells, "|")
      id = cells[2]
      gsub(/[ \t]/, "", id)
      if (id ~ /^c[0-9]+-p[0-9]+$/) print id
    }
  ' $CORPUS_DIR/README.md
}

corpus_note() {
  local id=$1 file=$2
  if ! corpus_ids | grep -qx -- "$id"; then
    print -u2 -r -- "drive: $id is not a corpus note"
    exit 2
  fi
  cp -- $CORPUS_DIR/$id.md $file
}

corpus_media() {
  local id=$1
  if ! corpus_ids | grep -qx -- "$id"; then
    print -u2 -r -- "drive: $id is not a corpus note"
    exit 2
  fi
  local refs
  refs=$( { grep -o 'photo/[0-9a-f]\{12\}' $CORPUS_DIR/$id.md || true; } | sed 's|^photo/||' | awk '!seen[$0]++')
  [[ -n $refs ]] || return 0
  print -r -- "$refs" | awk -v readme=$CORPUS_DIR/README.md '
    BEGIN {
      while ((getline line < readme) > 0) {
        if (line ~ /^## Media/) { media = 1; continue }
        if (line ~ /^## /) { media = 0 }
        if (media && line ~ /^\| [0-9a-f]+ \|/) {
          split(line, cells, "|")
          ref = cells[2]; width = cells[3]; height = cells[4]
          gsub(/[ \t]/, "", ref); gsub(/[ \t]/, "", width); gsub(/[ \t]/, "", height)
          sizes[ref] = width ":" height
        }
      }
    }
    { if ($0 in sizes) { out = out (out == "" ? "" : ",") $0 ":" sizes[$0] } }
    END { print out }
  '
}

result_begin() {
  RESULT_FILE=$3
  RESULT_COUNT=0
  RESULT_DISCARD=0
  local commit
  commit=$(git -C $PROBE_REPO rev-parse HEAD)
  mkdir -p ${RESULT_FILE:h}
  print -rn -- "{\"scenario\":$(json_str $1),\"platform\":$(json_str $(plat_name)),\"build\":$(json_str $2),\"commit\":$(json_str $commit),\"samples\":[" > $RESULT_FILE
}

sample() {
  (( RESULT_DISCARD )) && return 0
  [[ -n $RESULT_FILE ]] || return 0
  if (( RESULT_COUNT > 0 )); then
    print -rn -- "," >> $RESULT_FILE
  fi
  print -rn -- "$1" >> $RESULT_FILE
  (( RESULT_COUNT += 1 ))
}

result_end() {
  print -r -- "]}" >> $RESULT_FILE
}

expect_sample() {
  local row=$1 name=$2 expected=$3 observed=$4 extra=${5:-}
  sample "{\"row\":\"$row\",\"kind\":\"expect\",\"case\":$(json_str $name),\"expected\":$expected,\"observed\":$observed$extra}"
}

reported_sample() {
  local row=$1 name=$2 reason=$3
  sample "{\"row\":\"$row\",\"kind\":\"expect\",\"case\":$(json_str $name),\"reportedOnly\":true,\"reason\":$(json_str $reason),\"expected\":{},\"observed\":{}}"
}

errors_sample() {
  local row=$1 name=$2 endpoint=${3:-errors?clear=1} extra=${4:-} errors
  errors=$(probe_get $endpoint)
  sample "{\"row\":\"$row\",\"kind\":\"errors\",\"case\":$(json_str $name),\"errors\":$errors$extra}"
}

settle() {
  sleep_ms ${1:-2000}
}

scroll_to_top() {
  local state width height offset
  state=$(state_get text=0)
  width=$(jget "$state" view.width) && height=$(jget "$state" view.height) || return 1
  offset=$(jget "$state" scroll.offset) || return 1
  local -i step
  for (( step = 0; step < 400 && offset > 0.5; step++ )); do
    plat_scroll $(( width / 2.0 )) $(( height / 2.0 )) 2000
    sleep 0.05
    offset=$(jget "$(state_get text=0)" scroll.offset) || return 1
  done
}

scroll_through() {
  local -i step_px=${1:-120}
  local state width height offset max
  state=$(state_get text=0)
  width=$(jget "$state" view.width) && height=$(jget "$state" view.height) || return 1
  local -F previous=-1
  local -i step stalls=0
  for (( step = 0; step < 20000; step++ )); do
    plat_scroll $(( width / 2.0 )) $(( height / 2.0 )) $(( -step_px ))
    sleep 0.016
    if (( step % 20 == 19 )); then
      state=$(state_get text=0)
      offset=$(jget "$state" scroll.offset) && max=$(jget "$state" scroll.max) || return 1
      (( offset >= max - 0.5 )) && return 0
      if (( offset <= previous + 0.5 )); then
        (( stalls += 1 ))
        (( stalls >= 3 )) && return 0
      else
        stalls=0
      fi
      previous=$offset
    fi
  done
}

glyph_rect() {
  local boxes=$1 index
  index=$(jget "$boxes" firstSelected) || return 1
  rect_json "$boxes" glyphs.$index.rect
}

surface_bounds() {
  local state=$1 bounds
  if bounds=$(rect_json "$state" writingSurface); then
    print -r -- "$bounds"
  else
    print -r -- "[0,0,$(jget "$state" view.width),$(jget "$state" view.height)]"
  fi
}

glyph_in_view() {
  local -i offset=$1 attempt
  local state bounds boxes rect
  state=$(state_get text=0)
  bounds=$(surface_bounds "$state") || return 1
  local -F surface_top=$(jget "$bounds" 1) surface_height=$(jget "$bounds" 3)
  local -F surface_left=$(jget "$bounds" 0) surface_width=$(jget "$bounds" 2)
  local -F surface_bottom=$(( surface_top + surface_height ))
  for (( attempt = 0; attempt < 30; attempt++ )); do
    boxes=$(probe_get "boxes?from=$offset&to=$(( offset + 1 ))") || return 1
    rect=$(glyph_rect "$boxes") || return 1
    local -F top=$(jget "$rect" 1) height=$(jget "$rect" 3)
    if (( top >= surface_top && top + height <= surface_bottom )); then
      print -r -- "$rect"
      return 0
    fi
    local -F delta=$(( top + height / 2.0 - (surface_top + surface_height / 2.0) ))
    (( delta > 2000 )) && delta=2000
    (( delta < -2000 )) && delta=-2000
    plat_scroll $(( surface_left + surface_width / 2.0 )) $(( surface_top + surface_height / 2.0 )) $(( -delta ))
    sleep 0.1
  done
  return 1
}

click_glyph() {
  local -i offset=$1
  local hold=${2:-60} rect
  rect=$(glyph_in_view $offset) || return 1
  local center
  center=$(rect_center "{\"r\":$rect}" r) || return 1
  plat_click ${center%% *} ${center##* } $hold
}

typing_offset() {
  local found
  found=$(probe_get 'find?text=tidemark') || return 1
  jget "$found" offsets.0.1
}

state_kinds() {
  local state=$1
  local -i count index
  count=$(jcount "$state" blocks)
  local -a kinds=()
  for (( index = 0; index < count; index++ )); do
    kinds+=("$(json_str "$(jget "$state" blocks.$index.kind)")")
  done
  print -rn -- "[${(j:,:)kinds}]"
}

transactions_of() {
  jget "$1" transactions
}

selection_json() {
  local base extent
  base=$(jget "$1" selection.0) && extent=$(jget "$1" selection.1) || return 1
  print -rn -- "[$base,$extent]"
}

photo_count() {
  jcount "$1" photos
}

case_run() {
  local row=$1 name=$2 fixture=$3 base=$4 extent=$5 expected_source=$6 expected_selection=$7 expected_focus=${8:-true}
  shift 8
  set_text "$fixture" $base $extent
  focus_editor
  select_range $base $extent
  sleep 0.1
  local step
  for step in "$@"; do
    case $step in
      type:*) plat_type "${step#type:}" ;;
      key:*) plat_key "${step#key:}" ;;
      press:*) press_key "${step#press:}" ;;
      photo:*) select_photo "${step#photo:}" ;;
      clickat:*) click_glyph "${step#clickat:}" ;;
      *) print -u2 -r -- "drive: unknown step $step"; return 2 ;;
    esac
    sleep 0.08
  done
  sleep 0.2
  local state
  state=$(state_get)
  local photo_expected=
  if [[ $expected_selection == PHOTO_SELECTED ]]; then
    photo_expected=',"photoSelected":0'
    expected_selection=
  fi
  local expected="{\"state\":{\"source\":$(json_str "$expected_source"),\"focused\":$expected_focus$photo_expected}"
  [[ -n $expected_selection ]] && expected+=",\"selection\":$expected_selection"
  expected+="}"
  expect_sample $row "$name" "$expected" "{\"state\":$state,\"selection\":$(selection_json "$state")}"
}

gfm_table_examples() {
  print -rn -- $'| foo | bar |\n| --- | --- |\n| baz | bim |'
  print -rn -- $'\x1e'
  print -rn -- $'| abc | defghi |\n:-: | -----------:\nbar | baz'
  print -rn -- $'\x1e'
  print -rn -- $'| f\\|oo  |\n| ------ |\n| b `\\|` az |\n| b **\\|** im |'
  print -rn -- $'\x1e'
  print -rn -- $'| abc | def |\n| --- | --- |\n| bar | baz |\n> bar'
  print -rn -- $'\x1e'
  print -rn -- $'| abc | def |\n| --- | --- |\n| bar | baz |\nbar\n\nbar'
  print -rn -- $'\x1e'
  print -rn -- $'| abc | def |\n| --- |\n| bar |'
  print -rn -- $'\x1e'
  print -rn -- $'| abc | def |\n| --- | --- |\n| bar |\n| bar | baz | boo |'
  print -rn -- $'\x1e'
  print -rn -- $'| abc | def |\n| --- | --- |'
}

scenario_table_matrix() {
  open_text new ''
  local -a sources=("${(@ps:\x1e:)$(gfm_table_examples)}")
  local -a kinds=(
    '["table"]'
    '["table"]'
    '["table"]'
    '["table","quote"]'
    '["table","paragraph"]'
    '["paragraph"]'
    '["table"]'
    '["table"]'
  )
  local -i index
  for (( index = 1; index <= ${#sources}; index++ )); do
    set_text "${sources[index]}" 0 0
    sleep 0.2
    local state
    state=$(state_get text=0)
    expect_sample GT1 "gfm example $(( 197 + index ))" "{\"blockKinds\":${kinds[index]}}" "{\"blockKinds\":$(state_kinds "$state")}"
  done
  local grid=$'|  |  |\n| --- | --- |\n|  |  |'
  case_run GT1 'T2 typing in an empty cell' "$grid" 2 2 $'| Day |  |\n| --- | --- |\n|  |  |' '' true type:Day
  case_run GT1 'T2 a typed pipe is escaped' "$grid" 2 2 $'| a\\|b |  |\n| --- | --- |\n|  |  |' '' true 'type:a|b'
  case_run GT1 'C5 tab moves to the next cell' "$grid" 2 2 "$grid" '[5,5]' true key:tab
  case_run GT1 'C5 shift tab moves to the previous cell' "$grid" 5 5 "$grid" '[2,2]' true key:shift+tab
  case_run GT1 'C5 tab in the last cell adds a row' "$grid" 30 30 $'|  |  |\n| --- | --- |\n|  |  |\n|  |  |' '' true key:tab
  case_run GT1 'C4 enter moves down a row' "$grid" 2 2 "$grid" '[27,27]' true key:enter
  local table=$'| a | b |\n| --- | --- |\n| c | d |'
  case_run GT1 'T3 column right' "$table" 2 2 $'| a |  | b |\n| --- | --- | --- |\n| c |  | d |' '' true press:table-toolbar-column-right
  case_run GT1 'T3 row below' "$table" 2 2 $'| a | b |\n| --- | --- |\n|  |  |\n| c | d |' '' true press:table-toolbar-row-below
  case_run GT1 'T3 align centre' "$table" 2 2 $'| a | b |\n| :---: | --- |\n| c | d |' '' true press:table-toolbar-align-centre
  case_run GT1 'T3 delete row' "$table" 28 28 $'| a | b |\n| --- | --- |' '' true press:table-toolbar-delete-row
  case_run GT1 'T3 delete table' "$table" 2 2 '' '' true press:table-toolbar-delete-table
  case_run GT1 'T4 table button in an empty note' '' 0 0 $'|  |  |  |\n| --- | --- | --- |\n|  |  |  |' '[2,2]' true press:format-table
  errors_sample GT1 'table matrix errors'
}

scenario_spell_matrix() {
  open_text new ''
  probe_post 'settings?spellCheck=1' >/dev/null
  set_text 'teh harbour' 11 11
  sleep 0.4
  local state
  state=$(state_get text=0)
  expect_sample GSP1 'SP2 teh harbour underlines teh' '{"misspelled":[[0,3]]}' "{\"misspelled\":$(spell_ranges "$state")}"
  local found center
  found=$(probe_get 'find?text=teh')
  if center=$(rect_center "$found" rects.0); then
    local before
    before=$(transactions_of "$(state_get text=0)")
    plat_right_click ${center%% *} ${center##* }
    sleep 0.4
    expect_sample GSP1 'SP3 context menu offers suggestions' '{"suggestion":true,"cut":true}' "{\"suggestion\":$(bool_json text_present the),\"cut\":$(bool_json text_present Cut)}"
    local choice
    choice=$(probe_get 'find?text=the')
    if center=$(rect_center "$choice" rects.0); then
      plat_click ${center%% *} ${center##* } 60
      sleep 0.3
    fi
    state=$(state_get)
    expect_sample GSP1 'SP3 choosing a suggestion is one spell transaction' "{\"state\":{\"source\":\"the harbour\"},\"transactionDelta\":1}" "{\"state\":$state,\"transactionDelta\":$(( $(transactions_of "$state") - before ))}"
  else
    expect_sample GSP1 'SP3 context menu offers suggestions' '{"misspelledWordFound":true}' '{"misspelledWordFound":false}'
  fi
  set_text '`teh` and [link](https://example.com/teh)' 0 0
  sleep 0.4
  expect_sample GSP1 'SP2 code and link destinations are not checked' '{"misspelled":[]}' "{\"misspelled\":$(spell_ranges "$(state_get text=0)")}"
  local many= index
  for (( index = 0; index < 20; index++ )); do
    many+="block $index has teh word"
    (( index < 19 )) && many+=$'\n\n'
  done
  probe_post 'settings?spellCheck=0' >/dev/null
  set_text "$many" 0 0
  sleep 0.4
  expect_sample GSP1 'SP5 off means nothing is checked' '{"misspelled":[]}' "{\"misspelled\":$(spell_ranges "$(state_get text=0)")}"
  probe_post 'settings?spellCheck=1' >/dev/null
  sleep 0.3
  state=$(state_get text=0)
  expect_sample GSP1 'SP1 turning it on checks 20 blocks within 300 ms' '{"misspelledCount":20}' "{\"misspelledCount\":$(jcount "$state" misspelled)}"
  reported_sample GSP1 'SP6 on-device only' 'network traffic is not observable from the probe'
  probe_post 'settings?spellCheck=0' >/dev/null
  errors_sample GSP1 'spell matrix errors'
}

spell_ranges() {
  local state=$1
  local -i count index
  count=$(jcount "$state" misspelled)
  local -a ranges=()
  for (( index = 0; index < count; index++ )); do
    ranges+=("[$(jget "$state" misspelled.$index.0),$(jget "$state" misspelled.$index.1)]")
  done
  print -rn -- "[${(j:,:)ranges}]"
}

clock_pairs_json() {
  local -a pairs=("$@")
  local -a out=()
  local pair
  for pair in $pairs; do
    [[ -n $pair ]] && out+=("[${pair% *},${pair#* }]")
  done
  print -rn -- "[${(j:,:)out}]"
}

scenario_perf_keystroke() {
  local id
  for id in $(corpus_ids); do
    open_note $id composer
    local offset
    offset=$(typing_offset) || { print -u2 -r -- "drive: no tidemark in $id"; return 1; }
    select_range $offset $offset
    focus_editor
    settle 2000
    probe_get 'timings?reset=1' >/dev/null
    local -a pairs=()
    local -i index
    for (( index = 0; index < 3; index++ )); do
      pairs+=("$(plat_clock_pair)")
    done
    local nanos
    nanos=$(plat_timed_type "$PROBE_TYPING_TEXT")
    for (( index = 0; index < 3; index++ )); do
      pairs+=("$(plat_clock_pair)")
    done
    sleep 1
    local timings
    timings=$(probe_get timings)
    sample "{\"row\":\"GP1\",\"kind\":\"keystroke\",\"note\":$(json_str $id),\"timings\":$timings}"
    sample "{\"row\":\"GP3\",\"kind\":\"frames\",\"note\":$(json_str $id),\"phase\":\"typing\",\"timings\":$timings}"
    if [[ $id == c50000-p24 ]]; then
      local clock=$(clock_pairs_json "${pairs[@]}")
      if [[ $clock != '[]' && -n $nanos ]]; then
        sample "{\"row\":\"GP2\",\"kind\":\"keyToRaster\",\"note\":$(json_str $id),\"timings\":$timings,\"keyDownNanos\":$(json_lines_array "$nanos"),\"clockPairs\":$clock}"
      else
        sample "{\"row\":\"GP2\",\"kind\":\"keyToRaster\",\"note\":$(json_str $id),\"timings\":$timings}"
      fi
    fi
    probe_post close >/dev/null
  done
}

scenario_perf_scroll() {
  local id
  for id in $(corpus_ids); do
    open_note $id composer
    settle 1000
    probe_get 'timings?reset=1' >/dev/null
    scroll_through 120
    sleep 0.5
    sample "{\"row\":\"GP3\",\"kind\":\"frames\",\"note\":$(json_str $id),\"phase\":\"scrolling\",\"timings\":$(probe_get timings)}"
    probe_post close >/dev/null
  done
}

idle_measure() {
  local name=$1
  settle 2000
  probe_get 'timings?reset=1' >/dev/null
  local pid format ticks= start_cpu end_cpu window_start window_end
  pid=$(probe_get pid | json_get pid)
  read -r format ticks <<< "$(plat_cpu_format)"
  local -F cpu_started=$EPOCHREALTIME
  start_cpu=$(plat_cpu $pid)
  window_start=$(probe_get clock | json_get now)
  sleep 10
  window_end=$(probe_get clock | json_get now)
  end_cpu=$(plat_cpu $pid)
  local -F cpu_ended=$EPOCHREALTIME
  sleep 0.3
  local timings state caret_visible=false
  timings=$(probe_get timings)
  state=$(state_get text=0)
  if jget "$state" caret.0 >/dev/null || [[ $(jget "$state" textFieldFocused) == true ]]; then
    caret_visible=true
  fi
  local -i window_ms=$(( (window_end - window_start) / 1000 ))
  local -i cpu_window_ms=$(( int((cpu_ended - cpu_started) * 1000 + 0.5) ))
  sample "{\"row\":\"GP4\",\"kind\":\"idle\",\"case\":$(json_str $name),\"caretVisible\":$caret_visible,\"timings\":$timings,\"windowMs\":$window_ms,\"windowStartMicros\":$window_start,\"windowEndMicros\":$window_end,\"cpuWindowMs\":$cpu_window_ms,\"cpuStart\":$(json_str "$start_cpu"),\"cpuEnd\":$(json_str "$end_cpu"),\"cpuFormat\":$(json_str $format)${ticks:+,\"clockTicks\":$ticks}}"
}

narrow_toolbar_column() {
  local state column surface narrow
  state=$(state_get text=0)
  column=$(jget "$state" column) && surface=$(jget "$state" writingSurface.2) && narrow=$(jget "$state" photoToolbarNarrowWidth) || return 1
  print -r -- $(( int(narrow - (surface - column) - 2) ))
}

narrow_toolbar_viewport() {
  local column
  column=$(narrow_toolbar_column) || return 1
  probe_get "viewport?column=$column" >/dev/null
  ORIGIN_X=
  ORIGIN_Y=
}

idle_photo_fixture() {
  local title=$1 position=$2
  local photo=$(photo_line 1 "$title")
  local text=$'The harbour was quiet this morning, and the fog sat low over the water.\n\nA second paragraph keeps the note long enough to scroll.'
  if [[ $position == first ]]; then
    print -rn -- "$photo"$'\n\n'"$text"
  else
    print -rn -- "$text"$'\n\n'"$photo"
  fi
}

scenario_perf_idle() {
  local text=$'The harbour was quiet this morning.\n\nThe fog sat low over the water, and the gulls waited on the pier.'
  open_text composer "$text"
  focus_editor
  select_range 10 10
  idle_measure 'nothing selected'
  select_range 4 11
  idle_measure 'a range selected'
  local title position
  for title in 'left medium' 'centre medium' 'centre full'; do
    for position in first last; do
      open_text composer "$(idle_photo_fixture "$title" $position)"
      select_photo 0
      idle_measure "${title} photo selected as the $position block"
    done
  done
  open_text composer "$(idle_photo_fixture 'right medium' first)"
  scroll_to_top
  select_photo 0
  idle_measure 'toolbar flipped below its photo'
  open_text composer "$(idle_photo_fixture 'right medium' last)"
  narrow_toolbar_viewport
  select_photo 0
  press_key photo-toolbar-more 60
  idle_measure 'the more menu open'
  plat_key escape
  probe_get 'viewport?clear=1' >/dev/null
  open_text composer "$(idle_photo_fixture 'right medium' last)"
  select_photo 0
  press_key photo-toolbar-caption 60
  idle_measure 'caption field open'
  plat_key escape
  open_text composer "$text"
  focus_editor
  select_range 10 10
  plat_owner_step 'switch the input source to Japanese (Romaji)'
  plat_type 'nihon'
  idle_measure 'a composition open'
  plat_key escape
  plat_owner_step 'switch the input source back to ABC or U.S.'
  open_text composer "$(idle_photo_fixture 'left medium' first)"
  local state center
  state=$(state_get text=0)
  if center=$(rect_center "$state" photos.0.rect); then
    local x=${center%% *} y=${center##* }
    plat_drag $x $y $x $(( y + 160 )) none 16000 &
    local drag=$!
    sleep 1
    idle_measure 'a drag hovering still'
    plat_key escape
    wait $drag || true
  fi
  open_text composer "$text"
  local found
  found=$(probe_get 'find?text=harbour')
  if center=$(rect_center "$found" rects.0); then
    plat_right_click ${center%% *} ${center##* }
    idle_measure 'context menu open'
    plat_key escape
  fi
}

scenario_perf_open() {
  local -i run
  for (( run = 1; run <= 5; run++ )); do
    probe_post close >/dev/null 2>&1 || true
    probe_get 'timings?reset=1' >/dev/null
    open_note c50000-p24 composer
    sleep 1
    sample "{\"row\":\"GP5\",\"kind\":\"open\",\"note\":\"c50000-p24\",\"run\":$run,\"timings\":$(probe_get timings)}"
  done
  probe_post close >/dev/null
}

scenario_styling_ceiling() {
  local file=$PROBE_WORK/ceiling.md tail=$PROBE_WORK/tail.md
  corpus_note c50000-p24 $file
  corpus_note c50000-p0 $tail
  local -i bytes
  bytes=$(wc -c < $tail | tr -d ' ')
  { cat $file; printf '\n\n'; head -c $(( bytes - 2 )) $tail; } > $PROBE_WORK/ceiling-full.md
  probe_post "open?surface=new&id=ceiling&media=$(corpus_media c50000-p24)" /dev/null >/dev/null
  probe_post 'set?base=0&extent=0' $PROBE_WORK/ceiling-full.md >/dev/null
  settle 2000
  local state
  state=$(state_get text=0)
  local -i length
  length=$(jget "$state" length)
  sample "{\"row\":\"GP6\",\"kind\":\"styling\",\"case\":\"100000 units\",\"length\":$length,\"state\":$state}"
}

random_op() {
  local -i pick=$(( RANDOM % 18 ))
  local -a words=(harbour fog tide gull pier lantern shell kelp)
  local -a controls=("${(@f)$(photo_toolbar_keys)}")
  case $pick in
    0|1|2|3) REPLY="type:${words[RANDOM % ${#words} + 1]} " ;;
    4) REPLY=key:backspace ;;
    5) REPLY=key:opt+backspace ;;
    6) REPLY=key:cmd+b ;;
    7) REPLY=key:cmd+i ;;
    8) REPLY=key:shift+cmd+x ;;
    9) REPLY=key:shift+cmd+h ;;
    10) REPLY=key:shift+cmd+8 ;;
    11) REPLY=key:enter ;;
    12) REPLY=key:tab ;;
    13) REPLY=key:cmd+z ;;
    14) REPLY=key:shift+cmd+z ;;
    15) REPLY=key:shift+left ;;
    16) REPLY="photo:$(( RANDOM % 4 )):${controls[RANDOM % ${#controls} + 1]}" ;;
    *) REPLY=key:left ;;
  esac
}

photo_toolbar_keys() {
  print -rl -- photo-toolbar-move-up photo-toolbar-move-down photo-toolbar-remove photo-toolbar-size-small photo-toolbar-size-large photo-toolbar-side-left photo-toolbar-side-right photo-toolbar-side-centre
}

run_op() {
  local op=$1
  case $op in
    type:*) plat_type "${op#type:}" ;;
    key:*) plat_key "${op#key:}" ;;
    press:*) press_key "${op#press:}" 110 ;;
    select:*) select_photo "${op#select:}" ;;
    photo:*)
      local spec=${op#photo:} control=
      if [[ $spec == *:* ]]; then
        control=${spec#*:}
        spec=${spec%%:*}
      fi
      local state
      state=$(state_get text=0)
      local -i count
      count=$(photo_count "$state")
      if (( count > 0 )); then
        select_photo $(( spec % count ))
        if [[ -z $control ]]; then
          local -a keys=("${(@f)$(photo_toolbar_keys)}")
          control=${keys[RANDOM % ${#keys} + 1]}
        fi
        press_key $control 110 || true
      fi
      ;;
  esac
}

round_trip_fixture() {
  print -rn -- $'# Harbour day\n\nThe fog lifted at noon, and the tide ran out past the pier.\n\n'"$(photo_line 1 'left medium')"$'\n\n- rope\n- lantern\n\n'"$(photo_line 2 'centre large')"$'\n\nThe last paragraph of the day.'
}

round_trip_session() {
  local name=$1
  shift
  local fixture
  fixture=$(round_trip_fixture)
  open_text composer "$fixture"
  focus_editor
  select_range $(( ${#fixture} / 2 )) $(( ${#fixture} / 2 ))
  local op
  for op in "$@"; do
    run_op "$op"
    sleep 0.05
  done
  sleep 0.5
  local at_save saved reopened
  at_save=$(state_get)
  saved=$(probe_post save)
  local stored=$PROBE_WORK/stored.md
  if ! jget_exact "$saved" stored; then
    probe_post close >/dev/null 2>&1 || true
    sample "{\"row\":\"GR1\",\"kind\":\"roundTrip\",\"case\":$(json_str $name),\"storedMissing\":true,\"atSave\":$at_save,\"reopened\":{}}"
    return 0
  fi
  write_text $stored "$REPLY"
  probe_post close >/dev/null
  probe_post "open?surface=composer&id=roundtrip&media=$(fixture_media)" $stored >/dev/null
  sleep 0.3
  reopened=$(state_get)
  sample "{\"row\":\"GR1\",\"kind\":\"roundTrip\",\"case\":$(json_str $name),\"atSave\":$at_save,\"reopened\":$reopened}"
}

scripted_sessions() {
  print -rl -- \
    'type:morning |key:cmd+b|type:bold|key:cmd+b' \
    'key:shift+cmd+8|type:item|key:enter|type:next|key:tab' \
    'photo:0|key:backspace|key:backspace' \
    'photo:1|key:cmd+z|key:shift+cmd+z' \
    'key:shift+left|key:shift+left|key:shift+cmd+h|key:cmd+z' \
    'type:line |key:enter|key:enter|type:after' \
    'photo:0|key:cmd+x|key:cmd+v' \
    'key:shift+cmd+9|type:task|key:cmd+l' \
    'type:code |key:shift+left|key:cmd+e|key:cmd+k|type:link' \
    'key:opt+backspace|key:opt+backspace|key:cmd+z|key:cmd+z|key:shift+cmd+z'
}

scenario_round_trip() {
  local seed=${PROBE_SEED:-$RANDOM}
  print -r -- "round-trip seed $seed"
  RANDOM=$seed
  local -i sequences=${PROBE_SEQUENCES:-10000} sequence length step
  for (( sequence = 1; sequence <= sequences; sequence++ )); do
    length=$(( RANDOM % 50 + 1 ))
    local -a ops=()
    for (( step = 0; step < length; step++ )); do
      random_op
      ops+=("$REPLY")
    done
    round_trip_session "random $seed/$sequence" "${ops[@]}"
  done
  local -a scripts=("${(@f)$(scripted_sessions)}")
  local -i session
  for (( session = 1; session <= 50; session++ )); do
    local script=${scripts[(session - 1) % ${#scripts} + 1]}
    round_trip_session "scripted $session" "${(@s:|:)script}"
  done
}

line_range_of() {
  local source=$1
  local -i from=$2 to=$3 start end
  local before=${source[1,from]}
  if [[ $before == *$'\n'* ]]; then
    start=$(( ${#before} - ${#${before##*$'\n'}} ))
  else
    start=0
  fi
  local after=${source[to+1,-1]}
  if [[ $after == *$'\n'* ]]; then
    end=$(( to + ${#${after%%$'\n'*}} ))
  else
    end=${#source}
  fi
  print -r -- "$start $end"
}

allowed_range() {
  local op=$1 before=$2
  jget_exact "$before" source
  local source=$REPLY
  local -i base extent from to
  base=$(jget "$before" selection.0)
  extent=$(jget "$before" selection.1)
  from=$(( base < extent ? base : extent ))
  to=$(( base < extent ? extent : base ))
  case $op in
    type:*|key:backspace|key:opt+backspace|key:delete|key:opt+delete|key:enter|key:cmd+x|key:cmd+v)
      local range=$(line_range_of "$source" $from $to)
      local -i start=${range% *} end=${range#* }
      if [[ $op == key:backspace || $op == key:opt+backspace ]] && (( from == to && from == start && start > 0 )); then
        local previous=$(line_range_of "$source" $(( start - 1 )) $(( start - 1 )))
        start=${previous% *}
      fi
      if [[ $op == key:delete || $op == key:opt+delete ]] && (( from == to && to == end && end < ${#source} )); then
        local following=$(line_range_of "$source" $(( end + 1 )) $(( end + 1 )))
        end=${following#* }
      fi
      print -r -- "[[$start,$end]]"
      ;;
    *)
      local range=$(line_range_of "$source" $from $to)
      local -i start=${range% *} end=${range#* }
      (( start > 0 )) && start=$(( start - 1 ))
      (( end < ${#source} )) && end=$(( end + 1 ))
      print -r -- "[[$start,$end]]"
      ;;
  esac
}

photo_command_json() {
  local op=$1 before=$2 control= photo
  local -i count
  count=$(photo_count "$before")
  case $op in
    photo:*:*)
      (( count > 0 )) || return 1
      local spec=${op#photo:}
      control=${spec#*:}
      photo=$(( ${spec%%:*} % count ))
      ;;
    key:backspace|key:opt+backspace|key:delete|key:opt+delete|key:cmd+x)
      photo=$(jget "$before" photoSelected) || return 1
      control=remove
      ;;
    *)
      return 1
      ;;
  esac
  jget_exact "$before" source || return 1
  local blocks
  blocks=$(print -r -- "$before" | plutil -extract blocks json -o - - 2>/dev/null) || return 1
  print -rn -- "{\"control\":$(json_str $control),\"photo\":$photo,\"source\":$(json_str "$REPLY"),\"blocks\":$blocks}"
}

side_edit_sample() {
  local name=$1 op=$2 before=$3 changes=$4 command
  if command=$(photo_command_json "$op" "$before"); then
    sample "{\"row\":\"GR2\",\"kind\":\"sideEdit\",\"case\":$(json_str "$name"),\"command\":$(json_str $op),\"photoCommand\":$command,\"changes\":$changes}"
  else
    sample "{\"row\":\"GR2\",\"kind\":\"sideEdit\",\"case\":$(json_str "$name"),\"command\":$(json_str $op),\"allowed\":$(allowed_range "$op" "$before"),\"changes\":$changes}"
  fi
}

log_changes() {
  local log=$1
  local -i count index changes change
  count=$(jcount "$log" transactions)
  local -a out=()
  for (( index = 0; index < count; index++ )); do
    changes=$(jcount "$log" transactions.$index.changes)
    for (( change = 0; change < changes; change++ )); do
      out+=("[$(jget "$log" transactions.$index.changes.$change.0),$(jget "$log" transactions.$index.changes.$change.1),$(jget "$log" transactions.$index.changes.$change.2)]")
    done
  done
  print -rn -- "[${(j:,:)out}]"
}

scenario_side_edit_audit() {
  local seed=${PROBE_SEED:-$RANDOM}
  print -r -- "side-edit-audit seed $seed"
  RANDOM=$seed
  probe_get watch >/dev/null
  local -i sequences=${PROBE_SEQUENCES:-10000} sequence length step
  for (( sequence = 1; sequence <= sequences; sequence++ )); do
    length=$(( RANDOM % 50 + 1 ))
    local fixture
    fixture=$(round_trip_fixture)
    open_text composer "$fixture"
    focus_editor
    select_range $(( ${#fixture} / 2 )) $(( ${#fixture} / 2 ))
    probe_get 'log?clear=1' >/dev/null
    for (( step = 0; step < length; step++ )); do
      local op before log
      random_op
      op=$REPLY
      [[ $op == key:cmd+z || $op == key:shift+cmd+z ]] && continue
      before=$(state_get)
      run_op "$op"
      sleep 0.05
      log=$(probe_get 'log?clear=1')
      local changes=$(log_changes "$log")
      [[ $changes == '[]' ]] && continue
      side_edit_sample "$seed/$sequence/$step" "$op" "$before" "$changes"
    done
  done
}

held_fixture() {
  local title=$1 position=$2
  local -a before=() after=()
  local -i index
  for (( index = 1; index <= 8; index++ )); do
    before+=("Paragraph $index before the photo keeps the note long enough to scroll.")
    after+=("Paragraph $index after the photo keeps the note long enough to scroll.")
  done
  local photo=$(photo_line 1 "$title")
  case $position in
    first) print -rn -- "$photo"$'\n\n'"${(pj:\n\n:)after}" ;;
    middle) print -rn -- "${(pj:\n\n:)before}"$'\n\n'"$photo"$'\n\n'"${(pj:\n\n:)after}" ;;
    last) print -rn -- "${(pj:\n\n:)before}"$'\n\n'"$photo" ;;
  esac
}

held_blocks() {
  local title=$1 position=$2
  local -a blocks=()
  local -i index
  local photo=$(photo_line 1 "$title")
  [[ $position == first ]] || for (( index = 1; index <= 8; index++ )); do blocks+=("Paragraph $index before the photo keeps the note long enough to scroll."); done
  blocks+=("$photo")
  [[ $position == last ]] || for (( index = 1; index <= 8; index++ )); do blocks+=("Paragraph $index after the photo keeps the note long enough to scroll."); done
  print -rl -- $blocks
}

p3_uniform() {
  local op=$1
  local -i photo=$2
  shift 2
  local -a blocks=("$@")
  local -i count=${#blocks}
  local line=${blocks[photo]}
  local -a others=("${(@)blocks[1,photo-1]}" "${(@)blocks[photo+1,-1]}")
  case $op in
    remove) print -rn -- "${(pj:\n\n:)others}" ;;
    up)
      if (( photo == 1 )); then
        print -rn -- "__none__"
      elif (( photo == 2 )); then
        print -rn -- "$line"$'\n'"${(pj:\n\n:)others}"
      else
        local -a head=("${(@)blocks[1,photo-2]}") tail=("${(@)blocks[photo-1]}" "${(@)blocks[photo+1,-1]}")
        print -rn -- "${(pj:\n\n:)head}"$'\n'"$line"$'\n\n'"${(pj:\n\n:)tail}"
      fi
      ;;
    down)
      if (( photo == count )); then
        print -rn -- "__none__"
      else
        local -a head=("${(@)blocks[1,photo-1]}" "${(@)blocks[photo+1]}") tail=("${(@)blocks[photo+2,-1]}")
        local out="${(pj:\n\n:)head}"$'\n'"$line"
        (( ${#tail} > 0 )) && out+=$'\n\n'"${(pj:\n\n:)tail}"
        print -rn -- "$out"
      fi
      ;;
  esac
}

scroll_photo_to() {
  local -F want=$1
  local -i attempt
  for (( attempt = 0; attempt < 12; attempt++ )); do
    local state top width height
    state=$(state_get text=0)
    top=$(jget "$state" photos.0.rect.1) && width=$(jget "$state" view.width) && height=$(jget "$state" view.height) || return 0
    local -F delta=$(( top - want ))
    (( delta > -4 && delta < 4 )) && return 0
    plat_scroll $(( width / 2.0 )) $(( height / 2.0 )) $(( -delta ))
    sleep 0.15
  done
}

held_press() {
  local case_name=$1 click=$2 fixture=$3 key=$4 hold=$5 expected=$6 check=$7 top=$8
  set_text "$fixture" 0 0
  sleep 0.1
  scroll_photo_to $top
  select_photo 0
  probe_get 'errors?clear=1' >/dev/null
  local before
  before=$(state_get text=0)
  [[ $check == replace ]] && probe_get 'nextPhoto?w=1500&h=1000' >/dev/null
  press_key $key $hold || true
  sleep 0.35
  local after delta errors width_rounded=null
  after=$(state_get)
  delta=$(( $(transactions_of "$after") - $(transactions_of "$before") ))
  errors=$(errors_total)
  local observed expected_json
  case $check in
    source)
      local width
      width=$(jget "$after" photos.0.rect.2) && width_rounded=$(printf '%.0f' $width)
      if [[ $expected == __none__ ]]; then
        expected_json="{\"transactionDelta\":0,\"errors\":0}"
      else
        expected_json="{\"state\":{\"source\":$(json_str "$expected")},\"transactionDelta\":1,\"errors\":0${EXPECTED_WIDTH:+,\"photoWidth\":$EXPECTED_WIDTH}}"
      fi
      observed="{\"state\":$after,\"transactionDelta\":$delta,\"errors\":$errors,\"photoWidth\":$width_rounded}"
      ;;
    disabled)
      expected_json='{"transactionDelta":0,"errors":0}'
      observed="{\"transactionDelta\":$delta,\"errors\":$errors}"
      ;;
    caption)
      expected_json='{"captionOpen":true,"transactionDelta":0,"errors":0}'
      observed="{\"captionOpen\":$(bool_json key_present photo-caption-editor),\"transactionDelta\":$delta,\"errors\":$errors}"
      plat_key escape
      ;;
    replace)
      sleep 0.6
      after=$(state_get text=0)
      delta=$(( $(transactions_of "$after") - $(transactions_of "$before") ))
      local old_ref new_ref
      old_ref=$(jget "$before" photos.0.reference)
      new_ref=$(jget "$after" photos.0.reference)
      expected_json='{"transactionDelta":1,"referenceChanged":true,"errors":0}'
      observed="{\"transactionDelta\":$delta,\"referenceChanged\":$([[ $old_ref != $new_ref ]] && print -rn true || print -rn false),\"errors\":$errors}"
      ;;
    menu)
      expected_json='{"menuOpen":true,"transactionDelta":0,"errors":0}'
      observed="{\"menuOpen\":$(bool_json text_present 'Move up'),\"transactionDelta\":$delta,\"errors\":$errors}"
      plat_key escape
      ;;
  esac
  expect_sample GR3 "$case_name click $click hold ${hold}ms" "$expected_json" "$observed" "$(held_fields "$case_name" $hold)"
}

held_fields() {
  print -rn -- ",\"clickCase\":$(json_str "$1"),\"hold\":$2"
}

glyph_center() {
  local rect
  rect=$(glyph_rect "$1") || return 1
  rect_center "{\"r\":$rect}" r
}

format_press() {
  local key=$1 hold=$2
  case $key in
    format-strikethrough|format-highlight|format-code)
      press_key format-more 110 || return 1
      sleep 0.3
      ;;
  esac
  press_key $key $hold
}

format_selection() {
  set_text "$1" 4 9
  focus_editor
  select_range 4 9
  probe_get 'errors?clear=1' >/dev/null
}

held_title_after() {
  local title=$1 control=$2 value=$3
  local side size
  case $title in
    banana) side=centre size=medium ;;
    *) side=${title% *} size=${title#* } ;;
  esac
  if [[ $control == size ]]; then
    [[ $title == banana ]] && { print -r -- "centre $value"; return; }
    print -r -- "$side $value"
  else
    [[ $title == banana ]] && { print -r -- "$value medium"; return; }
    print -r -- "$value $size"
  fi
}

scenario_held_clicks() {
  local -a holds=(30 110 300)
  local -a titles=('left medium' 'right medium' 'centre medium' 'centre full' banana)
  local -a positions=(first middle last)
  local -a modes=(above below narrow)
  local ref=$(fixture_ref 1)
  local title position mode hold
  local -i click
  for title in $titles; do
    for position in $positions; do
      local fixture
      fixture=$(held_fixture "$title" $position)
      local -a blocks=("${(@f)$(held_blocks "$title" $position)}")
      local -i photo_index=${blocks[(i)*photo/*]}
      for mode in $modes; do
        local top=240
        [[ $mode == below ]] && top=4
        probe_get 'viewport?clear=1' >/dev/null
        open_text composer "$fixture"
        [[ $mode == narrow ]] && narrow_toolbar_viewport
        local state column
        state=$(state_get text=0)
        column=$(jget "$state" column)
        local phone=0
        is_phone_column && phone=1
        for hold in $holds; do
          for (( click = 1; click <= 20; click++ )); do
            local base="$title $position $mode"
            local control value expected
            if (( ! phone )); then
              for value in small medium large full; do
                local new_title=$(held_title_after "$title" size $value)
                expected=${fixture//\"$title\"/\"$new_title\"}
                local fraction
                case $value in small) fraction=0.3333333333 ;; medium) fraction=0.5 ;; large) fraction=0.6666666667 ;; full) fraction=1 ;; esac
                EXPECTED_WIDTH=$(printf '%.0f' $(( column * fraction )))
                if [[ $new_title == $title ]]; then
                  held_press "$base size $value" $click "$fixture" photo-toolbar-size-$value $hold __none__ source $top
                else
                  held_press "$base size $value" $click "$fixture" photo-toolbar-size-$value $hold "$expected" source $top
                fi
              done
              EXPECTED_WIDTH=
              for value in left centre right; do
                if [[ $title == 'centre full' && $value != centre ]]; then
                  held_press "$base side $value" $click "$fixture" photo-toolbar-side-$value $hold '' disabled $top
                  continue
                fi
                local new_title=$(held_title_after "$title" side $value)
                if [[ $new_title == $title ]]; then
                  held_press "$base side $value" $click "$fixture" photo-toolbar-side-$value $hold __none__ source $top
                else
                  held_press "$base side $value" $click "$fixture" photo-toolbar-side-$value $hold "${fixture//\"$title\"/\"$new_title\"}" source $top
                fi
              done
            fi
            if [[ $mode == narrow ]]; then
              held_press "$base more" $click "$fixture" photo-toolbar-more $hold '' menu $top
            else
              local up down
              up=$(p3_uniform up $photo_index "${blocks[@]}")
              down=$(p3_uniform down $photo_index "${blocks[@]}")
              if [[ $up == __none__ ]]; then
                held_press "$base move up" $click "$fixture" photo-toolbar-move-up $hold '' disabled $top
              else
                held_press "$base move up" $click "$fixture" photo-toolbar-move-up $hold "$up" source $top
              fi
              if [[ $down == __none__ ]]; then
                held_press "$base move down" $click "$fixture" photo-toolbar-move-down $hold '' disabled $top
              else
                held_press "$base move down" $click "$fixture" photo-toolbar-move-down $hold "$down" source $top
              fi
              held_press "$base replace" $click "$fixture" photo-toolbar-replace $hold '' replace $top
            fi
            held_press "$base caption" $click "$fixture" photo-toolbar-caption $hold '' caption $top
            held_press "$base remove" $click "$fixture" photo-toolbar-remove $hold "$(p3_uniform remove $photo_index "${blocks[@]}")" source $top
          done
        done
      done
    done
  done
  probe_get 'viewport?clear=1' >/dev/null
  held_format_clicks $holds
}

held_format_clicks() {
  local -a holds=("$@")
  local hold
  local -i click
  local selection_text='the quick fox'
  local -a formats=(
    'format-bold|the **quick** fox'
    'format-italic|the *quick* fox'
    'format-heading|# the quick fox'
    'format-list|- the quick fox'
    'format-numbered|1. the quick fox'
    'format-task|- [ ] the quick fox'
    'format-quote|> the quick fox'
    'format-link|the [quick]() fox'
    'format-strikethrough|the ~~quick~~ fox'
    'format-highlight|the ==quick== fox'
    'format-code|the `quick` fox'
  )
  open_text composer "$selection_text"
  local entry key expected before after center state
  for hold in $holds; do
    for (( click = 1; click <= 20; click++ )); do
      for entry in $formats; do
        key=${entry%%|*}
        expected=${entry#*|}
        format_selection "$selection_text"
        before=$(state_get text=0)
        format_press $key $hold || true
        sleep 0.3
        after=$(state_get)
        expect_sample GR3 "$key click $click hold ${hold}ms" "{\"state\":{\"source\":$(json_str "$expected")},\"transactionDelta\":1,\"errors\":0}" "{\"state\":$after,\"transactionDelta\":$(( $(transactions_of "$after") - $(transactions_of "$before") )),\"errors\":$(errors_total)}" "$(held_fields $key $hold)"
      done
      format_selection "$selection_text"
      before=$(state_get text=0)
      press_key format-more $hold || true
      sleep 0.3
      after=$(state_get text=0)
      expect_sample GR3 "format-more click $click hold ${hold}ms" '{"menuOpen":true,"transactionDelta":0,"errors":0}' "{\"menuOpen\":$(bool_json key_present format-strikethrough),\"transactionDelta\":$(( $(transactions_of "$after") - $(transactions_of "$before") )),\"errors\":$(errors_total)}" "$(held_fields format-more $hold)"
      plat_key escape
      format_selection "$selection_text"
      plat_key cmd+b
      sleep 0.2
      probe_get 'errors?clear=1' >/dev/null
      press_key format-undo $hold || true
      sleep 0.3
      after=$(state_get)
      expect_sample GR3 "format-undo click $click hold ${hold}ms" "{\"state\":{\"source\":$(json_str "$selection_text")},\"errors\":0}" "{\"state\":$after,\"errors\":$(errors_total)}" "$(held_fields format-undo $hold)"
      set_text '- [ ] passport' 10 10
      focus_editor
      select_range 10 10
      if center=$(glyph_center "$(probe_get 'boxes?from=2&to=5')"); then
        before=$(state_get text=0)
        plat_click ${center%% *} ${center##* } $hold
        sleep 0.3
        after=$(state_get)
        expect_sample GR3 "checkbox click $click hold ${hold}ms" '{"state":{"source":"- [x] passport"},"selection":[10,10],"transactionDelta":1}' "{\"state\":$after,\"selection\":$(selection_json "$after"),\"transactionDelta\":$(( $(transactions_of "$after") - $(transactions_of "$before") ))}" "$(held_fields checkbox $hold)"
      else
        expect_sample GR3 "checkbox click $click hold ${hold}ms" '{"checkboxFound":true}' '{"checkboxFound":false}' "$(held_fields checkbox $hold)"
      fi
      set_text "The figure follows."$'\n\n'"$(photo_line 1 'centre medium')" 0 0
      state=$(state_get text=0)
      if center=$(rect_center "$state" photos.0.rect); then
        plat_click ${center%% *} ${center##* } $hold
        sleep 0.3
        state=$(state_get text=0)
        expect_sample GR3 "photo figure click $click hold ${hold}ms" '{"photoSelected":0}' "{\"photoSelected\":$(jget "$state" photoSelected || print -rn null)}" "$(held_fields 'photo figure' $hold)"
      else
        expect_sample GR3 "photo figure click $click hold ${hold}ms" '{"photoFound":true}' '{"photoFound":false}' "$(held_fields 'photo figure' $hold)"
      fi
    done
  done
}

typeset -g EXPECTED_WIDTH=

scenario_monkey() {
  local -a skipped=(table-matrix spell-matrix perf-memory monkey)
  local scenario
  for scenario in $PROBE_SCENARIOS; do
    (( ${skipped[(Ie)$scenario]} )) && continue
    RESULT_DISCARD=1
    probe_get 'errors?scope=scenario&reset=1' >/dev/null
    scenario_${scenario//-/_} || print -u2 -r -- "drive: $scenario ended with status $? inside monkey"
    RESULT_DISCARD=0
    errors_sample GR4 $scenario 'errors?scope=scenario&reset=1'
  done
  local seed=${PROBE_SEED:-$RANDOM}
  print -r -- "monkey seed $seed"
  RANDOM=$seed
  open_note c6000-p8 composer
  focus_editor
  local state width height
  state=$(state_get text=0)
  width=$(jget "$state" view.width)
  height=$(jget "$state" view.height)
  local -a keys=(left right up down backspace delete enter tab shift+tab cmd+z shift+cmd+z cmd+b cmd+i opt+backspace shift+right shift+down cmd+a escape a e space)
  local -i step steps=${PROBE_MONKEY_STEPS:-10000}
  probe_get 'errors?scope=scenario&reset=1' >/dev/null
  for (( step = 1; step <= steps; step++ )); do
    case $(( RANDOM % 3 )) in
      0) plat_key ${keys[RANDOM % ${#keys} + 1]} || true ;;
      1) plat_click $(( RANDOM % int(width) )) $(( RANDOM % int(height) )) $(( 20 + RANDOM % 280 )) || true ;;
      2) plat_drag $(( RANDOM % int(width) )) $(( RANDOM % int(height) )) $(( RANDOM % int(width) )) $(( RANDOM % int(height) )) || true ;;
    esac
    if (( step % 500 == 0 )) && ! probe_get pid >/dev/null 2>&1; then
      sample "{\"row\":\"GR4\",\"kind\":\"errors\",\"case\":$(json_str "random relaunch at step $step"),\"errors\":{\"errors\":[{\"error\":\"the probe stopped answering during the random run and was relaunched\"}],\"drops\":[]}}"
      plat_launch $PROBE_BUILD
      open_note c6000-p8 composer
      focus_editor
    fi
  done
  errors_sample GR4 random 'errors?scope=scenario&reset=1' ",\"steps\":$steps"
}

undo_case() {
  local name=$1 fixture=$2 base=$3 extent=$4 selection=${5:-}
  shift 5
  open_text composer "$fixture"
  focus_editor
  select_range $base $extent
  local start
  start=$(state_get)
  local op
  for op in "$@"; do
    run_op "$op"
    sleep 0.08
  done
  sleep 0.2
  local edited
  edited=$(state_get)
  jget_exact "$edited" source
  local edited_source=$REPLY
  plat_key cmd+z
  sleep 0.2
  local undone
  undone=$(state_get)
  expect_sample GR5 "$name undo" "{\"state\":{\"source\":$(json_str "$fixture")},\"selection\":${selection:-[$base,$extent]}}" "{\"state\":$undone,\"selection\":$(selection_json "$undone")}"
  plat_key shift+cmd+z
  sleep 0.2
  local redone
  redone=$(state_get)
  expect_sample GR5 "$name redo" "{\"state\":{\"source\":$(json_str "$edited_source")}}" "{\"state\":$redone}"
}

scenario_undo_matrix() {
  local text='the quick fox jumps'
  local photo=$(photo_line 1 'left medium')
  local photo_note="Before the photo."$'\n\n'"$photo"$'\n\n'"After the photo."
  local -i photo_start=${#${photo_note%%$photo*}}
  undo_case 'typing a word' "$text " 20 20 '' type:over
  undo_case 'deleting a word' "$text" 19 19 '' key:opt+backspace
  undo_case 'bold' "$text" 4 9 '' key:cmd+b
  undo_case 'italic' "$text" 4 9 '' key:cmd+i
  undo_case 'strikethrough' "$text" 4 9 '' key:shift+cmd+x
  undo_case 'highlight' "$text" 4 9 '' key:shift+cmd+h
  undo_case 'inline code' "$text" 4 9 '' key:cmd+e
  undo_case 'link' "$text" 4 9 '' key:cmd+k
  undo_case 'bullet list' "$text" 4 4 '' key:shift+cmd+8
  undo_case 'numbered list' "$text" 4 4 '' key:shift+cmd+7
  undo_case 'task list' "$text" 4 4 '' key:shift+cmd+9
  undo_case 'enter in a list' '- rope' 6 6 '' key:enter
  undo_case 'tab in a list' $'- rope\n- lantern' 15 15 '' key:tab
  undo_case 'cut' "$text" 4 9 '' key:cmd+x
  undo_case 'photo move down' "$photo_note" 0 0 "[$photo_start,$(( photo_start + ${#photo} ))]" select:0 press:photo-toolbar-move-down key:escape
  local fixture=$text
  open_text composer "$fixture"
  focus_editor
  local -i index
  for (( index = 0; index < 1200; index++ )); do
    select_range 4 9
    plat_key cmd+b
  done
  for (( index = 0; index < 1000; index++ )); do
    plat_key cmd+z
  done
  local deep
  deep=$(state_get)
  local deep_can=$(jget "$deep" canUndo)
  plat_key cmd+z
  sleep 0.2
  local after
  after=$(state_get)
  expect_sample GR5 '1200 edits then 1001 undos' "{\"canUndo\":false,\"state\":{\"source\":$(json_str "$fixture")},\"depthReached\":false}" "{\"canUndo\":$(jget "$after" canUndo),\"state\":$after,\"depthReached\":$deep_can}"
}

gr6_kind_source() {
  case $1 in
    paragraph) print -rn -- 'A plain paragraph.' ;;
    heading) print -rn -- '## A heading' ;;
    list) print -rn -- $'- one\n- two' ;;
    task) print -rn -- $'- [ ] one\n- [x] two' ;;
    quote) print -rn -- '> a quote' ;;
    fence) print -rn -- $'```\ncode\n```' ;;
    divider) print -rn -- '---' ;;
    photo) photo_line 2 'left small' 'other' ;;
    unclosed) print -rn -- $'```\nopen code' ;;
  esac
}

gr6_fixture() {
  local position=$1 kind=$2 separator=$3
  local lb=$'\n'
  [[ $separator == crlf ]] && lb=$'\r\n'
  local wide=$lb$lb
  local near=$lb
  [[ $separator == double ]] && near=$lb$lb
  local block=$(gr6_kind_source $kind)
  block=${block//$'\n'/$lb}
  local photo=$(photo_line 1 'right medium' 'p')
  local head='Head paragraph.' tail='Tail paragraph.'
  GR6_BLOCKS=()
  GR6_PHOTO_FLAGS=()
  GR6_FENCE_FLAGS=()
  GR6_SEPARATORS=()
  local -i moved
  case $position in
    first)
      GR6_BLOCKS=("$photo" "$block" "$tail")
      GR6_SEPARATORS=("$near" "$wide")
      moved=0
      ;;
    middle)
      GR6_BLOCKS=("$head" "$block" "$photo" "$tail")
      GR6_SEPARATORS=("$wide" "$near" "$near")
      moved=2
      ;;
    last)
      GR6_BLOCKS=("$head" "$block" "$photo")
      GR6_SEPARATORS=("$wide" "$near")
      moved=2
      ;;
  esac
  if [[ $kind == unclosed ]]; then
    GR6_BLOCKS=("$head" "$photo" "$block")
    GR6_SEPARATORS=("$near" "$near")
    moved=1
  fi
  local entry
  for entry in $GR6_BLOCKS; do
    [[ $entry == '!['*'](photo/'* ]] && GR6_PHOTO_FLAGS+=(true) || GR6_PHOTO_FLAGS+=(false)
    [[ $kind == unclosed && $entry == '```'* ]] && GR6_FENCE_FLAGS+=(true) || GR6_FENCE_FLAGS+=(false)
  done
  GR6_MOVED=$moved
}

typeset -ga GR6_BLOCKS=() GR6_PHOTO_FLAGS=() GR6_FENCE_FLAGS=() GR6_SEPARATORS=()
typeset -gi GR6_MOVED=0

gr6_source() {
  local out=${GR6_BLOCKS[1]}
  local -i index
  for (( index = 2; index <= ${#GR6_BLOCKS}; index++ )); do
    out+=${GR6_SEPARATORS[index - 1]}${GR6_BLOCKS[index]}
  done
  printf '%s' "$out"
}

gr6_fixture_json() {
  local -a blocks=() separators=()
  local -i index
  for (( index = 1; index <= ${#GR6_BLOCKS}; index++ )); do
    blocks+=("{\"source\":$(json_str "${GR6_BLOCKS[index]}"),\"isPhoto\":${GR6_PHOTO_FLAGS[index]},\"unclosedFence\":${GR6_FENCE_FLAGS[index]}}")
  done
  for (( index = 1; index <= ${#GR6_SEPARATORS}; index++ )); do
    separators+=("$(json_str "${GR6_SEPARATORS[index]}")")
  done
  print -rn -- "{\"blocks\":[${(j:,:)blocks}],\"separators\":[${(j:,:)separators}]}"
}

gr6_photo_ordinal() {
  local -i index ordinal=0
  for (( index = 1; index <= GR6_MOVED; index++ )); do
    [[ ${GR6_PHOTO_FLAGS[index]} == true ]] && (( ordinal += 1 ))
  done
  print -r -- $ordinal
}

gr6_boundary_y() {
  local state=$1
  local -i after_block=$2 count
  count=$(jcount "$state" blocks)
  if (( after_block < 0 )); then
    print -r -- $(( $(jget "$state" blocks.0.globalTop) + 2 ))
  elif (( after_block + 1 < count )); then
    print -r -- $(( ($(jget "$state" blocks.$after_block.globalBottom) + $(jget "$state" blocks.$(( after_block + 1 )).globalTop)) / 2.0 ))
  else
    print -r -- $(( $(jget "$state" blocks.$(( count - 1 )).globalBottom) + 3 ))
  fi
}

gr6_run() {
  local name=$1 op=$2 after_block=${3:-} escape=${4:-false}
  local file=$PROBE_WORK/gr6.md
  gr6_source > $file
  probe_post 'set?base=0&extent=0' $file >/dev/null
  sleep 0.15
  local ordinal=$(gr6_photo_ordinal)
  local before
  before=$(state_get)
  local hover=null
  case $op in
    remove|moveUp|moveDown)
      select_photo $ordinal
      before=$(state_get)
      local key
      case $op in
        remove) key=photo-toolbar-remove ;;
        moveUp) key=photo-toolbar-move-up ;;
        moveDown) key=photo-toolbar-move-down ;;
      esac
      press_key $key 110 || true
      ;;
    drag)
      local center x y target
      center=$(rect_center "$before" photos.$ordinal.rect) || return 0
      x=${center%% *}
      y=${center##* }
      target=$(gr6_boundary_y "$before" $after_block)
      plat_drag $x $y $x $target none 1200 &
      local drag=$!
      sleep 0.9
      hover=$(jget "$(state_get text=0)" dropBoundary) || hover=null
      [[ $escape == true ]] && plat_key escape
      wait $drag || true
      ;;
  esac
  sleep 0.35
  local after
  after=$(state_get)
  local extra=
  if [[ $op == drag ]]; then
    extra=",\"afterBlock\":$after_block,\"escaped\":$escape,\"hoverBoundary\":$hover"
  fi
  sample "{\"row\":\"GR6\",\"kind\":\"relocation\",\"case\":$(json_str $name),\"fixture\":$(gr6_fixture_json),\"photo\":$GR6_MOVED,\"op\":\"$op\"$extra,\"before\":$before,\"after\":$after}"
}

scenario_photo_move_matrix() {
  local position kind separator
  open_text new ''
  focus_editor
  for kind in paragraph heading list task quote fence divider photo unclosed; do
    for position in first middle last; do
      [[ $kind == unclosed && $position != middle ]] && continue
      for separator in single double crlf; do
        gr6_fixture $position $kind $separator
        local name="$kind $position $separator"
        gr6_run "$name remove" remove
        gr6_run "$name move up" moveUp
        gr6_run "$name move down" moveDown
        local -i boundary count=${#GR6_BLOCKS}
        for (( boundary = -1; boundary < count; boundary++ )); do
          gr6_run "$name drag to $boundary" drag $boundary false
        done
        local -i escape_target=-1
        (( GR6_MOVED == 0 )) && escape_target=$(( count - 1 ))
        gr6_run "$name escape during drag" drag $escape_target true
      done
    done
  done
}

typeset -g GR7_FIXTURE= GR7_CARET= GR7_BEFORE= GR7_EXPECTED_PREFIX= GR7_EXPECTED_SUFFIX= GR7_NOTE_ID=
typeset -g GR7_DROP_X= GR7_DROP_Y= GR7_DROP_BOUNDARY=

gr7_prepare() {
  local caret_case=$1
  local text=$'First paragraph here.\n\nSecond paragraph.'
  GR7_NOTE_ID=
  case $caret_case in
    'paragraph start') GR7_FIXTURE=$text GR7_CARET=0 ;;
    'paragraph middle') GR7_FIXTURE=$text GR7_CARET=6 ;;
    'paragraph end') GR7_FIXTURE=$text GR7_CARET=21 ;;
    'empty line') GR7_FIXTURE=$'First paragraph here.\n\n\n\nSecond paragraph.' GR7_CARET=23 ;;
    'end of c50000-p24') GR7_NOTE_ID=c50000-p24 ;;
  esac
  if [[ -n $GR7_NOTE_ID ]]; then
    open_note c50000-p24 composer
    GR7_FIXTURE=$(<$CORPUS_DIR/c50000-p24.md)
    GR7_CARET=$(jget "$(state_get text=0)" length)
    GR7_EXPECTED_PREFIX=$GR7_FIXTURE
    GR7_EXPECTED_SUFFIX=$'\n'
  else
    open_text composer "$GR7_FIXTURE"
    if [[ $caret_case == 'empty line' ]]; then
      GR7_EXPECTED_PREFIX=$'First paragraph here.\n\n'
      GR7_EXPECTED_SUFFIX=$'\n\nSecond paragraph.'
    else
      GR7_EXPECTED_PREFIX=$'First paragraph here.'
      GR7_EXPECTED_SUFFIX=$'\n\nSecond paragraph.'
    fi
  fi
  focus_editor
  select_range $GR7_CARET $GR7_CARET
  sleep 0.2
}

gr7_begin() {
  probe_get 'nextPhoto?w=1600&h=1200&delayMs=500' >/dev/null
  GR7_BEFORE=$(state_get text=0)
}

gr7_drop_target() {
  local state
  state=$(state_get text=0)
  local -i count index target=0
  count=$(jcount "$state" blocks)
  for (( index = 0; index < count; index++ )); do
    (( $(jget "$state" blocks.$index.start) <= GR7_CARET )) && target=$index
  done
  local -F bottom height
  bottom=$(jget "$state" blocks.$target.globalBottom) || return 1
  height=$(jget "$state" view.height) || return 1
  if (( bottom + 3 > height )); then
    scroll_through 600
    state=$(state_get text=0)
    bottom=$(jget "$state" blocks.$target.globalBottom) || return 1
  fi
  local -F y=$(( bottom + 3 ))
  if (( target + 1 < count )); then
    y=$(( (bottom + $(jget "$state" blocks.$(( target + 1 )).globalTop)) / 2.0 ))
  fi
  (( y > height - 2 )) && y=$(( height - 2 ))
  GR7_DROP_BOUNDARY=$(jget "$state" blocks.$target.end)
  GR7_DROP_X=$(( $(jget "$state" view.width) / 2.0 ))
  GR7_DROP_Y=$y
}

gr7_drop_expected() {
  local lines=$1
  if (( GR7_DROP_BOUNDARY >= $(jget "$GR7_BEFORE" length) )); then
    print -rn -- "$GR7_FIXTURE$lines"$'\n'
  else
    print -rn -- "${GR7_FIXTURE[1,GR7_DROP_BOUNDARY]}$lines${GR7_FIXTURE[GR7_DROP_BOUNDARY+1,-1]}"
  fi
}

gr7_finish() {
  local name=$1
  local -i wanted=$2
  local toast=${3:-} mode=${4:-caret}
  local -i before_count=$(photo_count "$GR7_BEFORE") waited=0
  local placeholder=false state
  while (( waited < 200 )); do
    state=$(state_get text=0)
    (( $(jcount "$state" placeholders) > 0 )) && placeholder=true
    if (( $(photo_count "$state") >= before_count + wanted && $(jcount "$state" placeholders) == 0 )); then
      break
    fi
    sleep 0.025
    (( waited += 1 ))
  done
  sleep_ms $(plat_reveal_budget_ms)
  state=$(state_get)
  local -a refs=()
  local -i index count=$(photo_count "$state")
  local old_refs=" "
  for (( index = 0; index < before_count; index++ )); do
    old_refs+="$(jget "$GR7_BEFORE" photos.$index.reference) "
  done
  local lines=
  for (( index = 0; index < count; index++ )); do
    local ref
    ref=$(jget "$state" photos.$index.reference)
    if [[ $old_refs != *" $ref "* ]]; then
      lines+=$'\n'"![](photo/$ref \"right medium\")"
    fi
  done
  local expected_source
  if [[ $mode == drop ]]; then
    expected_source=$(gr7_drop_expected "$lines")
  elif [[ -z $GR7_NOTE_ID && $GR7_EXPECTED_PREFIX == *$'\n\n' ]]; then
    expected_source=$GR7_EXPECTED_PREFIX${lines#$'\n'}$GR7_EXPECTED_SUFFIX
  else
    expected_source=$GR7_EXPECTED_PREFIX$lines$GR7_EXPECTED_SUFFIX
  fi
  local selected=false revealed=false
  jget "$state" photoSelected >/dev/null && selected=true
  local height top bottom
  height=$(jget "$state" view.height)
  local -i last=$(( count - 1 ))
  if top=$(jget "$state" photos.$last.rect.1) && bottom=$(( top + $(jget "$state" photos.$last.rect.3) )); then
    (( top >= 0 && bottom <= height )) && revealed=true
  fi
  local toast_expected='"Photo added"' toast_seen
  toast_seen=$(bool_json text_present 'Photo added')
  local extra_expected= extra_observed=
  if [[ -n $toast ]]; then
    extra_expected=",\"skippedToast\":true"
    extra_observed=",\"skippedToast\":$(bool_json text_present "$toast")"
  fi
  expect_sample GR7 "$name" "{\"state\":{\"source\":$(json_str "$expected_source")},\"added\":$wanted,\"placeholderSeen\":true,\"toast\":true,\"photoSelected\":true,\"revealed\":true$extra_expected}" "{\"state\":$state,\"added\":$(( count - before_count )),\"placeholderSeen\":$placeholder,\"toast\":$toast_seen,\"photoSelected\":$selected,\"revealed\":$revealed,\"toastText\":$toast_expected$extra_observed}"
}

scenario_photo_insert_matrix() {
  local caret_case
  for caret_case in 'paragraph start' 'paragraph middle' 'paragraph end' 'empty line' 'end of c50000-p24'; do
    gr7_prepare "$caret_case"
    gr7_begin
    press_key composer-add-photo 110
    gr7_finish "$caret_case add memory" 1 ''
    plat_image_insert_cases "$caret_case"
  done
}

gr8_expected_caret() {
  local fixture=$PROBE_WORK/restore.json
  print -r -- "$1" > $fixture
  (cd $PROBE_REPO && dart run tool/probe/lib/gates.dart restore-caret $fixture 2>/dev/null)
}

gr8_case() {
  local name=$1 surface=$2 kill_mode=$3
  local typed='fog lifting'
  local photo=$(photo_line 1 'right medium')
  local original expected fixture entry=
  if [[ $surface == edit ]]; then
    original="Walk"$'\n\n'"$photo"
    expected="Walk $typed"$'\n\n'"$photo"
    fixture="{\"blocks\":[{\"source\":$(json_str "Walk $typed"),\"isPhoto\":false,\"unclosedFence\":false},{\"source\":$(json_str "$photo"),\"isPhoto\":true,\"unclosedFence\":false}],\"separators\":[\"\\n\\n\"]}"
    open_text composer "$original"
    entry=$OPENED_ENTRY
    focus_editor
    select_range 4 4
    plat_type " $typed"
  else
    expected=$typed
    fixture="{\"blocks\":[{\"source\":$(json_str "$typed"),\"isPhoto\":false,\"unclosedFence\":false}],\"separators\":[]}"
    open_text new ''
    focus_editor
    plat_type "$typed"
  fi
  if [[ $kill_mode == wait ]]; then
    sleep 0.5
    plat_kill
  else
    plat_kill --hide
  fi
  plat_launch $PROBE_BUILD
  if [[ $surface == edit ]]; then
    if [[ -z $entry ]]; then
      expect_sample GR8 "$name" '{"entryId":true}' '{"entryId":false}'
      return 0
    fi
    open_entry composer "$entry"
  else
    open_text new ''
  fi
  sleep 0.8
  local caret
  caret=$(gr8_expected_caret "$fixture") || caret=-1
  local state chip
  state=$(state_get)
  chip=$(bool_json text_present 'Draft restored')
  expect_sample GR8 "$name" "{\"state\":{\"source\":$(json_str "$expected"),\"canUndo\":false},\"selection\":[$caret,$caret],\"chip\":true}" "{\"state\":$state,\"selection\":$(selection_json "$state"),\"chip\":$chip}"
  probe_post save >/dev/null 2>&1 || true
  probe_post close >/dev/null 2>&1 || true
}

gr8_save_during_restore() {
  local typed='fog lifting'
  open_text new ''
  focus_editor
  plat_type "$typed"
  sleep 0.5
  plat_kill
  plat_launch $PROBE_BUILD
  probe_post 'flags?draftReadDelayMs=6000' >/dev/null
  open_text new ''
  local -i before_count=${OPENED_COUNT:--1}
  local saved ignored=false
  saved=$(probe_post save 2>/dev/null) || saved='{}'
  [[ $(jget "$saved" saved) == false ]] && ignored=true
  probe_post 'flags?draftReadDelayMs=0' >/dev/null
  sleep 6
  local state after_count chip
  state=$(state_get 'entries=1')
  after_count=$(jget "$state" entryCount) || after_count=-1
  chip=$(bool_json text_present 'Draft restored')
  expect_sample GR8 'save is ignored while the draft loads' "{\"saveIgnored\":true,\"entriesAdded\":0,\"state\":{\"source\":$(json_str "$typed")},\"chip\":true}" "{\"saveIgnored\":$ignored,\"entriesAdded\":$(( after_count - before_count )),\"state\":$state,\"chip\":$chip}"
  probe_post 'close?discard=1' >/dev/null 2>&1 || true
}

gr8_discard() {
  open_text new ''
  focus_editor
  plat_type 'discard me'
  sleep 0.8
  local closed discarded=false
  closed=$(probe_post 'close?discard=1' 2>/dev/null) || closed='{}'
  [[ $(jget "$closed" discarded) == true ]] && discarded=true
  sleep 0.5
  plat_kill
  plat_launch $PROBE_BUILD
  open_text new ''
  sleep 0.8
  local state
  state=$(state_get)
  expect_sample GR8 'a discarded note leaves no draft' '{"discarded":true,"state":{"source":""},"chip":false}' "{\"discarded\":$discarded,\"state\":$state,\"chip\":$(bool_json text_present 'Draft restored')}"
  probe_post 'close?discard=1' >/dev/null 2>&1 || true
}

scenario_draft_recovery() {
  local -i run
  for (( run = 1; run <= 20; run++ )); do
    gr8_case 'new note, wait 500 ms, kill' new wait
    gr8_case 'edit note, wait 500 ms, kill' edit wait
    gr8_case 'new note, hide and kill at once' new hide
    gr8_case 'edit note, hide and kill at once' edit hide
    gr8_save_during_restore
    gr8_discard
    open_text new ''
    focus_editor
    plat_type 'saved note'
    probe_post save >/dev/null
    probe_post close >/dev/null
    plat_kill
    plat_launch $PROBE_BUILD
    open_text new ''
    sleep 0.8
    local state
    state=$(state_get)
    expect_sample GR8 'a saved note leaves no draft' '{"state":{"source":""},"chip":false}' "{\"state\":$state,\"chip\":$(bool_json text_present 'Draft restored')}"
  done
}

gb1_note() {
  local row=$1 id=$2 label=$3
  local state
  state=$(state_get text=0)
  local -i length from
  length=$(jget "$state" length)
  for (( from = 0; from <= length; from += 2000 )); do
    local -i to=$(( from + 2000 > length ? length : from + 2000 ))
    sample "{\"row\":\"$row\",\"kind\":\"caret\",\"case\":$(json_str "$id $label $from"),\"caretAudit\":$(probe_get "caretAudit?from=$from&to=$to")}"
  done
}

scenario_caret_audit() {
  local id size scale
  for size in small medium large; do
    probe_post "settings?textSize=$size" >/dev/null
    for scale in $(plat_text_scales); do
      plat_set_text_scale $scale
      for id in $(corpus_ids); do
        open_note $id composer
        settle 500
        gb1_note GB1 $id "$size $scale"
      done
    done
  done
  plat_set_text_scale 1.0
  probe_post 'settings?textSize=medium' >/dev/null
}

gb2_note() {
  local row=$1 id=$2
  local -i samples=$3 index length
  length=$(jget "$(state_get text=0)" length)
  for (( index = 0; index < samples; index++ )); do
    local -i a=$(( RANDOM * 32768 + RANDOM )) b=$(( RANDOM % 400 + 1 ))
    local -i from=$(( length > 0 ? a % length : 0 ))
    local -i to=$(( from + b > length ? length : from + b ))
    select_range $from $to
    sleep 0.05
    sample "{\"row\":\"$row\",\"kind\":\"selection\",\"case\":$(json_str "$id $from-$to"),\"boxes\":$(probe_get "boxes?from=$from&to=$to")}"
  done
}

scenario_selection_audit() {
  RANDOM=${PROBE_SEED:-20260923}
  local id
  for id in $(corpus_ids); do
    open_note $id composer
    focus_editor
    gb2_note GB2 $id 200
  done
}

gb3_note() {
  local row=$1 id=$2
  local -i samples=$3 index length done_count=0 offset
  local rect left top width height landed
  length=$(jget "$(state_get text=0)" length)
  for (( index = 0; index < samples * 10 && done_count < samples; index++ )); do
    offset=$(( (RANDOM * 32768 + RANDOM) % (length > 1 ? length - 1 : 1) ))
    select_range $offset $offset
    sleep 0.05
    rect=$(glyph_in_view $offset) || continue
    left=$(jget "$rect" 0) && top=$(jget "$rect" 1) && width=$(jget "$rect" 2) && height=$(jget "$rect" 3) || continue
    (( width >= 3 )) || continue
    local -F share=$(( (RANDOM % 2 ? 0.2 : 0.6) + (RANDOM % 20) / 100.0 ))
    local -F x=$(( left + width * share )) y=$(( top + height / 2.0 ))
    plat_click $x $y 20 || continue
    sleep 0.1
    landed=$(jget "$(state_get text=0)" selection.1) || continue
    sample "{\"row\":\"$row\",\"kind\":\"click\",\"case\":$(json_str "$id $offset"),\"note\":$(json_str "$id"),\"clickX\":$x,\"glyphLeft\":$left,\"glyphRight\":$(( left + width )),\"offsetBefore\":$offset,\"offsetAfter\":$(( offset + 1 )),\"landed\":$landed}"
    (( done_count += 1 ))
  done
}

scenario_click_sweep() {
  RANDOM=${PROBE_SEED:-20260923}
  local id
  for id in $(corpus_ids); do
    open_note $id composer
    focus_editor
    gb3_note GB3 $id 500
  done
}

gb4_note() {
  local row=$1 id=$2
  local -i runs=$3 run length
  length=$(jget "$(state_get text=0)" length)
  local -i done_count=0
  for (( run = 0; run < runs; run++ )); do
    local -i offset=$(( (RANDOM * 32768 + RANDOM) % (length > 0 ? length : 1) ))
    select_range $offset $offset
    focus_editor
    sleep 0.1
    local state goal
    state=$(state_get text=0)
    goal=$(jget "$state" caret.0) || continue
    local direction=down
    (( RANDOM % 2 )) && direction=up
    local -i presses=$(( RANDOM % 5 + 1 )) press
    for (( press = 0; press < presses && done_count < runs; press++ )); do
      plat_key $direction
      sleep 0.12
      state=$(state_get "text=0&goalX=$goal")
      local caret advance shorter line_end
      caret=$(jget "$state" caret.0) || break
      advance=$(jget "$state" verticalGoal.glyphAdvance) || break
      shorter=$(jget "$state" verticalGoal.lineShorterThanGoal) || break
      line_end=$(jget "$state" verticalGoal.lineEndX) || break
      sample "{\"row\":\"$row\",\"kind\":\"vertical\",\"case\":$(json_str "$id $offset $direction $press"),\"caretX\":$caret,\"goalX\":$goal,\"glyphAdvance\":$advance,\"lineShorterThanGoal\":$shorter,\"lineEndX\":$line_end}"
      (( done_count += 1 ))
    done
  done
}

scenario_vertical_sweep() {
  RANDOM=${PROBE_SEED:-20260923}
  local -a ids=($(corpus_ids))
  local id
  local -i per=$(( (200 + ${#ids} - 1) / ${#ids} ))
  for id in $ids; do
    open_note $id composer
    gb4_note GB4 $id $per
  done
}

gb5_followers() {
  print -rl -- \
    'nothing|' \
    'paragraph|A paragraph follows the photo.' \
    'link paragraph|[A link](https://example.com/harbour) starts this paragraph.' \
    'autolink paragraph|<https://example.com/tide> starts this paragraph.' \
    'heading|## A heading follows' \
    'list|- rope\n- lantern' \
    'task list|- [ ] rope\n- [x] lantern' \
    'quote|> a quote follows' \
    'blank line|\n' \
    'code block|```\ncode\n```' \
    'divider|---' \
    'another photo|PHOTO2'
}

gb5_case() {
  local row=$1 column=$2 size=$3 side=$4 media=$5
  local ref=${media%%:*} rest=${media#*:}
  local width=${rest%%:*} height=${rest#*:}
  local photo="![](photo/$ref \"$side $size\")"
  local intro='An introduction paragraph sits above the photo.'
  local -a rects=()
  local entry label follower
  for entry in "${(@f)$(gb5_followers)}"; do
    label=${entry%%|*}
    follower=${(g::)entry#*|}
    [[ $follower == PHOTO2 ]] && follower=$(photo_line 2 'centre small')
    local text="$intro"$'\n\n'"$photo"
    [[ -n $follower ]] && text+=$'\n\n'"$follower"
    set_text "$text" 0 0
    sleep 0.15
    local rect
    rect=$(rect_json "$(state_get text=0)" photos.0.rect) && rects+=("$rect")
  done
  local text="$intro"$'\n\n'"$photo"$'\n\n'"Typing happens here."
  set_text "$text" ${#text} ${#text}
  focus_editor
  local -i step
  for (( step = 0; step < 20; step++ )); do
    plat_type x
    local rect
    rect=$(rect_json "$(state_get text=0)" photos.0.rect) && rects+=("$rect")
  done
  for (( step = 0; step < 20; step++ )); do
    plat_key backspace
    local rect
    rect=$(rect_json "$(state_get text=0)" photos.0.rect) && rects+=("$rect")
  done
  select_photo 0
  local state ring tilt em reader
  state=$(state_get text=0)
  ring=$(jget "$state" photos.0.ringDegrees) || ring=null
  tilt=$(jget "$state" photos.0.tiltDegrees) || tilt=null
  em=$(jget "$state" em)
  local observed_column
  observed_column=$(jget "$state" column)
  open_text viewer "$text"
  sleep 0.3
  reader=$(rect_json "$(state_get text=0)" photos.0.rect) || reader=null
  open_text composer "$text"
  sample "{\"row\":\"$row\",\"kind\":\"photo\",\"case\":$(json_str "$column $side $size"),\"column\":$observed_column,\"em\":$em,\"size\":\"$size\",\"side\":\"$side\",\"validPlacement\":true,\"pixelWidth\":$width,\"pixelHeight\":$height,\"rects\":[${(j:,:)rects}],\"readerRect\":$reader,\"ringDegrees\":$ring,\"tiltDegrees\":$tilt}"
}

scenario_placement_matrix() {
  local media=${$(fixture_media)%%,*}
  local column size side
  for column in 720 350; do
    probe_get "viewport?column=$column" >/dev/null
    open_text new ''
    for size in small medium large full; do
      for side in left centre right; do
        gb5_case GB5 $column $size $side $media
      done
    done
  done
  probe_get 'viewport?clear=1' >/dev/null
}

keyboard_cases() {
  print -rl -- \
    'C1 bold wraps the word at the caret|the quick fox|6|6|the **quick** fox|[8,8]|key:cmd+b' \
    'C1 bold removes markers|the **quick** fox|8|8|the quick fox|[6,6]|key:cmd+b' \
    'C1 italic writes a star|the quick fox|4|9|the *quick* fox||key:cmd+i' \
    'C1 strikethrough|the quick fox|4|9|the ~~quick~~ fox||key:shift+cmd+x' \
    'C1 highlight|the quick fox|4|9|the ==quick== fox||key:shift+cmd+h' \
    'C1 inline code|the quick fox|4|9|the `quick` fox||key:cmd+e' \
    'C1 link wraps the selection|the quick fox|4|9|the [quick]() fox|[12,12]|key:cmd+k' \
    'C1 link at a caret outside a word|the fox |8|8|the fox []()|[9,9]|key:cmd+k' \
    'C1 empty pair at a caret outside a word|the fox |8|8|the fox ****|[10,10]|key:cmd+b' \
    'C2 bullet list toggles on|a\nb\nc|0|5|- a\n- b\n- c||press:format-list' \
    'C2 bullet list toggles off|- a\n- b\n- c|0|11|a\nb\nc||press:format-list' \
    'C2 heading cycle plain to H1|title|0|0|# title||press:format-heading' \
    'C2 heading cycle H3 to plain|### title|4|4|title||press:format-heading' \
    'C2 heading cycle H5 to plain|##### title|6|6|title||press:format-heading' \
    'C3 numbered list|item|0|0|1. item||key:shift+cmd+7' \
    'C3 bullet list|item|0|0|- item||key:shift+cmd+8' \
    'C3 task list|item|0|0|- [ ] item||key:shift+cmd+9' \
    'C3 K2 cmd+l toggles the box|- [ ] passport|10|10|- [x] passport|[10,10]|key:cmd+l' \
    'C3 cmd+l makes a task item|passport|3|3|- [ ] passport||key:cmd+l' \
    'C4 enter in a nested ordered item|- first\n  1. second|19|19|- first\n  1. second\n  2. |[25,25]|key:enter' \
    'C4 enter in a checked task item|* [x] a|7|7|* [x] a\n* [ ] |[14,14]|key:enter' \
    'C4 enter after a lone ordered task|3. [ ] a|8|8|3. [ ] a\n4. [ ] |[16,16]|key:enter' \
    'C4 enter on an empty top-level item ends the list|- a\n- |6|6|- a\n|[4,4]|key:enter' \
    'C4 enter in a quote continues it|> quote|7|7|> quote\n> |[10,10]|key:enter' \
    'C4 enter on an empty quote line|> quote\n> |10|10|> quote\n|[8,8]|key:enter' \
    'C4 enter in a fence keeps indentation|```\n  code\n```|10|10|```\n  code\n  \n```|[13,13]|key:enter' \
    'C4 shift enter indents to the content column|- item|6|6|- item\n  |[9,9]|key:shift+enter' \
    'C5 tab indents a bullet item|- a\n- b|7|7|- a\n  - b|[9,9]|key:tab' \
    'C5 tab renumbers a new nested ordered list|1. a\n2. b|9|9|1. a\n   1. b|[12,12]|key:tab' \
    'C5 tab on a first item does nothing|- a|3|3|- a|[3,3]|key:tab' \
    'C5 shift tab outdents|- a\n  - b|9|9|- a\n- b|[7,7]|key:shift+tab' \
    'C6 backspace removes a top-level marker|- item|2|2|item|[0,0]|key:backspace' \
    'C6 backspace outdents a nested item|- a\n  - b|8|8|- a\n- b|[6,6]|key:backspace' \
    'C6 backspace removes a quote marker|> quote|2|2|quote|[0,0]|key:backspace' \
    'I8 option backspace deletes a word|the quick fox|13|13|the quick |[10,10]|key:opt+backspace' \
    'I8 ctrl a moves to the line start|the quick fox|9|9|the quick fox|[0,0]|key:ctrl+a' \
    'I8 cmd a selects all|the quick fox|3|3|the quick fox|[0,13]|key:cmd+a' \
    'I8 option right moves by word|the quick fox|0|0|the quick fox|[3,3]|key:opt+right' \
    'I8 shift option right extends by word|the quick fox|0|0|the quick fox|[0,3]|key:shift+opt+right' \
    'I8 cmd right moves to the line end|the quick fox|0|0|the quick fox|[13,13]|key:cmd+right' \
    'I8 cmd down moves to the document end|a\nb\nc|0|0|a\nb\nc|[5,5]|key:cmd+down' \
    'I8 shift cmd up extends to the document start|a\nb\nc|5|5|a\nb\nc|[5,0]|key:shift+cmd+up' \
    'I8 ctrl t transposes|abc|2|2|acb|[3,3]|key:ctrl+t' \
    'I8 ctrl k deletes to the line end|the quick fox|4|4|the |[4,4]|key:ctrl+k' \
    'I8 forward delete removes a grapheme|ab|0|0|b|[0,0]|key:delete' \
    'I8 cmd backspace deletes to the line start|the quick fox|9|9| fox|[0,0]|key:cmd+backspace' \
    'I8 collapsing a range moves to its end|the quick fox|4|9|the quick fox|[9,9]|key:right' \
    'I8 undo and redo|the quick fox|13|13|the quick fox x|[15,15]|type: x|key:cmd+z|key:shift+cmd+z' \
    'P2 right from the line before selects the photo|before\nPHOTO\nafter|6|6|before\nPHOTO\nafter|PHOTO_SELECTED|key:right' \
    'P2 backspace after a photo selects then removes it|before\nPHOTO\nafter|PHOTO_END_PLUS_1|PHOTO_END_PLUS_1|before\n\nafter||key:backspace|key:backspace' \
    'P2 typing with a photo selected adds a line|PHOTO|0|0|PHOTO\nh||photo:0|type:h' \
    'P2 enter with a photo selected adds an empty line|before\n\nPHOTO|0|0|before\n\nPHOTO\n||photo:0|key:enter' \
    'P1 tab from a selected photo enters the toolbar|before\n\nPHOTO|0|0|before\n\nPHOTO|TOOLBAR_FOCUS|photo:0|key:tab' \
    'P1 escape returns from the toolbar|before\n\nPHOTO|0|0|before\n\nPHOTO|PHOTO_SELECTED|photo:0|key:tab|key:escape' \
    'C7 escape deselects a photo and puts the caret after it|before\n\nPHOTO\n\nafter|0|0|before\n\nPHOTO\n\nafter|CARET_AFTER_PHOTO|photo:0|key:escape' \
    'P8 caption commits with enter|before\n\nPHOTO|0|0|before\n\nCAPTIONED||photo:0|press:photo-toolbar-caption|type:Low tide|key:enter' \
    'P8 caption cancels with escape|before\n\nPHOTO|0|0|before\n\nPHOTO||photo:0|press:photo-toolbar-caption|type:Low tide|key:escape' \
    'P8 caption commits with a click outside|before\n\nPHOTO|0|0|before\n\nCAPTIONED||photo:0|press:photo-toolbar-caption|type:Low tide|clickat:2' \
    'P2 left from the line after selects the photo|before\nPHOTO\nafter|PHOTO_END_PLUS_1|PHOTO_END_PLUS_1|before\nPHOTO\nafter|PHOTO_SELECTED|key:left' \
    'P2 right twice crosses the photo|before\nPHOTO\nafter|6|6|before\nPHOTO\nafter|CARET_AFTER_PHOTO|key:right|key:right' \
    'P2 up crosses a photo as one line|before\nPHOTO\nafter|PHOTO_END_PLUS_1|PHOTO_END_PLUS_1|before\nPHOTO\nafter|[0,0]|key:up|key:up' \
    'P2 down crosses a photo as one line|before\nPHOTO\nafter|0|0|before\nPHOTO\nafter|CARET_AFTER_PHOTO|key:down|key:down' \
    'P2 delete at the end of the line before selects the photo|before\nPHOTO\nafter|6|6|before\nPHOTO\nafter|PHOTO_SELECTED|key:delete' \
    'P2 delete twice removes the photo under P3|before\nPHOTO\nafter|6|6|before\n\nafter||key:delete|key:delete' \
    'P2 cmd x cuts a selected photo under P3|before\n\nPHOTO\n\nafter|0|0|before\n\nafter||photo:0|key:cmd+x' \
    'P2 cmd c copies a selected photo line|PHOTO\n\nafter\n\n|0|0|PHOTO\n\nafter\n\nPHOTO||photo:0|key:cmd+c|key:cmd+down|key:cmd+v' \
    'C9 a typed heading marker stays as typed||0|0|# title|[7,7]|type:# title' \
    'C9 a typed star pair is not auto-closed||0|0|**fog|[5,5]|type:**fog' \
    'C9 a typed bracket is not auto-closed||0|0|[link|[5,5]|type:[link'
}

macos_selector_cases() {
  print -rl -- \
    'I8 ctrl e moves to the line end (moveToEndOfLine)|the quick fox|0|0|the quick fox|[13,13]|key:ctrl+e' \
    'I8 ctrl b moves back a character (moveBackward)|the quick fox|5|5|the quick fox|[4,4]|key:ctrl+b' \
    'I8 ctrl f moves forward a character (moveForward)|the quick fox|5|5|the quick fox|[6,6]|key:ctrl+f' \
    'I8 ctrl p moves up a line (moveUp)|abc\nabc|5|5|abc\nabc|[1,1]|key:ctrl+p' \
    'I8 ctrl n moves down a line (moveDown)|abc\nabc|1|1|abc\nabc|[5,5]|key:ctrl+n' \
    'I8 ctrl d deletes forward (deleteForward)|abc|1|1|ac|[1,1]|key:ctrl+d' \
    'I8 ctrl h deletes backward (deleteBackward)|abc|1|1|bc|[0,0]|key:ctrl+h' \
    'I8 option up moves to the paragraph start (moveToBeginningOfParagraph)|first line\nsecond line|15|15|first line\nsecond line|[11,11]|key:opt+up' \
    'I8 option down moves to the paragraph end (moveToEndOfParagraph)|first line\nsecond line|2|2|first line\nsecond line|[10,10]|key:opt+down' \
    'I8 shift option up extends to the paragraph start (moveParagraphBackwardAndModifySelection)|first line\nsecond line|15|15|first line\nsecond line|[15,11]|key:shift+opt+up' \
    'I8 option delete deletes a word forward (deleteWordForward)|the quick fox|4|4|the  fox|[4,4]|key:opt+delete' \
    'I8 cmd up moves to the document start (moveToBeginningOfDocument)|a\nb\nc|5|5|a\nb\nc|[0,0]|key:cmd+up' \
    'I8 shift cmd left extends to the line start (moveToLeftEndOfLineAndModifySelection)|the quick fox|9|9|the quick fox|[9,0]|key:shift+cmd+left' \
    'I8 shift down extends by a line (moveDownAndModifySelection)|abc\nabc|1|1|abc\nabc|[1,5]|key:shift+down' \
    'I8 page down scrolls without moving the caret (scrollPageDown)|the quick fox|4|4|the quick fox|[4,4]|key:pagedown' \
    'I8 home scrolls without moving the caret (scrollToBeginningOfDocument)|the quick fox|4|4|the quick fox|[4,4]|key:home'
}

scenario_keyboard_matrix() {
  local photo=$(photo_line 1 'left medium')
  local captioned=$(photo_line 1 'left medium' 'Low tide')
  open_text new ''
  local -a cases=("${(@f)$(keyboard_cases)}")
  [[ $(plat_name) == macos ]] && cases+=("${(@f)$(macos_selector_cases)}")
  local entry
  for entry in $cases; do
    local -a fields=("${(@s:|:)entry}")
    local name=${fields[1]}
    local fixture=${(g::)fields[2]} expected=${(g::)fields[5]} selection=${fields[6]}
    fixture=${fixture//PHOTO/$photo}
    expected=${expected//CAPTIONED/$captioned}
    expected=${expected//PHOTO/$photo}
    local base=${fields[3]} extent=${fields[4]}
    if [[ $base == PHOTO_END_PLUS_1 ]]; then
      base=$(( ${#${fixture%%$photo*}} + ${#photo} + 1 ))
      extent=$base
    fi
    local focus=true
    case $selection in
      TOOLBAR_FOCUS) selection= focus=false ;;
      CARET_AFTER_PHOTO)
        local -i after=$(( ${#${fixture%%$photo*}} + ${#photo} + 1 ))
        selection="[$after,$after]"
        ;;
    esac
    case_run GB6 "$name" "$fixture" $base $extent "$expected" "$selection" $focus "${(@)fields[7,-1]}"
  done
  local walk="Walk"$'\n\n'"$photo"
  open_text new ''
  sleep 0.3
  local state
  state=$(state_get)
  expect_sample GB6 'C8 a new note focuses with the caret at 0' '{"state":{"focused":true},"selection":[0,0]}' "{\"state\":$state,\"selection\":$(selection_json "$state")}"
  open_text composer 'An existing note.'
  sleep 0.3
  state=$(state_get)
  expect_sample GB6 'C8 an edit composer puts the caret at the end' '{"state":{"focused":true},"selection":[17,17]}' "{\"state\":$state,\"selection\":$(selection_json "$state")}"
  open_text composer "$walk"
  sleep 0.3
  state=$(state_get)
  expect_sample GB6 'C8 a note ending with a photo puts the caret above it' '{"state":{"focused":true,"photoSelected":null},"selection":[4,4]}' "{\"state\":$state,\"selection\":$(selection_json "$state")}"
  open_text new ''
  set_text "$walk"
  sleep 0.8
  plat_kill
  plat_launch $PROBE_BUILD
  open_text new ''
  sleep 0.8
  state=$(state_get)
  expect_sample GB6 'C8 a restored draft follows C8 and clears history' '{"state":{"source":'"$(json_str "$walk")"',"canUndo":false,"focused":true},"selection":[4,4]}' "{\"state\":$state,\"selection\":$(selection_json "$state")}"
  probe_post 'close?discard=1' >/dev/null 2>&1 || true
  open_text new ''
  set_text 'the quick fox' 3 3
  focus_editor
  select_range 3 3
  plat_key escape
  sleep 0.4
  state=$(state_get)
  expect_sample GB6 'C7 escape with nothing to dismiss reaches the discard prompt' '{"discardPrompt":true,"state":{"source":"the quick fox"}}' "{\"discardPrompt\":$(bool_json key_present composer-discard),\"state\":$state}"
  press_key composer-keep-editing 60 || true
  open_text composer '- [ ] passport'
  focus_editor
  select_range 14 14
  local center
  if center=$(glyph_center "$(probe_get 'boxes?from=2&to=5')"); then
    plat_click ${center%% *} ${center##* } 60
    sleep 0.3
    state=$(state_get)
    expect_sample GB6 'K2 a click toggles the box and keeps the caret' '{"state":{"source":"- [x] passport","focused":true},"selection":[14,14]}' "{\"state\":$state,\"selection\":$(selection_json "$state")}"
  else
    expect_sample GB6 'K2 a click toggles the box and keeps the caret' '{"checkboxFound":true}' '{"checkboxFound":false}'
  fi
  local dragged="before"$'\n\n'"$photo"$'\n\n'"after"
  open_text composer "$dragged"
  local drag_state
  drag_state=$(state_get text=0)
  if center=$(rect_center "$drag_state" photos.0.rect); then
    local x=${center%% *} y=${center##* }
    plat_drag $x $y $x $(( y + 120 )) none 1200 &
    local drag=$!
    sleep 0.9
    plat_key escape
    wait $drag || true
    sleep 0.3
    state=$(state_get)
    expect_sample GB6 'P4 escape during a drag records no transaction' "{\"state\":{\"source\":$(json_str "$dragged")},\"transactionDelta\":0}" "{\"state\":$state,\"transactionDelta\":$(( $(transactions_of "$state") - $(transactions_of "$drag_state") ))}"
  fi
}

ime_fixture() {
  open_text composer 'fog '
  focus_editor
  select_range 4 4
  sleep 0.2
}

ime_expect() {
  local name=$1 expected=$2
  local state errors
  state=$(state_get)
  errors=$(errors_total 'errors?clear=1')
  expect_sample GB7 "$name" "{\"state\":{\"source\":$(json_str "$expected")},\"errors\":0}" "{\"state\":$state,\"errors\":$errors}"
}

ime_committed_expect() {
  local name=$1 script=${2:-any}
  local log committed=
  log=$(probe_get log)
  local -i count index
  count=$(jcount "$log" committed)
  for (( index = 0; index < count; index++ )); do
    jget_exact "$log" committed.$index && committed+=$REPLY
  done
  local state errors source=
  state=$(state_get)
  errors=$(errors_total 'errors?clear=1')
  jget_exact "$state" source && source=$REPLY
  local nonempty=false non_ascii=false changed=false
  [[ -n $committed ]] && nonempty=true
  [[ $committed == *[^\ -~]* ]] && non_ascii=true
  [[ $source != 'fog ' ]] && changed=true
  local wanted="\"nonEmpty\":true"
  [[ $script == non-ascii ]] && wanted+=",\"nonAscii\":true"
  expect_sample GB7 "$name" "{\"state\":{\"source\":$(json_str "fog $committed")},\"errors\":0,\"committed\":{$wanted},\"changed\":true}" "{\"state\":$state,\"errors\":$errors,\"committed\":{\"text\":$(json_str "$committed"),\"nonEmpty\":$nonempty,\"nonAscii\":$non_ascii},\"changed\":$changed}"
}

typeset -g A11Y_PHOTOS='[]' A11Y_CHECKBOXES='[]'

a11y_open() {
  A11Y_PHOTOS=${3:-'[]'}
  A11Y_CHECKBOXES=${4:-'[]'}
  open_text composer "$1"
  focus_editor
  select_range $2 $2
  sleep 0.3
}

a11y_select() {
  select_range $1 $1
  sleep 0.2
}

a11y_expect() {
  local name=$1 phrase=$2 reported=${3:-}
  sleep 0.6
  local spoken semantics
  spoken=$(plat_speech_last) || spoken=
  semantics=$(probe_get semantics)
  local extra=
  [[ -n $reported ]] && extra=',"reportedOnly":true'
  sample "{\"row\":\"GB8\",\"kind\":\"a11y\",\"case\":$(json_str "$name"),\"spoken\":$(json_str "$spoken"),\"phrase\":$(json_str "$phrase"),\"photos\":$A11Y_PHOTOS,\"checkboxes\":$A11Y_CHECKBOXES,\"semantics\":$semantics$extra}"
}

scenario_ime_matrix() {
  plat_ime_cases
}

scenario_a11y_matrix() {
  plat_a11y_cases
}

photo_titles_of() {
  grep -o 'photo/[0-9a-f]\{12\}[^)]*)' $CORPUS_DIR/$1.md | sed -e 's|^photo/[0-9a-f]* *||' -e 's|)$||' -e 's|"||g'
}

gb9_photos() {
  local id=$1 label=$2
  local state
  state=$(state_get text=0)
  local column em
  column=$(jget "$state" column)
  em=$(jget "$state" em)
  local -a titles=("${(@f)$(photo_titles_of $id)}")
  local -a refs=("${(@f)$(grep -o 'photo/[0-9a-f]\{12\}' $CORPUS_DIR/$id.md | sed 's|photo/||')}")
  local media=$(corpus_media $id)
  local -i index count=$(photo_count "$state")
  for (( index = 0; index < count && index < ${#titles}; index++ )); do
    local title=${titles[index + 1]:l} side=right size=medium word
    for word in ${=title}; do
      case $word in
        left|right) side=$word ;;
        centre|center) side=centre ;;
        small|medium|large|full) size=$word ;;
      esac
    done
    local ref=${refs[index + 1]} entry dims=0:0
    for entry in ${(s:,:)media}; do
      [[ $entry == $ref:* ]] && dims=${entry#*:}
    done
    local rect
    rect=$(rect_json "$state" photos.$index.rect) || continue
    sample "{\"row\":\"GB9\",\"kind\":\"photo\",\"case\":$(json_str "$label photo $index"),\"column\":$column,\"columnLeft\":$(jget "$state" columnLeft),\"em\":$em,\"size\":\"$size\",\"side\":\"$side\",\"validPlacement\":true,\"pixelWidth\":${dims%%:*},\"pixelHeight\":${dims#*:},\"rects\":[$rect]}"
    if [[ $side != centre && $size != full ]] && ! is_phone_column; then
      local top height
      top=$(jget "$state" photos.$index.rect.1)
      height=$(jget "$state" photos.$index.rect.3)
      local offset
      offset=$(jget "$(probe_get "offsetAt?x=$(( column / 2.0 ))&y=$(( top + 4 ))")" offset) || continue
      local boxes
      boxes=$(probe_get "boxes?from=$offset&to=$(( offset + 600 ))")
      local -a fragments=()
      local -i box boxes_count
      boxes_count=$(jcount "$boxes" selection)
      for (( box = 0; box < boxes_count; box++ )); do
        local box_top box_left box_width
        box_top=$(jget "$boxes" selection.$box.1)
        (( box_top < top + height - 0.5 )) || continue
        box_left=$(jget "$boxes" selection.$box.0)
        box_width=$(jget "$boxes" selection.$box.2)
        fragments+=("[$box_left,$(( box_left + box_width ))]")
      done
      sample "{\"row\":\"GB9\",\"kind\":\"float\",\"case\":$(json_str "$label float $index"),\"floatRect\":$rect,\"side\":\"$side\",\"em\":$em,\"fragments\":[${(j:,:)fragments}]}"
    fi
  done
}

scenario_window_scale_matrix() {
  RANDOM=${PROBE_SEED:-20260923}
  local size column
  for size in small medium large; do
    probe_post "settings?textSize=$size" >/dev/null
    for column in $(plat_columns $size); do
      probe_get "viewport?column=$column" >/dev/null
      open_note c20000-p8 composer
      focus_editor
      settle 500
      local label="$size $column"
      gb1_note GB9 c20000-p8 "$label"
      gb2_note GB9 "c20000-p8 $label" 20
      gb3_note GB9 "c20000-p8 $label" 20
      gb4_note GB9 "c20000-p8 $label" 20
      gb9_photos c20000-p8 "$label"
    done
  done
  probe_get 'viewport?clear=1' >/dev/null
  probe_post 'settings?textSize=medium' >/dev/null
}

lines_json() {
  local state=$1 key=${2:-lines}
  local -i count index
  count=$(jcount "$state" $key)
  local -a texts=()
  for (( index = 0; index < count; index++ )); do
    jget_exact "$state" $key.$index.text || REPLY=
    texts+=("$(json_str "$REPLY")")
  done
  print -rn -- "[${(j:,:)texts}]"
}

tops_json() {
  local state=$1 key=${2:-blocks}
  local -i count index
  count=$(jcount "$state" $key)
  local -a tops=()
  for (( index = 0; index < count; index++ )); do
    tops+=("$(jget "$state" $key.$index.top)")
  done
  print -rn -- "[${(j:,:)tops}]"
}

short_fixtures() {
  print -rl -- \
    'The fog lifted at noon.' \
    '# Harbour day\nThe tide ran out past the pier.' \
    'A **bold** start and an *italic* finish.' \
    '- rope\n- lantern\n- shell' \
    '> a quiet quote about the gulls' \
    'Two paragraphs.\n\nThe second one is short.' \
    'A line with ==highlight== and `code`.' \
    '- [ ] passport\n- [x] tickets' \
    'café by the harbour, and a long sentence that wraps across the card at its narrow width.' \
    'The last fixture has a [link](https://example.com/tide) in it.'
}

scenario_reader_parity() {
  local size column id
  for size in small medium large; do
    probe_post "settings?textSize=$size" >/dev/null
    for column in $(plat_columns $size); do
      probe_get "viewport?column=$column" >/dev/null
      for id in $(corpus_ids); do
        open_note $id composer
        local state
        state=$(state_get text=0)
        plat_click 2 $(( $(jget "$state" view.height) - 2 )) 20
        sleep 0.3
        local composer viewer
        composer=$(state_get text=0)
        open_note $id viewer
        sleep 0.3
        viewer=$(state_get text=0)
        sample "{\"row\":\"GB10\",\"kind\":\"parity\",\"case\":$(json_str "$id $size $column"),\"composerLines\":$(lines_json "$composer"),\"viewerLines\":$(lines_json "$viewer"),\"composerTops\":$(tops_json "$composer"),\"viewerTops\":$(tops_json "$viewer")}"
      done
    done
    probe_get 'viewport?clear=1' >/dev/null
    local fixture surface
    local -i number=0
    for fixture in "${(@f)$(short_fixtures)}"; do
      (( number += 1 ))
      for surface in feed-card day-card; do
        open_text $surface "${(g::)fixture}"
        sleep 0.3
        local card
        card=$(state_get 'text=0&reference=1')
        sample "{\"row\":\"GB10\",\"kind\":\"parity\",\"case\":$(json_str "short $number $surface $size"),\"composerLines\":$(lines_json "$card"),\"viewerLines\":$(lines_json "$card" referenceLines),\"composerTops\":$(tops_json "$card" lines),\"viewerTops\":$(tops_json "$card" referenceLines)}"
      done
    done
  done
  probe_post 'settings?textSize=medium' >/dev/null
}

toolbar_case() {
  local name=$1 want=$2
  scroll_photo_to $want
  select_photo 0
  sleep 0.3
  local keys state toolbar photo surface
  keys=$(probe_get 'keys?prefix=photo-toolbar')
  state=$(state_get text=0)
  toolbar=$(rect_json "$keys" photo-toolbar) || { expect_sample GB11 "$name" '{"toolbarShown":true}' '{"toolbarShown":false}'; return 0; }
  photo=$(rect_json "$state" photos.0.rect) || return 0
  surface=$(rect_json "$state" writingSurface) || { expect_sample GB11 "$name" '{"writingSurface":true}' '{"writingSurface":false}'; return 0; }
  sample "{\"row\":\"GB11\",\"kind\":\"toolbar\",\"case\":$(json_str $name),\"toolbar\":$toolbar,\"surface\":$surface,\"photo\":$photo}"
}

scenario_toolbar_placement() {
  local -a paragraphs=()
  local -i index
  for (( index = 1; index <= 16; index++ )); do
    paragraphs+=("Paragraph $index of the placement note keeps enough text around the photo to scroll it anywhere in the view.")
  done
  local around="${(pj:\n\n:)paragraphs}"
  local title
  for title in 'left medium' 'centre medium' 'centre full'; do
    open_text composer "$around"$'\n\n'"$(photo_line 1 "$title")"$'\n\n'"$around"
    local state height
    state=$(state_get text=0)
    height=$(jget "$state" view.height)
    toolbar_case "$title photo at the top of the view" 0
    toolbar_case "$title photo in the middle of the view" $(( height / 2.0 - 120 ))
    toolbar_case "$title photo at the bottom of the view" $(( height - 200 ))
  done
  local tall_ref=$(fixture_ref 4)
  open_text composer "$around"$'\n\n'"![](photo/$tall_ref \"centre full\")"$'\n\n'"$around"
  toolbar_case 'photo taller than the view, top edge visible' 40
  toolbar_case 'photo taller than the view, scrolled past its top' -300
}

scenario_perf_memory() {
  local media= entry
  for entry in ${(s:,:)$(corpus_media c50000-p24)}; do
    media+="${media:+,}${entry%%:*}:4000:3000"
  done
  open_note c50000-p24 composer "$media"
  local pid
  pid=$(probe_get pid | json_get pid)
  local rss_log=$PROBE_WORK/rss.log
  : > $rss_log
  ( while kill -0 $pid 2>/dev/null; do plat_rss $pid >> $rss_log 2>/dev/null || true; sleep 0.25; done ) &
  local sampler=$!
  settle 1000
  scroll_through 120
  scroll_to_top
  scroll_through 120
  sleep 1
  kill $sampler 2>/dev/null || true
  wait $sampler 2>/dev/null || true
  local peak
  peak=$(sort -n $rss_log | tail -1)
  local state
  state=$(state_get text=0)
  sample "{\"row\":\"GP7\",\"kind\":\"memory\",\"case\":\"c50000-p24 at 4000 x 3000\",\"peakRssBytes\":${peak:-0},\"imageCacheBytes\":$(jget "$state" imageCacheBytes || print -rn 0),\"oversizeDecodes\":$(jget "$state" oversizeDecodes || print -rn 0)}"
}

drive_check() {
  local -i missing=0
  local scenario name
  for scenario in $PROBE_SCENARIOS; do
    name=scenario_${scenario//-/_}
    if ! whence -w $name | grep -q ': function$'; then
      print -u2 -r -- "drive: $scenario has no $name function"
      missing=1
    fi
  done
  for name in $PROBE_PRIMITIVES $PROBE_CASE_HOOKS; do
    if ! whence -w $name | grep -q ': function$'; then
      print -u2 -r -- "drive: $name is not defined"
      missing=1
    fi
  done
  return $missing
}

drive_usage() {
  print -u2 -r -- "usage: drive.sh --list | --check | --library | <scenario> <profile|debug> <result.json>"
}

drive_main() {
  case ${1:-} in
    --list)
      print -rl -- $PROBE_SCENARIOS
      return 0
      ;;
    --check)
      drive_check
      return $?
      ;;
    --library)
      return 0
      ;;
  esac
  if (( $# != 3 )) || (( ! ${PROBE_SCENARIOS[(Ie)$1]} )) || [[ $2 != profile && $2 != debug ]]; then
    drive_usage
    return 2
  fi
  PROBE_BUILD=$2
  PROBE_WORK=$(mktemp -d "${TMPDIR:-/tmp}/field_notes_probe.XXXXXX")
  trap 'rm -rf -- $PROBE_WORK' EXIT
  result_begin $1 $2 $3
  local -i drive_status=0
  scenario_${1//-/_} &
  wait $! || drive_status=$?
  result_end
  return $drive_status
}

if [[ ${1:-} == --library ]]; then
  return 0
fi

drive_main "$@"
exit $?
