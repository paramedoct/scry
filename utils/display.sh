display_action_confirm() {
  local prompt
  local answer
  prompt=$1
  printf '%s' "$prompt [y/N]: " >/dev/tty
  IFS= read -r answer </dev/tty
  case "$answer" in
    y | Y) return 0 ;;
    *) return 1 ;;
  esac
}

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

display_image_start() {
  local path
  local rows
  local cols
  local mime
  local view_size
  path=$1
  rows=$2
  cols=$3
  mime=$4
  view_size="${cols}x$((rows - 7))"
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
      chafa --probe off --format "$SCRY_DISPLAY_FORMAT" --animate on \
        --duration infinite --scale max --align top,left \
        --size "$view_size" "$path" &
    else
      chafa --probe off --format "$SCRY_DISPLAY_FORMAT" --animate off \
        --scale max --align top,left --size "$view_size" "$path" &
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

display_browser() {
  local total
  local selected
  local image_total
  local image_selected
  local image_rows
  local rows
  local cols
  local target
  local id
  local record
  local records
  local sha
  local artist
  local cat
  local topic
  local mime
  local key
  local path
  local search_pager
  local image_pager
  local search_col
  local search_delta
  local image_delta
  local position
  local -a images
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
    images=()
    records=$(db_value "
SELECT images.id || char(9) || images.sha256 || char(9) || artists.name ||
       char(9) || images.mime_type || char(9) || cats.name || char(9) ||
       COALESCE(topics.name, '-')
FROM images
JOIN sequences ON sequences.id = images.sequence_id
JOIN artists ON artists.id = sequences.artist_id
JOIN cats ON cats.id = sequences.cat_id
LEFT JOIN topics ON topics.id = sequences.topic_id
WHERE sequences.id = $target ORDER BY images.position;
")
    while IFS= read -r record; do
      [ -n "$record" ] && images+=("$record")
    done <<<"$records"
    image_total=${#images[@]}
    [ "$image_total" -gt 0 ] || {
      echo "sequence is empty: $target" >&2
      return 1
    }
    if ((image_selected >= image_total)); then
      image_selected=$((image_total - 1))
    fi
    record=${images[$image_selected]}
    IFS=$'\t' read -r id sha artist mime cat topic <<<"$record"
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
    image_rows=$(chafa --probe off --format symbols --colors none \
      --symbols ascii --animate off --scale max --align top,left \
      --size "${cols}x$((rows - 7))" --work 1 "$path" |
      awk 'END { print NR }')
    display_clear_history
    printf '\033[%s;1H' "$((image_rows + 1))"
    printf '%-6s %s\n%-6s %s\n%-6s %s\n' \
      artist "$artist" cat "$cat" topic "$topic"
    search_pager=$(printf '[%s/%s]' "$((selected + 1))" "$total")
    search_col=$((cols - ${#search_pager} + 1))
    printf '\033[%s;1H\033[2K' "$rows"
    image_pager=$(printf '[%s/%s]' "$((image_selected + 1))" "$image_total")
    printf '%s' "$image_pager"
    if ((search_col > ${#image_pager} + 1)); then
      display_cursor_position "$rows" "$search_col"
      printf '%s' "$search_pager"
    else
      printf ' %s' "$search_pager"
    fi
    printf '\033[H'
    display_image_start "$path" "$rows" "$cols" "$mime"
    while :; do
      key=$(display_read_key)
      search_delta=0
      image_delta=0
      case "$key" in
        $'\033[A') search_delta=-1 ;;
        $'\033[B') search_delta=1 ;;
        $'\033[D') image_delta=-1 ;;
        $'\033[C') image_delta=1 ;;
        x | X) break ;;
        d | D | b | B | q | Q | $'\033') break ;;
        *) continue ;;
      esac
      if ((selected + search_delta >= 0 &&
        selected + search_delta < total &&
        image_selected + image_delta >= 0 &&
        image_selected + image_delta < image_total)); then
        break
      fi
    done
    if ! display_image_stop; then
      printf '\033[%s;1H\n' "$rows"
      return 1
    fi
    printf '\033[%s;1H\033[2K' "$rows"
    selected=$((selected + search_delta))
    if ((search_delta == 0)); then
      image_selected=$((image_selected + image_delta))
    else
      image_selected=0
    fi
    case "$key" in
      x | X)
        if display_action_confirm \
          "remove image $((image_selected + 1)) from sequence $target" &&
          image_remove "$id" "$target"; then
          if [ -z "$(db_value \
            "SELECT id FROM sequences WHERE id = $target;")" ]; then
            DISPLAY_SELECTED=$selected
            return 10
          fi
        fi
        ;;
      d | D)
        if display_action_confirm "remove sequence $target" &&
          sequence_remove "$target"; then
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
