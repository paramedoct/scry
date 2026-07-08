display_validate_limit() {
  case "${1:-}" in
    '' | *[!0-9]* | 0)
      echo "limit must be a positive integer: ${1:-}" >&2
      return 1
      ;;
  esac
}

display_auto_layout() {
  local rows
  local cols
  local grid_cols
  local grid_rows
  local required
  local limit
  rows=24
  cols=80
  read -r rows cols < <(stty size </dev/tty 2>/dev/null || printf '24 80\n')
  case "$rows:$cols" in
    *[!0-9:]* | 0:* | *:0) rows=24; cols=80 ;;
  esac
  grid_cols=$((cols / 20))
  if ((grid_cols < 1)); then grid_cols=1; fi
  grid_rows=1
  limit=$grid_cols
  while ((grid_cols * grid_rows <= 200)); do
    required=$((4 + grid_rows * 16))
    if ((required > rows)); then break; fi
    limit=$((grid_cols * grid_rows))
    grid_rows=$((grid_rows + 1))
  done
  printf '%s %s\n' "$limit" "$grid_cols"
}

display_read_key() {
  local key
  local rest
  IFS= read -r -n 1 key </dev/tty
  if [ "$key" = $'\033' ]; then
    rest=
    if IFS= read -r -t 0.1 -n 1 rest </dev/tty && [ "$rest" = '[' ]; then
      key=$key$rest
      rest=
      if IFS= read -r -t 0.1 -n 1 rest </dev/tty; then
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
SELECT objects.id || char(9) || artists.name || char(9) || COALESCE((
         SELECT group_concat(name, ',') FROM (
           SELECT tags.name AS name
           FROM tags
           JOIN object_tags ON object_tags.tag_id = tags.id
           WHERE object_tags.object_id = objects.id
           ORDER BY tags.name
         )
       ), '-')
FROM objects
JOIN artists ON artists.id = objects.artist_id
WHERE objects.id = $id;
"
}

display_image() {
  local id
  local record
  local sha
  local artist
  local info
  local shown_id
  local tags
  local sequence
  local path
  id=$1
  record=$(image_require "$id")
  IFS=$'\t' read -r _ sha artist _ <<<"$record"
  info=$(display_info "$id")
  IFS=$'\t' read -r shown_id artist tags <<<"$info"
  path=$(image_path "$artist" "$sha")
  if [ ! -r "$path" ]; then
    echo "stored image not found: $path" >&2
    return 1
  fi
  printf 'image %s  ·  %s  ·  tags %s\n' "$shown_id" "$artist" "$tags"
  chafa "$path"
}

