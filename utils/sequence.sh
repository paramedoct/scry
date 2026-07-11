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
  local album_id
  local character_id
  local current_artist_id
  local current_album_id
  local current_character_id
  [ "$#" -ge 1 ] || {
    echo "sequence requires at least one image" >&2
    return 1
  }
  artist_id=$(db_value "SELECT artist_id FROM objects WHERE id = $1;")
  album_id=$(db_value "SELECT album_id FROM objects WHERE id = $1;")
  character_id=$(db_value \
    "SELECT COALESCE(character_id, '') FROM objects WHERE id = $1;")
  [ -n "$artist_id" ] || {
    echo "image not found: $1" >&2
    return 1
  }
  statements="
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
INSERT INTO objects (type, artist_id, album_id, character_id)
VALUES ('sequence', $artist_id, $album_id, ${character_id:-NULL});"
  position=1
  for image_id in "$@"; do
    image_require "$image_id" >/dev/null
    current_artist_id=$(db_value \
      "SELECT artist_id FROM objects WHERE id = $image_id;")
    current_album_id=$(db_value \
      "SELECT album_id FROM objects WHERE id = $image_id;")
    current_character_id=$(db_value \
      "SELECT COALESCE(character_id, '') FROM objects WHERE id = $image_id;")
    if [ "$current_artist_id" != "$artist_id" ]; then
      echo "sequence images must have the same artist" >&2
      return 1
    fi
    if [ "$current_album_id" != "$album_id" ]; then
      echo "sequence images must have the same cat" >&2
      return 1
    fi
    if [ "$current_character_id" != "$character_id" ]; then
      echo "sequence images must have the same topic" >&2
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
DELETE FROM characters WHERE NOT EXISTS (
  SELECT 1 FROM objects WHERE objects.character_id = characters.id
);
DELETE FROM albums WHERE NOT EXISTS (
  SELECT 1 FROM objects WHERE objects.album_id = albums.id
);
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

sequence_image_remove() {
  local sequence_id
  local image_id
  local record
  local sha
  local artist
  local object_id
  local position
  local count
  local path
  sequence_id=$1
  image_id=$2
  sequence_require "$sequence_id" >/dev/null
  record=$(image_file_require "$image_id")
  IFS=$'\t' read -r _ sha artist _ _ object_id position <<<"$record"
  if [ "$object_id" != "$sequence_id" ]; then
    echo "image is not in sequence: $image_id" >&2
    return 1
  fi
  count=$(db_value "SELECT count(*) FROM images WHERE object_id = $sequence_id;")
  if [ "$count" -eq 1 ]; then
    sequence_remove "$sequence_id"
    return 0
  fi
  db_run "
BEGIN IMMEDIATE;
DELETE FROM images WHERE id = $image_id AND object_id = $sequence_id;
UPDATE images SET position = position + $count
WHERE object_id = $sequence_id AND position > $position;
UPDATE images SET position = position - $count - 1
WHERE object_id = $sequence_id AND position > $count;
UPDATE objects SET type = 'image'
WHERE id = $sequence_id AND $count = 2;
COMMIT;
"
  path=$(image_path "$artist" "$sha")
  rm -f -- "$path"
}
