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
  local count
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
    count=$((grid_cols * grid_rows))
    required=$((4 + count + grid_rows * 8))
    if ((required > rows)); then break; fi
    limit=$count
    grid_rows=$((grid_rows + 1))
  done
  printf '%s %s\n' "$limit" "$grid_cols"
}

display_read_key() {
  local key
  local rest
  IFS= read -r -n 1 key </dev/tty
  if [ "$key" = $'\033' ]; then
    IFS= read -r -n 2 rest </dev/tty
    key=$key$rest
  fi
  printf '%s' "$key"
}

display_info() {
  local id
  id=$1
  db_value "
SELECT image_objects.object_id || char(9) || artists.name || char(9) || COALESCE((
         SELECT group_concat(name, ',') FROM (
           SELECT tags.name AS name
           FROM tags
           JOIN object_tags ON object_tags.tag_id = tags.id
           WHERE object_tags.object_id = image_objects.object_id
           ORDER BY tags.name
         )
       ), '-') || char(9) ||
       COALESCE(sequence_objects.object_id || ':' || sequence_items.position, '-')
FROM images
JOIN image_objects ON image_objects.image_id = images.id
JOIN artists ON artists.id = images.artist_id
LEFT JOIN sequence_items ON sequence_items.image_id = images.id
LEFT JOIN sequences ON sequences.id = sequence_items.sequence_id
LEFT JOIN sequence_objects ON sequence_objects.sequence_id = sequences.id
WHERE image_objects.object_id = $id;
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
  IFS=$'\t' read -r shown_id artist tags sequence <<<"$info"
  path=$(image_path "$artist" "$sha")
  if [ ! -r "$path" ]; then
    echo "stored image not found: $path" >&2
    return 1
  fi
  printf 'id: %s  type: image  artist: %s\n' "$shown_id" "$artist"
  printf 'tags: %s  sequence: %s\n' "$tags" "$sequence"
  chafa --format sixels "$path"
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
    record=$(image_require "$id")
    IFS=$'\t' read -r _ sha artist _ <<<"$record"
    info=$(display_info "$id")
    IFS=$'\t' read -r shown_id artist tags sequence <<<"$info"
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
  while :; do
    rows=24
    cols=80
    read -r rows cols < <(stty size </dev/tty 2>/dev/null || printf '24 80\n')
    if ((rows < 10)); then rows=10; fi
    if ((cols < 50)); then cols=50; fi
    list_width=$((cols / 3))
    if ((list_width < 24)); then list_width=24; fi
    if ((list_width > 40)); then list_width=40; fi
    image_width=$((cols - list_width - 3))
    image_height=$((rows - 4))
    visible=$((rows - 5))
    start=$((selected - visible / 2))
    if ((start < 0)); then start=0; fi
    if ((start + visible > total)); then start=$((total - visible)); fi
    if ((start < 0)); then start=0; fi
    end=$((start + visible))
    if ((end > total)); then end=$total; fi
    printf '\033[2J\033[H'
    printf 'id: %s  type: sequence  image: %s  %s/%s  artist: %s  tags: %s\n' \
      "$sequence_id" "${ids[$selected]}" "$((selected + 1))" "$total" \
      "${artists[$selected]}" "${tag_values[$selected]}"
    printf '%-*s |\n' "$list_width" "images"
    index=$start
    while ((index < end)); do
      label=$(printf '%3s  %s  %s' "$((index + 1))" \
        "${ids[$index]}" "${artists[$index]}")
      label=${label:0:$((list_width - 1))}
      if ((index == selected)); then
        printf '\033[1;7m%-*s\033[0m |\n' "$list_width" "$label"
      else
        printf '%-*s |\n' "$list_width" "$label"
      fi
      index=$((index + 1))
    done
    printf '\033[2;%sH' "$((list_width + 3))"
    if ! chafa --format sixels --animate off \
      --size "${image_width}x${image_height}" "${paths[$selected]}"; then
      printf '\033[%s;1H\n' "$rows"
      return 1
    fi
    printf '\033[%s;1H[k] 이전  [j] 다음  [q] 종료' "$rows"
    key=$(display_read_key)
    case "$key" in
      k | K | $'\033[A')
        if ((selected > 0)); then selected=$((selected - 1)); fi
        ;;
      j | J | $'\033[B')
        if ((selected + 1 < total)); then selected=$((selected + 1)); fi
        ;;
      q | Q)
        printf '\033[2J\033[H'
        return 0
        ;;
    esac
  done
}

display_previews() {
  local grid
  local help
  local path
  grid=${DISPLAY_GRID_COLS:-auto}
  help=$(chafa --help 2>&1)
  case "$help" in
    *--grid*)
      chafa --format sixels --grid "$grid" --label on --animate off "$@"
      ;;
    *)
      for path in "$@"; do
        chafa --format sixels --size 32x16 "$path"
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
  local info
  local sha
  local artist
  local shown_id
  local tags
  local sequence
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
  printf 'page %s/%s  images %s-%s of %s\n\n' \
    "$((page + 1))" "$(((total + limit - 1) / limit))" \
    "$((start + 1))" "$end" "$total"
  index=0
  for target in "$@"; do
    if ((index >= start && index < end)); then
      type=$(object_type "$target")
      case "$type" in
        image) id=$target ;;
        sequence)
          id=$(db_value "
SELECT image_objects.object_id FROM sequence_items
JOIN image_objects ON image_objects.image_id = sequence_items.image_id
JOIN sequence_objects
  ON sequence_objects.sequence_id = sequence_items.sequence_id
WHERE sequence_objects.object_id = $target
ORDER BY position LIMIT 1;
")
          if [ -z "$id" ]; then
            rm -rf "$preview_dir"
            echo "sequence not found or empty: $target" >&2
            return 1
          fi
          ;;
      esac
      record=$(image_require "$id")
      IFS=$'\t' read -r _ sha artist _ <<<"$record"
      info=$(display_info "$id")
      IFS=$'\t' read -r shown_id artist tags sequence <<<"$info"
      path=$(image_path "$artist" "$sha")
      if [ ! -r "$path" ]; then
        rm -rf "$preview_dir"
        echo "stored image not found: $path" >&2
        return 1
      fi
      printf '[%s] id: %s  type: %s  artist: %s  sequence: %s\n' \
        "$((index + 1))" "$target" "$type" "$artist" "$sequence"
      preview=$(printf '%s/[%s]' "$preview_dir" "$((index + 1))")
      ln -s "$path" "$preview"
      paths+=("$preview")
    fi
    index=$((index + 1))
  done
  printf '\n'
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
  limit=$1
  shift
  display_validate_limit "$limit"
  total=$#
  if ((total == 0)); then
    echo "no images found"
    return 0
  fi
  pages=$(((total + limit - 1) / limit))
  page=0
  while :; do
    if [ -t 0 ] && [ -t 1 ]; then
      printf '\033[2J\033[H'
    fi
    display_page "$page" "$limit" "$@"
    if [ ! -t 0 ] || [ ! -t 1 ] || ((pages == 1)); then
      return 0
    fi
    printf '[k] previous [j] next [q] quit: '
    key=$(display_read_key)
    printf '\n'
    case "$key" in
      k | K | $'\033[A')
        if ((page > 0)); then
          page=$((page - 1))
        fi
        ;;
      j | J | $'\033[B')
        if ((page + 1 < pages)); then
          page=$((page + 1))
        fi
        ;;
      q | Q) return 0 ;;
    esac
  done
}
