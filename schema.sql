CREATE TABLE IF NOT EXISTS artists (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE CHECK(name <> '')
);

CREATE TABLE IF NOT EXISTS cats (
  id INTEGER PRIMARY KEY,
  artist_id INTEGER NOT NULL REFERENCES artists(id),
  name TEXT NOT NULL CHECK(name <> ''),
  UNIQUE(artist_id, name)
);

CREATE TABLE IF NOT EXISTS topics (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE CHECK(name <> '')
);

CREATE TABLE IF NOT EXISTS sequences (
  id INTEGER PRIMARY KEY,
  artist_id INTEGER NOT NULL REFERENCES artists(id),
  cat_id INTEGER NOT NULL REFERENCES cats(id),
  topic_id INTEGER REFERENCES topics(id)
);

CREATE TABLE IF NOT EXISTS images (
  id INTEGER PRIMARY KEY,
  sequence_id INTEGER NOT NULL REFERENCES sequences(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK(position > 0),
  sha256 TEXT NOT NULL UNIQUE
    CHECK(length(sha256) = 64 AND sha256 = lower(sha256)),
  mime_type TEXT NOT NULL,
  byte_size INTEGER NOT NULL CHECK(byte_size >= 0),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  UNIQUE(sequence_id, position)
);

CREATE TABLE IF NOT EXISTS settings (
  id INTEGER PRIMARY KEY CHECK(id = 1),
  display_format TEXT NOT NULL
    CHECK(display_format IN ('iterm', 'kitty', 'sixels', 'symbols'))
);

CREATE INDEX IF NOT EXISTS sequences_artist_id_idx ON sequences(artist_id);
CREATE INDEX IF NOT EXISTS sequences_cat_id_idx ON sequences(cat_id);
CREATE INDEX IF NOT EXISTS sequences_topic_id_idx ON sequences(topic_id);
CREATE UNIQUE INDEX IF NOT EXISTS sequences_context_idx
ON sequences(artist_id, cat_id, IFNULL(topic_id, 0));
CREATE INDEX IF NOT EXISTS images_sequence_id_idx ON images(sequence_id);

INSERT OR IGNORE INTO settings (id, display_format) VALUES (1, 'symbols');
