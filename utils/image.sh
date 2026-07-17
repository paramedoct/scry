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

image_require() {
  local record
  record=$(db_value "
SELECT id, sha256, artist, mime_type, cat, COALESCE(topic, '-'), byte_size
FROM images
WHERE images.id = $1;
")
  if [ -z "$record" ]; then
    echo "image not found: $1" >&2
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
  local target_dir
  local target
  local temporary
  local id
  artist=$1
  cat=$2
  topic=$3
  file=$4
  sha=$(image_sha256 "$file")
  existing_id=$(db_value \
    "SELECT id FROM images WHERE sha256 = $(db_quote "$sha");")
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
  if ! id=$(db_value "
INSERT INTO images (artist, cat, topic, sha256, mime_type, byte_size)
VALUES ($(db_quote "$artist"), $(db_quote "$cat"),
        NULLIF($(db_quote "$topic"), ''), $(db_quote "$sha"),
        $(db_quote "$mime"), $size);
SELECT id FROM images WHERE sha256 = $(db_quote "$sha");"); then
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
  id=$1
  record=$(image_require "$id")
  IFS=$'\t' read -r _ sha artist _ _ _ _ <<<"$record"
  db_run "DELETE FROM images WHERE id = $id;"
  image_file_delete "$artist" "$sha"
}
