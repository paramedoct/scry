image_validate_artist() {
  local artist
  artist=$1
  case "$artist" in
    '' | '.' | '..' | */*)
      echo "invalid artist: $artist" >&2
      return 1
      ;;
  esac
}

image_validate_id() {
  case "${1:-}" in
    '' | *[!0-9]*)
      echo "invalid image id: ${1:-}" >&2
      return 1
      ;;
  esac
}

image_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  elif command -v sha256 >/dev/null 2>&1; then
    sha256 -q "$1"
  else
    echo "sha-256 command not found" >&2
    return 1
  fi
}

image_path() {
  printf '%s/%s/%s\n' "$SCRY_IMAGES_DIR" "$1" "$2"
}

image_file_delete() {
  local artist
  local sha
  artist=$1
  sha=$2
  rm -f -- "$(image_path "$artist" "$sha")"
  rmdir "$SCRY_IMAGES_DIR/$artist" 2>/dev/null || true
}

image_record() {
  local id
  id=$1
  image_validate_id "$id"
  query_image_record "$id"
}

image_require() {
  local record
  record=$(image_record "$1")
  if [ -z "$record" ]; then
    echo "image file not found: $1" >&2
    return 1
  fi
  printf '%s\n' "$record"
}

image_add() {
  local artist
  local cat
  local topic
  local file
  local sha
  local existing_id
  local mime
  local size
  local result_column
  local target_dir
  local target
  local temporary
  local id
  artist=$1
  cat=$2
  topic=$3
  file=$4
  result_column=${5:-sequence_id}
  case "$result_column" in
    id | sequence_id) ;;
    *)
      echo "invalid image result column: $result_column" >&2
      return 1
      ;;
  esac
  image_validate_artist "$artist"
  cat_validate "$cat"
  if [ -n "$topic" ]; then topic_validate "$topic"; fi
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "image is not a readable file: $file" >&2
    return 1
  fi
  sha=$(image_sha256 "$file")
  existing_id=$(query_image_sequence_by_sha "$sha")
  if [ -n "$existing_id" ]; then
    echo "duplicate image skipped: sha256 $sha" >&2
    return 2
  fi
  mime=$(file -b --mime-type -- "$file")
  case "$mime" in
    image/*) ;;
    *)
      echo "not an image file: $file" >&2
      return 1
      ;;
  esac
  size=$(wc -c <"$file" | tr -d '[:space:]')
  target_dir=$SCRY_IMAGES_DIR/$artist
  target=$(image_path "$artist" "$sha")
  mkdir -p "$target_dir"
  temporary=$(mktemp "$target_dir/.${sha}.XXXXXX")
  if ! cp -- "$file" "$temporary"; then
    rm -f "$temporary"
    return 1
  fi
  chmod 600 "$temporary"
  if ! mv "$temporary" "$target"; then
    rm -f "$temporary"
    return 1
  fi
  if ! id=$(query_image_add \
    "$artist" "$cat" "$topic" "$mime" "$size" "$sha" "$result_column"); then
    rm -f "$target"
    return 1
  fi
  printf '%s\n' "$id"
}

image_remove() {
  local id
  local record
  local sha
  local artist
  local sequence_id
  local position
  local count
  id=$1
  record=$(image_require "$id")
  IFS=$'\t' read -r _ sha artist _ _ sequence_id position <<<"$record"
  count=$(query_image_count "$sequence_id")
  if [ "$count" -eq 1 ]; then
    sequence_remove "$sequence_id"
    return 0
  else
    query_image_remove "$id" "$count" "$sequence_id" "$position"
  fi
  image_file_delete "$artist" "$sha"
}
