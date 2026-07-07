sequence_validate_id() {
  case "${1:-}" in
    '' | *[!0-9]*)
      echo "invalid sequence id: ${1:-}" >&2
      return 1
      ;;
  esac
}

sequence_add() {
  local statements
  local position
  local image_id
  local artist_id
  local current_artist_id
  [ "$#" -ge 1 ] || {
    echo "sequence requires at least one image" >&2
    return 1
  }
  artist_id=$(db_value "SELECT artist_id FROM objects WHERE id = $1;")
  [ -n "$artist_id" ] || {
    echo "image not found: $1" >&2
    return 1
  }
  statements="
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
INSERT INTO objects (type, artist_id) VALUES ('sequence', $artist_id);"
  position=1
  for image_id in "$@"; do
    image_require "$image_id" >/dev/null
    current_artist_id=$(db_value \
      "SELECT artist_id FROM objects WHERE id = $image_id;")
    if [ "$current_artist_id" != "$artist_id" ]; then
      echo "sequence images must have the same artist" >&2
      return 1
    fi
    statements="$statements
UPDATE images SET object_id = (SELECT max(id) FROM objects), position = $position
WHERE object_id = $image_id;
DELETE FROM objects WHERE id = $image_id;"
    position=$((position + 1))
  done
  statements="$statements
SELECT max(id) FROM objects;
COMMIT;"
  db_value "$statements"
}

sequence_remove() {
  local id
  local records
  local sha
  local artist
  local path
  id=$1
  sequence_require "$id" >/dev/null
  records=$(db_value "
SELECT images.sha256 || char(9) || artists.name
FROM images
JOIN objects ON objects.id = images.object_id
JOIN artists ON artists.id = objects.artist_id
WHERE objects.id = $id ORDER BY images.position;
")
  db_run "
BEGIN IMMEDIATE;
DELETE FROM objects WHERE id = $id;
DELETE FROM artists WHERE NOT EXISTS (
  SELECT 1 FROM objects WHERE objects.artist_id = artists.id
);
COMMIT;
"
  while IFS=$'\t' read -r sha artist; do
    [ -n "$sha" ] || continue
    path=$(image_path "$artist" "$sha")
    rm -f -- "$path"
    rmdir "$ARTS_IMAGES_DIR/$artist" 2>/dev/null || true
  done <<<"$records"
}

sequence_require() {
  local id
  id=$1
  sequence_validate_id "$id"
  if [ "$(object_type "$id")" != sequence ]; then
    echo "sequence not found: $id" >&2
    return 1
  fi
  printf '%s\n' "$id"
}

sequence_image_ids() {
  local id
  id=$1
  sequence_require "$id" >/dev/null
  db_value "
SELECT images.id FROM images
WHERE images.object_id = $id
ORDER BY images.position;
"
}
