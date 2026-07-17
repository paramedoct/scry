query_display_format() {
  db_value "SELECT display_format FROM settings WHERE id = 1;"
}

query_display_format_update() {
  db_run "UPDATE settings
SET display_format = $(db_quote "$1")
WHERE id = 1;"
}

query_image_record() {
  db_value "
SELECT images.id || char(9) || images.sha256 || char(9) ||
       artists.name || char(9) || images.mime_type || char(9) ||
       images.byte_size || char(9) || images.sequence_id || char(9) ||
       images.position
FROM images
JOIN sequences ON sequences.id = images.sequence_id
JOIN artists ON artists.id = sequences.artist_id
WHERE images.id = $1;
"
}

query_image_sequence_by_sha() {
  db_value "SELECT sequence_id
FROM images
WHERE sha256 = $(db_quote "$1");"
}

query_image_add() {
  local artist_sql
  local cat_sql
  local topic_sql
  local topic_id_sql
  local topic_statement
  local mime_sql
  local sha_sql
  local size
  local result_column
  artist_sql=$(db_quote "$1")
  cat_sql=$(db_quote "$2")
  topic_sql=$(db_quote "$3")
  mime_sql=$(db_quote "$4")
  size=$5
  sha_sql=$(db_quote "$6")
  result_column=$7
  topic_id_sql=NULL
  topic_statement=
  if [ -n "$3" ]; then
    topic_id_sql="(SELECT id FROM topics WHERE name = $topic_sql)"
    topic_statement="INSERT OR IGNORE INTO topics (name)
VALUES ($topic_sql);"
  fi
  db_value "
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
       $sha_sql, $mime_sql, $size
FROM sequences
JOIN artists ON artists.id = sequences.artist_id
JOIN cats ON cats.id = sequences.cat_id
LEFT JOIN images ON images.sequence_id = sequences.id
WHERE artists.name = $artist_sql AND cats.name = $cat_sql
  AND sequences.topic_id IS $topic_id_sql
GROUP BY sequences.id;
SELECT $result_column FROM images WHERE sha256 = $sha_sql;
COMMIT;
"
}

query_image_count() {
  db_value "SELECT count(*) FROM images WHERE sequence_id = $1;"
}

query_image_remove() {
  db_run "
BEGIN IMMEDIATE;
DELETE FROM images WHERE id = $1;
UPDATE images SET position = position + $2
WHERE sequence_id = $3 AND position > $4;
UPDATE images SET position = position - $2 - 1
WHERE sequence_id = $3 AND position > $2;
COMMIT;
"
}

query_sequence_images() {
  db_value "
SELECT images.sha256 || char(9) || artists.name
FROM images
JOIN sequences ON sequences.id = images.sequence_id
JOIN artists ON artists.id = sequences.artist_id
WHERE sequences.id = $1 ORDER BY images.position;
"
}

query_sequence_remove() {
  db_run "
BEGIN IMMEDIATE;
DELETE FROM sequences WHERE id = $1;
DELETE FROM topics WHERE NOT EXISTS (
  SELECT 1 FROM sequences WHERE sequences.topic_id = topics.id
);
DELETE FROM cats WHERE NOT EXISTS (
  SELECT 1 FROM sequences WHERE sequences.cat_id = cats.id
);
DELETE FROM artists WHERE NOT EXISTS (
  SELECT 1 FROM sequences WHERE sequences.artist_id = artists.id
);
COMMIT;
"
}

query_sequence_exists() {
  db_value "SELECT id FROM sequences WHERE id = $1;"
}

query_image_sequence() {
  db_value "SELECT sequence_id FROM images WHERE id = $1;"
}

query_search_targets() {
  local artist
  local cat
  local topic
  local where
  artist=$1
  cat=$2
  topic=$3
  where='1 = 1'
  if [ -n "$artist" ]; then
    where="$where AND artists.name = $(db_quote "$artist")"
  fi
  if [ -n "$cat" ]; then
    where="$where AND cats.name = $(db_quote "$cat")"
  fi
  if [ -n "$topic" ]; then
    where="$where AND topics.name = $(db_quote "$topic")"
  fi
  db_value "
SELECT sequences.id
FROM sequences
JOIN images ON images.sequence_id = sequences.id
JOIN artists ON artists.id = sequences.artist_id
JOIN cats ON cats.id = sequences.cat_id
LEFT JOIN topics ON topics.id = sequences.topic_id
WHERE $where
GROUP BY sequences.id
ORDER BY min(images.id), sequences.id;
"
}

query_sequence_info() {
  db_value "
SELECT sequences.id || char(9) || artists.name || char(9) || cats.name ||
       char(9) || COALESCE(topics.name, '-')
FROM sequences
JOIN artists ON artists.id = sequences.artist_id
JOIN cats ON cats.id = sequences.cat_id
LEFT JOIN topics ON topics.id = sequences.topic_id
WHERE sequences.id = $1;
"
}

query_sequence_image_ids() {
  db_value "SELECT images.id
FROM images
WHERE images.sequence_id = $1
ORDER BY images.position;"
}
