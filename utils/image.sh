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
  db_value "
SELECT images.id || char(9) || images.sha256 || char(9) ||
       artists.name || char(9) || images.mime_type || char(9) ||
       images.byte_size || char(9) || images.sequence_id || char(9) ||
       images.position
FROM images
JOIN sequences ON sequences.id = images.sequence_id
JOIN artists ON artists.id = sequences.artist_id
WHERE images.id = $id;
"
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
  local artist_sql
  local cat_sql
  local topic_sql
  local topic_id_sql
  local topic_statement
  local mime_sql
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
  existing_id=$(db_value "
SELECT sequence_id FROM images WHERE sha256 = $(db_quote "$sha");
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
  cat_sql=$(db_quote "$cat")
  topic_sql=$(db_quote "$topic")
  topic_id_sql=NULL
  topic_statement=
  if [ -n "$topic" ]; then
    topic_id_sql="(SELECT id FROM topics WHERE name = $topic_sql)"
    topic_statement="INSERT OR IGNORE INTO topics (name)
VALUES ($topic_sql);"
  fi
  mime_sql=$(db_quote "$mime")
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
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
INSERT OR IGNORE INTO artists (name) VALUES ($artist_sql);
INSERT OR IGNORE INTO cats (artist_id, name)
SELECT id, $cat_sql FROM artists WHERE name = $artist_sql;
$topic_statement
INSERT OR IGNORE INTO sequences (artist_id, cat_id, topic_id)
SELECT artists.id, cats.id, $topic_id_sql
FROM artists
JOIN cats ON cats.artist_id = artists.id
WHERE artists.name = $artist_sql AND cats.name = $cat_sql;
INSERT INTO images (sequence_id, position, sha256, mime_type, byte_size)
SELECT sequences.id, COALESCE(max(images.position), 0) + 1,
       $(db_quote "$sha"), $mime_sql, $size
FROM sequences
JOIN artists ON artists.id = sequences.artist_id
JOIN cats ON cats.id = sequences.cat_id
LEFT JOIN images ON images.sequence_id = sequences.id
WHERE artists.name = $artist_sql AND cats.name = $cat_sql
  AND sequences.topic_id IS $topic_id_sql
GROUP BY sequences.id;
SELECT $result_column FROM images WHERE sha256 = $(db_quote "$sha");
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
  local sequence_id
  local position
  local count
  id=$1
  record=$(image_require "$id")
  IFS=$'\t' read -r _ sha artist _ _ sequence_id position <<<"$record"
  count=$(db_value "SELECT count(*) FROM images WHERE sequence_id = $sequence_id;")
  if [ "$count" -eq 1 ]; then
    sequence_remove "$sequence_id"
    return 0
  else
    db_run "
BEGIN IMMEDIATE;
DELETE FROM images WHERE id = $id;
UPDATE images SET position = position + $count
WHERE sequence_id = $sequence_id AND position > $position;
UPDATE images SET position = position - $count - 1
WHERE sequence_id = $sequence_id AND position > $count;
COMMIT;
"
  fi
  image_file_delete "$artist" "$sha"
}
