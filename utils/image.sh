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
SELECT id || char(9) || sha256 || char(9) || artist || char(9) ||
       mime_type || char(9) || byte_size
FROM (
  SELECT image_objects.object_id AS id, images.sha256, artists.name AS artist,
         images.mime_type, images.byte_size
  FROM images
  JOIN image_objects ON image_objects.image_id = images.id
  JOIN artists ON artists.id = images.artist_id
) WHERE id = $id;
"
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
  local file
  local sha
  local existing_id
  local mime
  local size
  local artist_sql
  local mime_sql
  local target_dir
  local target
  local temporary
  local id
  artist=$1
  file=$2
  image_validate_artist "$artist"
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "image is not a readable file: $file" >&2
    return 1
  fi
  sha=$(image_sha256 "$file")
  existing_id=$(db_value "
SELECT image_objects.object_id FROM images
JOIN image_objects ON image_objects.image_id = images.id
WHERE images.sha256 = $(db_quote "$sha");
")
  if [ -n "$existing_id" ]; then
    printf '%s\n' "$existing_id"
    return 0
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
INSERT INTO objects (type) VALUES ('image');
INSERT INTO images (sha256, artist_id, mime_type, byte_size)
SELECT $(db_quote "$sha"), id, $mime_sql, $size
FROM artists WHERE name = $artist_sql;
INSERT INTO image_objects (object_id, image_id)
SELECT max(id), (SELECT max(id) FROM images) FROM objects;
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
WHERE id = (SELECT image_id FROM image_objects WHERE object_id = $id);
DELETE FROM objects WHERE id = $id;
DELETE FROM artists WHERE NOT EXISTS (
  SELECT 1 FROM images WHERE images.artist_id = artists.id
);
COMMIT;
"
  rm -f -- "$path"
  rmdir "$ARTS_IMAGES_DIR/$artist" 2>/dev/null || true
}

image_set_artist() {
  local id
  local artist
  local record
  local sha
  local old_artist
  local old_path
  local new_path
  id=$1
  artist=$2
  image_validate_artist "$artist"
  record=$(image_require "$id")
  IFS=$'\t' read -r _ sha old_artist _ <<<"$record"
  if [ "$artist" = "$old_artist" ]; then
    return 0
  fi
  old_path=$(image_path "$old_artist" "$sha")
  new_path=$(image_path "$artist" "$sha")
  mkdir -p "$ARTS_IMAGES_DIR/$artist"
  mv -- "$old_path" "$new_path"
  if ! db_run "
BEGIN IMMEDIATE;
INSERT OR IGNORE INTO artists (name) VALUES ($(db_quote "$artist"));
UPDATE images
SET artist_id = (SELECT id FROM artists WHERE name = $(db_quote "$artist"))
WHERE id = (SELECT image_id FROM image_objects WHERE object_id = $id);
DELETE FROM artists WHERE NOT EXISTS (
  SELECT 1 FROM images WHERE images.artist_id = artists.id
);
COMMIT;
"; then
    mv -- "$new_path" "$old_path"
    return 1
  fi
  rmdir "$ARTS_IMAGES_DIR/$old_artist" 2>/dev/null || true
}
