display_validate_limit() {
  case "${1:-}" in
    '' | *[!0-9]* | 0)
      echo "limit must be a positive integer: ${1:-}" >&2
      return 1
      ;;
  esac
}

display_info() {
  local id
  id=$1
  db_value "
SELECT images.id || char(9) || artists.name || char(9) || COALESCE((
         SELECT group_concat(name, ',') FROM (
           SELECT tags.name AS name
           FROM tags
           JOIN image_tags ON image_tags.tag_id = tags.id
           WHERE image_tags.image_id = images.id
           ORDER BY tags.name
         )
       ), '-') || char(9) ||
       COALESCE(sequences.id || ':' || sequence_items.position, '-')
FROM images
JOIN artists ON artists.id = images.artist_id
LEFT JOIN sequence_items ON sequence_items.image_id = images.id
LEFT JOIN sequences ON sequences.id = sequence_items.sequence_id
WHERE images.id = $id;
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
  printf 'image id: %s  artist: %s\n' "$shown_id" "$artist"
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
    printf 'sequence:%s  image:%s  %s/%s  artist: %s  tags: %s\n' \
      "$sequence_id" "${ids[$selected]}" "$((selected + 1))" "$total" \
      "${artists[$selected]}" "${tag_values[$selected]}"
    printf '%-*s |\n' "$list_width" "images"
    index=$start
    while ((index < end)); do
      label=$(printf '%3s  image:%s  %s' "$((index + 1))" \
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
    printf '\033[%s;1H[j] 이전  [k] 다음  [q] 종료' "$rows"
    IFS= read -r -n 1 key </dev/tty
    case "$key" in
      j | J)
        if ((selected > 0)); then selected=$((selected - 1)); fi
        ;;
      k | K)
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
  local help
  local path
  help=$(chafa --help 2>&1)
  case "$help" in
    *--grid*)
      chafa --format sixels --grid auto --label off --animate off "$@"
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
  local id
  local record
  local info
  local sha
  local artist
  local shown_id
  local tags
  local sequence
  local path
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
  printf 'page %s/%s  images %s-%s of %s\n\n' \
    "$((page + 1))" "$(((total + limit - 1) / limit))" \
    "$((start + 1))" "$end" "$total"
  index=0
  for target in "$@"; do
    if ((index >= start && index < end)); then
      case "$target" in
        image:*) id=${target#image:} ;;
        sequence:*)
          id=$(db_value "
SELECT image_id FROM sequence_items
WHERE sequence_id = ${target#sequence:}
ORDER BY position LIMIT 1;
")
          if [ -z "$id" ]; then
            echo "sequence not found or empty: ${target#sequence:}" >&2
            return 1
          fi
          ;;
        *) id=$target; target=image:$target ;;
      esac
      record=$(image_require "$id")
      IFS=$'\t' read -r _ sha artist _ <<<"$record"
      info=$(display_info "$id")
      IFS=$'\t' read -r shown_id artist tags sequence <<<"$info"
      path=$(image_path "$artist" "$sha")
      if [ ! -r "$path" ]; then
        echo "stored image not found: $path" >&2
        return 1
      fi
      printf '[%s] %s  artist: %s  sequence: %s\n' \
        "$((index + 1))" "$target" "$artist" "$sequence"
      paths+=("$path")
    fi
    index=$((index + 1))
  done
  printf '\n'
  display_previews "${paths[@]}"
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
    printf '[n]ext [p]revious [q]uit: '
    IFS= read -r -n 1 key </dev/tty
    printf '\n'
    case "$key" in
      n | N)
        if ((page + 1 < pages)); then
          page=$((page + 1))
        fi
        ;;
      p | P)
        if ((page > 0)); then
          page=$((page - 1))
        fi
        ;;
      q | Q) return 0 ;;
    esac
  done
}
