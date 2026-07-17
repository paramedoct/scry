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

CREATE TRIGGER IF NOT EXISTS images_remove_empty_sequence
AFTER DELETE ON images
WHEN EXISTS (SELECT 1 FROM sequences WHERE id = OLD.sequence_id)
  AND NOT EXISTS (
    SELECT 1 FROM images WHERE sequence_id = OLD.sequence_id
  )
BEGIN
  DELETE FROM sequences WHERE id = OLD.sequence_id;
END;

CREATE TRIGGER IF NOT EXISTS sequences_remove_empty_classification
AFTER DELETE ON sequences
BEGIN
  DELETE FROM topics WHERE NOT EXISTS (
    SELECT 1 FROM sequences WHERE sequences.topic_id = topics.id
  );
  DELETE FROM cats WHERE NOT EXISTS (
    SELECT 1 FROM sequences WHERE sequences.cat_id = cats.id
  );
  DELETE FROM artists WHERE NOT EXISTS (
    SELECT 1 FROM sequences WHERE sequences.artist_id = artists.id
  );
END;

INSERT OR IGNORE INTO settings (id, display_format) VALUES (1, 'symbols');
