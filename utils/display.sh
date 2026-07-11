display_validate_limit() {
  case "${1:-}" in
    '' | *[!0-9]* | 0)
      echo "limit must be a positive integer: ${1:-}" >&2
      return 1
      ;;
  esac
  if [ "$1" -gt 10 ]; then
    echo "limit must not exceed 10: $1" >&2
    return 1
  fi
}

display_auto_layout() {
  local rows
  local cols
  local grid_cols
  local grid_rows
  local required
  local limit
  local min_preview_rows
  rows=24
  cols=80
  min_preview_rows=10
  read -r rows cols < <(stty size </dev/tty 2>/dev/null || printf '24 80\n')
  case "$rows:$cols" in
    *[!0-9:]* | 0:* | *:0) rows=24; cols=80 ;;
  esac
  grid_cols=$((cols / 20))
  if ((grid_cols < 1)); then grid_cols=1; fi
  if ((grid_cols > 5)); then grid_cols=5; fi
  grid_rows=1
  limit=$grid_cols
  while ((grid_rows <= 2)); do
    required=$((2 + grid_rows * min_preview_rows))
    if ((required > rows)); then break; fi
    limit=$((grid_cols * grid_rows))
    grid_rows=$((grid_rows + 1))
  done
  printf '%s %s\n' "$limit" "$grid_cols"
}

display_clear_history() {
  printf '\033[H\033[2J\033[3J'
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
SELECT objects.id || char(9) || artists.name || char(9) || albums.name ||
       char(9) || COALESCE(characters.name, '-')
FROM objects
JOIN artists ON artists.id = objects.artist_id
JOIN albums ON albums.id = objects.album_id
LEFT JOIN characters ON characters.id = objects.character_id
WHERE objects.id = $id;
"
}

display_image() {
  local id
  local record
  local sha
  local artist
  local mime
  local info
  local album
  local character
  local path
  local rows
  local cols
  id=$1
  record=$(image_require "$id")
  IFS=$'\t' read -r _ sha artist mime _ <<<"$record"
  info=$(display_info "$id")
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
  chafa --align top,left --size "${cols}x$((rows - 7))" "$path"
  printf 'artist %s\n' "$artist"
  printf 'album %s\n' "$album"
  printf 'character %s\n' "$character"
  printf 'mime %s\n' "${mime#image/}"
  printf 'sha256 %s\n' "$sha"
}

display_image_browser() {
  local id
  local rows
  local cols
  local key
  local message
  id=$1
  message=
  while :; do
    printf '\033[2J\033[H'
    display_image "$id"
    [ -z "$message" ] || printf '%s\n' "$message"
    rows=24
    cols=80
    read -r rows cols < <(stty size </dev/tty 2>/dev/null || printf '24 80\n')
    if ((rows < 10)); then rows=10; fi
    printf '\033[%s;1H\033[2K[1/1]' "$rows"
    key=$(display_read_key)
    printf '\033[%s;1H\033[2K' "$rows"
    message=
    case "$key" in
      d | D)
        if action_remove "$id"; then return 10; fi
        ;;
      b | B | q | Q | $'\033')
        return 0
        ;;
      *) message="unknown key: $key" ;;
    esac
  done
}

