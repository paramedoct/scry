db_quote() {
  local value
  value=$1
  value=${value//\'/\'\'}
  printf "'%s'\n" "$value"
}

db_run() {
  sqlite3 -batch -bail -cmd 'PRAGMA foreign_keys = ON;' "$ARTS_DB_FILE" "$1"
}

db_value() {
  sqlite3 -batch -bail -noheader -cmd 'PRAGMA foreign_keys = ON;' \
    "$ARTS_DB_FILE" "$1"
}

db_init() {
  db_run "
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS images (
  id INTEGER PRIMARY KEY,
  sha256 TEXT NOT NULL UNIQUE
    CHECK(length(sha256) = 64 AND sha256 = lower(sha256)),
  artist TEXT NOT NULL CHECK(artist <> ''),
  original_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  byte_size INTEGER NOT NULL CHECK(byte_size >= 0),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE CHECK(name <> '')
);
CREATE TABLE IF NOT EXISTS image_tags (
  image_id INTEGER NOT NULL REFERENCES images(id) ON DELETE CASCADE,
  tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (image_id, tag_id)
);
CREATE TABLE IF NOT EXISTS sequences (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE CHECK(name <> '')
);
CREATE TABLE IF NOT EXISTS sequence_items (
  sequence_id INTEGER NOT NULL REFERENCES sequences(id) ON DELETE CASCADE,
  image_id INTEGER NOT NULL UNIQUE REFERENCES images(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK(position > 0),
  PRIMARY KEY (sequence_id, position)
);
"
}
