display_clear_history() {
  printf '\033[H\033[2J\033[3J'
}

display_cursor_hide() {
  printf '\033[?25l'
}

display_cursor_show() {
  printf '\033[?25h'
}

display_cursor_position() {
  printf '\033[%s;%sH' "$1" "$2"
}

display_read_key() {
  local key
  local rest
  IFS= read -r -s -n 1 key </dev/tty
  if [ "$key" = $'\033' ]; then
    rest=
    if IFS= read -r -s -t 0.1 -n 1 rest </dev/tty && [ "$rest" = '[' ]; then
      key=$key$rest
      rest=
      if IFS= read -r -s -t 0.1 -n 1 rest </dev/tty; then
        key=$key$rest
      fi
    fi
  fi
  printf '%s' "$key"
}

display_info() {
  local id
  id=$1
  db_value "
SELECT objects.id || char(9) || artists.name || char(9) || cats.name ||
       char(9) || COALESCE(topics.name, '-')
FROM objects
JOIN artists ON artists.id = objects.artist_id
JOIN cats ON cats.id = objects.cat_id
LEFT JOIN topics ON topics.id = objects.topic_id
WHERE objects.id = $id;
"
}

display_image_start() {
  local path
  local rows
  local cols
  local mime
  path=$1
  rows=$2
  cols=$3
  mime=$4
  (
    local image_pid
    trap '
      kill "$image_pid" 2>/dev/null || true
      wait "$image_pid" 2>/dev/null || true
      display_cursor_hide
      exit 143
    ' TERM
    display_cursor_position 1 1
    if [ "$mime" = image/gif ]; then
      chafa --probe off --format "$ARTS_DISPLAY_FORMAT" --animate on \
        --duration infinite --align top,left \
        --size "${cols}x$((rows - 7))" "$path" &
    else
      chafa --probe off --format "$ARTS_DISPLAY_FORMAT" --animate off \
        --align top,left --size "${cols}x$((rows - 7))" "$path" &
    fi
    image_pid=$!
    wait "$image_pid"
    display_cursor_hide
  ) &
  DISPLAY_IMAGE_PID=$!
}

display_image_stop() {
  local status
  if [ -z "$DISPLAY_IMAGE_PID" ]; then return 0; fi
  status=0
  if kill -0 "$DISPLAY_IMAGE_PID" 2>/dev/null; then
    kill "$DISPLAY_IMAGE_PID" 2>/dev/null || true
  fi
  wait "$DISPLAY_IMAGE_PID" 2>/dev/null || status=$?
  DISPLAY_IMAGE_PID=
  [ "$status" -eq 0 ] || [ "$status" -eq 143 ]
}

display_metadata() {
  local rows
  local artist
  local album
  local character
  local sha
  rows=$1
  artist=$2
  album=$3
  character=$4
  sha=$5
  printf '\033[%s;1H' "$((rows - 6))"
  pair_reset
  pair_add artist "$artist"
  pair_add cat "$album"
  pair_add topic "$character"
  pair_add sha256 "$sha"
  pair_print
}

display_browser() {
  local total
  local selected
  local image_total
  local image_selected
  local rows
  local cols
  local target
  local type
  local id
  local ids
  local record
  local info
  local sha
  local artist
  local album
  local character
  local mime
  local key
  local path
  local pager
  local position
  local -a image_ids
  total=$#
  if ((total == 0)); then
    echo "no images found"
    return 0
  fi
  selected=${DISPLAY_SELECTED:-0}
  if ((selected >= total)); then selected=$((total - 1)); fi
  if ((selected < 0)); then selected=0; fi
  image_selected=0
  while :; do
    position=$((selected + 1))
    target=${!position}
    type=$(object_type "$target")
    image_ids=()
    ids=$(db_value "
SELECT images.id FROM images
WHERE images.object_id = $target
ORDER BY images.position;
")
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      image_ids+=("$id")
    done <<<"$ids"
    image_total=${#image_ids[@]}
    [ "$image_total" -gt 0 ] || {
      echo "object is empty: $target" >&2
      return 1
    }
    if ((image_selected >= image_total)); then
      image_selected=$((image_total - 1))
    fi
    id=${image_ids[$image_selected]}
    record=$(image_file_require "$id")
    IFS=$'\t' read -r _ sha artist mime _ <<<"$record"
    info=$(display_info "$target")
    IFS=$'\t' read -r _ artist album character <<<"$info"
    path=$(image_path "$artist" "$sha")
    if [ ! -r "$path" ]; then
      echo "stored image not found: $path" >&2
      return 1
    fi
    rows=24
    cols=80
    read -r rows cols < <(stty size </dev/tty 2>/dev/null || printf '24 80\n')
    if ((rows < 10)); then rows=10; fi
    if ((cols < 20)); then cols=20; fi
    display_clear_history
    display_metadata "$rows" "$artist" "$album" "$character" "$sha"
    pager=$(printf '[%s/%s][%s/%s]' "$((selected + 1))" "$total" \
      "$((image_selected + 1))" "$image_total")
    printf '\033[%s;1H\033[2K%s' "$rows" "$pager"
    printf '\033[H'
    display_image_start "$path" "$rows" "$cols" "$mime"
    while :; do
      key=$(display_read_key)
      case "$key" in
        $'\033[A')
          ((selected > 0)) && break
          ;;
        $'\033[B')
          ((selected + 1 < total)) && break
          ;;
        $'\033[D')
          ((image_selected > 0)) && break
          ;;
        $'\033[C')
          ((image_selected + 1 < image_total)) && break
          ;;
        x | X)
          [ "$type" = sequence ] && break
          ;;
        d | D | b | B | q | Q | $'\033') break ;;
      esac
    done
    if ! display_image_stop; then
      printf '\033[%s;1H\n' "$rows"
      return 1
    fi
    printf '\033[%s;1H\033[2K' "$rows"
    case "$key" in
      $'\033[A')
        selected=$((selected - 1))
        image_selected=0
        ;;
      $'\033[B')
        selected=$((selected + 1))
        image_selected=0
        ;;
      $'\033[D')
        image_selected=$((image_selected - 1))
        ;;
      $'\033[C')
        image_selected=$((image_selected + 1))
        ;;
      x | X)
        if [ "$type" = sequence ] && \
          action_sequence_image_remove "$target" "$id" \
            "$((image_selected + 1))"; then
          if [ -z "$(object_type "$target")" ]; then
            DISPLAY_SELECTED=$selected
            return 10
          fi
        fi
        ;;
      d | D)
        if action_remove "$target"; then
          DISPLAY_SELECTED=$selected
          return 10
        fi
        ;;
      b | B | q | Q | $'\033')
        display_clear_history
        return 0
        ;;
    esac
  done
}