display_sequence_browser() {
  local sequence_id
  local total
  local selected
  local shown_selected
  local rows
  local cols
  local id
  local record
  local info
  local sha
  local artist
  local mime
  local album
  local character
  local key
  local message
  local path
  local -a ids
  local -a paths
  local -a artists
  local -a albums
  local -a characters
  local -a mimes
  local -a shas
  sequence_id=$1
  shift
  ids=("$@")
  total=${#ids[@]}
  [ "$total" -gt 0 ] || {
    echo "sequence is empty: $sequence_id" >&2
    return 1
  }
  paths=()
  artists=()
  albums=()
  characters=()
  mimes=()
  shas=()
  for id in "${ids[@]}"; do
    record=$(image_file_require "$id")
    IFS=$'\t' read -r _ sha artist mime _ <<<"$record"
    info=$(display_info "$sequence_id")
    IFS=$'\t' read -r _ artist album character <<<"$info"
    path=$(image_path "$artist" "$sha")
    if [ ! -r "$path" ]; then
      echo "stored image not found: $path" >&2
      return 1
    fi
    paths+=("$path")
    artists+=("$artist")
    albums+=("$album")
    characters+=("$character")
    mimes+=("${mime#image/}")
    shas+=("$sha")
  done
  selected=0
  shown_selected=-1
  message=
  while :; do
    rows=24
    cols=80
    read -r rows cols < <(stty size </dev/tty 2>/dev/null || printf '24 80\n')
    if ((rows < 10)); then rows=10; fi
    if ((cols < 20)); then cols=20; fi
    if ((shown_selected >= 0 && shown_selected != selected)); then
      display_clear_history
    else
      printf '\033[2J\033[H'
    fi
    if ! chafa --animate on --duration 0 --align top,left \
      --size "${cols}x$((rows - 7))" "${paths[$selected]}"; then
      printf '\033[%s;1H\n' "$rows"
      return 1
    fi
    shown_selected=$selected
    printf 'artist %s\n' "${artists[$selected]}"
    printf 'album %s\n' "${albums[$selected]}"
    printf 'character %s\n' "${characters[$selected]}"
    printf 'mime %s\n' "${mimes[$selected]}"
    printf 'sha256 %s\n' "${shas[$selected]}"
    [ -z "$message" ] || printf '%s\n' "$message"
    printf '\033[%s;1H\033[2K[%s/%s]' "$rows" "$((selected + 1))" "$total"
    key=$(display_read_key)
    printf '\033[%s;1H\033[2K' "$rows"
    message=
    case "$key" in
      $'\033[A' | $'\033[D')
        if ((selected > 0)); then
          selected=$((selected - 1))
        else
          message='first image'
        fi
        ;;
      $'\033[B' | $'\033[C')
        if ((selected + 1 < total)); then
          selected=$((selected + 1))
        else
          message='last image'
        fi
        ;;
      x | X)
        if action_sequence_image_remove "$sequence_id" "${ids[$selected]}" \
          "$((selected + 1))"; then
          return 10
        fi
        ;;
      d | D)
        if action_remove "$sequence_id"; then return 10; fi
        ;;
      b | B | q | Q | $'\033')
        printf '\033[2J\033[H'
        return 0
        ;;
      *) message="unknown key: $key" ;;
    esac
  done
}

display_target() {
  local target
  local type
  local ids
  local id
  local -a image_ids
  target=$1
  type=$(object_type "$target")
  case "$type" in
    image)
      display_image_browser "$target"
      ;;
    sequence)
      image_ids=()
      ids=$(sequence_image_ids "$target")
      while IFS= read -r id; do
        [ -n "$id" ] || continue
        image_ids+=("$id")
      done <<<"$ids"
      display_sequence_browser "$target" "${image_ids[@]}"
      ;;
  esac
}

display_previews() {
  local grid
  local help
  local path
  grid=${DISPLAY_GRID_COLS:-auto}
  help=$(chafa --help 2>&1)
  case "$help" in
    *--grid*)
      chafa --grid "$grid" --label on --link off --align bottom,center \
        --animate on --duration 0 "$@"
      ;;
    *)
      for path in "$@"; do
        chafa --size 32x16 --align bottom,center "$path"
      done
      ;;
  esac
}

