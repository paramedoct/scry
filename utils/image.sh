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
  printf '%s/%s/%s\n' "$ARTS_IMAGES_DIR" "$1" "$2"
}

image_record() {
  local id
  id=$1
  image_validate_id "$id"
  db_value "
SELECT objects.id || char(9) || images.sha256 || char(9) ||
       artists.name || char(9) || images.mime_type || char(9) || images.byte_size
FROM objects
JOIN images ON images.object_id = objects.id
JOIN artists ON artists.id = objects.artist_id
WHERE objects.id = $id AND objects.type = 'image' AND images.position = 1;
"
}

image_file_record() {
  local id
  id=$1
  image_validate_id "$id"
  db_value "
SELECT images.id || char(9) || images.sha256 || char(9) ||
       artists.name || char(9) || images.mime_type || char(9) ||
       images.byte_size || char(9) || images.object_id || char(9) ||
       images.position
FROM images
JOIN objects ON objects.id = images.object_id
JOIN artists ON artists.id = objects.artist_id
WHERE images.id = $id;
"
}

image_file_require() {
  local record
  record=$(image_file_record "$1")
  if [ -z "$record" ]; then
    echo "image file not found: $1" >&2
    return 1
  fi
  printf '%s\n' "$record"
}

image_require() {
  local record
  record=$(image_record "$1")
  if [ -z "$record" ]; then
    echo "image not found: $1" >&2
    return 1
  fi
  printf '%s\n' "$record"
}

image_add() {
  local artist
  local album
  local file
  local sha
  local existing_id
  local mime
  local size
  local artist_sql
  local album_sql
  local mime_sql
  local target_dir
  local target
  local temporary
  local id
  artist=$1
  album=$2
  file=$3
  image_validate_artist "$artist"
  album_validate "$album"
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "image is not a readable file: $file" >&2
    return 1
  fi
  sha=$(image_sha256 "$file")
  existing_id=$(db_value "
SELECT object_id FROM images WHERE sha256 = $(db_quote "$sha");
")
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
  artist_sql=$(db_quote "$artist")
  album_sql=$(db_quote "$album")
  mime_sql=$(db_quote "$mime")
  target_dir=$ARTS_IMAGES_DIR/$artist
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
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
INSERT OR IGNORE INTO artists (name) VALUES ($artist_sql);
INSERT OR IGNORE INTO albums (artist_id, name)
SELECT id, $album_sql FROM artists WHERE name = $artist_sql;
INSERT INTO objects (type, artist_id, album_id)
SELECT 'image', artists.id, albums.id
FROM artists
JOIN albums ON albums.artist_id = artists.id
WHERE artists.name = $artist_sql AND albums.name = $album_sql;
INSERT INTO images (object_id, position, sha256, mime_type, byte_size)
SELECT (SELECT max(id) FROM objects), 1, $(db_quote "$sha"), $mime_sql, $size
FROM artists WHERE name = $artist_sql;
SELECT max(id) FROM objects;
COMMIT;
"); then
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
  local path
  id=$1
  record=$(image_require "$id")
  IFS=$'\t' read -r _ sha artist _ <<<"$record"
  path=$(image_path "$artist" "$sha")
  db_run "
BEGIN IMMEDIATE;
DELETE FROM images
WHERE object_id = $id;
DELETE FROM objects WHERE id = $id;
DELETE FROM albums WHERE NOT EXISTS (
  SELECT 1 FROM objects WHERE objects.album_id = albums.id
);
DELETE FROM artists WHERE NOT EXISTS (
  SELECT 1 FROM objects WHERE objects.artist_id = artists.id
);
COMMIT;
"
  rm -f -- "$path"
  rmdir "$ARTS_IMAGES_DIR/$artist" 2>/dev/null || true
}