display_image_browser() {
  local id
  local key
  local message
  id=$1
  message=
  while :; do
    printf '\033[2J\033[H'
    display_image "$id"
    [ -z "$message" ] || printf '%s\n' "$message"
    printf '[a] tag  [r] untag  [d] delete  [q] back: '
    key=$(display_read_key)
    printf '\n'
    message=
    case "$key" in
      a | A)
        if action_tag_add "$id"; then return 10; fi
        ;;
      r | R)
        if action_tag_remove "$id"; then return 10; fi
        ;;
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
  local rows
  local cols
  local list_width
  local image_width
  local image_height
  local visible
  local start
  local end
  local index
  local id
  local record
  local info
  local sha
  local artist
  local shown_id
  local tags
  local sequence
  local label
  local key
  local message
  local path
  local -a ids
  local -a paths
  local -a artists
  local -a tag_values
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
  tag_values=()
  for id in "${ids[@]}"; do
    record=$(image_file_require "$id")
    IFS=$'\t' read -r _ sha artist _ <<<"$record"
    info=$(display_info "$sequence_id")
    IFS=$'\t' read -r shown_id artist tags <<<"$info"
    path=$(image_path "$artist" "$sha")
    if [ ! -r "$path" ]; then
      echo "stored image not found: $path" >&2
      return 1
    fi
    paths+=("$path")
    artists+=("$artist")
    tag_values+=("$tags")
  done
  selected=0
  message=
  while :; do
    rows=24
    cols=80
    read -r rows cols < <(stty size </dev/tty 2>/dev/null || printf '24 80\n')
    if ((rows < 10)); then rows=10; fi
    if ((cols < 50)); then cols=50; fi
    list_width=$((cols / 4))
    if ((list_width < 20)); then list_width=20; fi
    if ((list_width > 32)); then list_width=32; fi
    image_width=$((cols - list_width - 3))
    image_height=$((rows - 2))
    visible=$((rows - 2))
    start=$((selected - visible / 2))
    if ((start < 0)); then start=0; fi
    if ((start + visible > total)); then start=$((total - visible)); fi
    if ((start < 0)); then start=0; fi
    end=$((start + visible))
    if ((end > total)); then end=$total; fi
    printf '\033[2J\033[H'
    printf 'sequence %s  ·  %s/%s  ·  %s  ·  tags %s\n' \
      "$sequence_id" "$((selected + 1))" "$total" \
      "${artists[$selected]}" "${tag_values[$selected]}"
    index=$start
    while ((index < end)); do
      label=$(printf '%3s  %s' "$((index + 1))" "${artists[$index]}")
      label=${label:0:$((list_width - 1))}
      if ((index == selected)); then
        printf '\033[1;7m%-*s\033[0m |\n' "$list_width" "$label"
      else
        printf '%-*s |\n' "$list_width" "$label"
      fi
      index=$((index + 1))
    done
    printf '\033[2;%sH' "$((list_width + 3))"
    if ! chafa --animate on --duration 0 \
      --size "${image_width}x${image_height}" "${paths[$selected]}"; then
      printf '\033[%s;1H\n' "$rows"
      return 1
    fi
    printf '\033[%s;1H' "$rows"
    [ -z "$message" ] || printf '%s  ' "$message"
    printf '↑/↓  [a] tag  [r] untag  [x] remove image  '
    printf '[d] delete  [q] back: '
    key=$(display_read_key)
    message=
    case "$key" in
      $'\033[A')
        if ((selected > 0)); then
          selected=$((selected - 1))
        else
          message='first image'
        fi
        ;;
      $'\033[B')
        if ((selected + 1 < total)); then
          selected=$((selected + 1))
        else
          message='last image'
        fi
        ;;
      a | A)
        if action_tag_add "$sequence_id"; then return 10; fi
        ;;
      r | R)
        if action_tag_remove "$sequence_id"; then return 10; fi
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
      chafa --grid "$grid" --label on --link off \
        --animate on --duration 0 "$@"
      ;;
    *)
      for path in "$@"; do
        chafa --size 32x16 "$path"
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
      preview=$(printf '%s/[%s]' "$preview_dir" "$((index + 1))")
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
  local selected
  local start
  local end
  local position
  local target
  local message
  local redraw
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
  message=
  redraw=1
  while :; do
    DISPLAY_PAGE=$page
    if [ "$redraw" -eq 1 ]; then
      if [ -t 0 ] && [ -t 1 ]; then
        printf '\033[2J\033[H'
      fi
      display_page "$page" "$limit" "$@"
      if [ ! -t 0 ] || [ ! -t 1 ]; then
        return 0
      fi
    fi
    redraw=1
    printf '[%s/%s] ' "$((page + 1))" "$pages"
    [ -z "$message" ] || printf '%s  ' "$message"
    key=$(display_read_key)
    if case "$key" in [0-9]) true ;; *) false ;; esac; then
      IFS= read -r rest </dev/tty
      key=$key$rest
    fi
    printf '\n'
    message=
    case "$key" in
      $'\033[D')
        if ((page > 0)); then
          page=$((page - 1))
        else
          message='first page'
        fi
        ;;
      $'\033[C')
        if ((page + 1 < pages)); then
          page=$((page + 1))
        else
          message='last page'
        fi
        ;;
      q | Q | $'\033') return 0 ;;
      '') ;;
      *[!0-9]*)
        printf '\033[1A\r\033[2K'
        redraw=0
        ;;
      *)
        selected=$((10#$key - 1))
        start=$((page * limit))
        end=$((start + limit))
        if ((end > total)); then end=$total; fi
        if ((selected >= start && selected < end)); then
          position=$((selected + 1))
          target=${!position}
          if display_target "$target"; then
            continue
          else
            rest=$?
          fi
          if [ "$rest" -eq 10 ]; then
            DISPLAY_PAGE=$page
            return 10
          fi
          return "$rest"
        else
          message="selection is not on this page: $key"
        fi
        ;;
    esac
  done
}