display_page() {
  local page
  local limit
  local total
  local start
  local end
  local index
  local target
  local type
  local id
  local record
  local sha
  local artist
  local path
  local preview
  local preview_dir
  local -a paths
  page=$1
  limit=$2
  shift 2
  total=$#
  start=$((page * limit))
  end=$((start + limit))
  if ((end > total)); then
    end=$total
  fi
  paths=()
  preview_dir=$(mktemp -d "$ARTS_STATE_DIR/.previews.XXXXXX")
  index=0
  for target in "$@"; do
    if ((index >= start && index < end)); then
      type=$(object_type "$target")
      case "$type" in
        image) id=$target ;;
        sequence)
          id=$(db_value "
SELECT images.id FROM images
WHERE images.object_id = $target
ORDER BY position LIMIT 1;
")
          if [ -z "$id" ]; then
            rm -rf "$preview_dir"
            echo "sequence not found or empty: $target" >&2
            return 1
          fi
          ;;
      esac
      if [ "$type" = image ]; then
        record=$(image_require "$id")
      else
        record=$(image_file_require "$id")
      fi
      IFS=$'\t' read -r _ sha artist _ <<<"$record"
      path=$(image_path "$artist" "$sha")
      if [ ! -r "$path" ]; then
        rm -rf "$preview_dir"
        echo "stored image not found: $path" >&2
        return 1
      fi
      preview=$(printf '%s/[%s]' "$preview_dir" "$((index - start))")
      ln -s "$path" "$preview"
      paths+=("$preview")
    fi
    index=$((index + 1))
  done
  if ! display_previews "${paths[@]}"; then
    rm -rf "$preview_dir"
    return 1
  fi
  rm -rf "$preview_dir"
}

display_pager() {
  local limit
  local total
  local pages
  local page
  local key
  local rest
  local rows
  local cols
  local selected
  local start
  local end
  local position
  local target
  local redraw
  local shown_page
  limit=$1
  shift
  display_validate_limit "$limit"
  total=$#
  if ((total == 0)); then
    echo "no images found"
    return 0
  fi
  pages=$(((total + limit - 1) / limit))
  page=${DISPLAY_PAGE:-0}
  if ((page >= pages)); then page=$((pages - 1)); fi
  if ((page < 0)); then page=0; fi
  redraw=1
  shown_page=-1
  while :; do
    DISPLAY_PAGE=$page
    if [ "$redraw" -eq 1 ]; then
      if [ -t 0 ] && [ -t 1 ]; then
        if ((shown_page < 0 || shown_page != page)); then
          display_clear_history
        else
          printf '\033[2J\033[H'
        fi
      fi
      display_page "$page" "$limit" "$@"
      shown_page=$page
      if [ ! -t 0 ] || [ ! -t 1 ]; then
        return 0
      fi
    fi
    redraw=1
    rows=24
    cols=80
    read -r rows cols < <(stty size </dev/tty 2>/dev/null || printf '24 80\n')
    if ((rows < 10)); then rows=10; fi
    printf '\033[%s;1H\033[2K[%s/%s]' "$rows" "$((page + 1))" "$pages"
    key=$(display_read_key)
    printf '\033[%s;1H\033[2K' "$rows"
    case "$key" in
      $'\033[A' | $'\033[D')
        if ((page > 0)); then
          page=$((page - 1))
        fi
        ;;
      $'\033[B' | $'\033[C')
        if ((page + 1 < pages)); then
          page=$((page + 1))
        fi
        ;;
      q | Q | $'\033')
        display_clear_history
        return 0
        ;;
      '') ;;
      *[!0-9]* | ??*)
        redraw=0
        ;;
      *)
        start=$((page * limit))
        end=$((start + limit))
        if ((end > total)); then end=$total; fi
        selected=$((start + 10#$key))
        if ((selected >= start && selected < end)); then
          position=$((selected + 1))
          target=${!position}
          if [ -t 0 ] && [ -t 1 ]; then
            display_clear_history
          fi
          if display_target "$target"; then
            if [ -t 0 ] && [ -t 1 ]; then
              display_clear_history
            fi
            continue
          else
            rest=$?
          fi
          if [ -t 0 ] && [ -t 1 ]; then
            display_clear_history
          fi
          if [ "$rest" -eq 10 ]; then
            DISPLAY_PAGE=$page
            return 10
          fi
          return "$rest"
        fi
        ;;
    esac
  done
}
