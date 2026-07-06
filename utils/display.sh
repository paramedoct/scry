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
       COALESCE(sequences.name || ':' || sequence_items.position, '-')
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
  printf 'id: %s  artist: %s\n' "$shown_id" "$artist"
  printf 'tags: %s  sequence: %s\n' "$tags" "$sequence"
  chafa "$path"
}

display_page() {
  local page
  local limit
  local total
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
  for id in "$@"; do
    if ((index >= start && index < end)); then
      record=$(image_require "$id")
      IFS=$'\t' read -r _ sha artist _ <<<"$record"
      info=$(display_info "$id")
      IFS=$'\t' read -r shown_id artist tags sequence <<<"$info"
      path=$(image_path "$artist" "$sha")
      if [ ! -r "$path" ]; then
        echo "stored image not found: $path" >&2
        return 1
      fi
      printf '[%s] id: %s  artist: %s  sequence: %s\n' \
        "$((index + 1))" "$shown_id" "$artist" "$sequence"
      paths+=("$path")
    fi
    index=$((index + 1))
  done
  printf '\n'
  chafa --grid auto --label off --animate off "${paths[@]}"
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
