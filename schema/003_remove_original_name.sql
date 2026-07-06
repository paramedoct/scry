CREATE TABLE images_new (
  id INTEGER PRIMARY KEY,
  sha256 TEXT NOT NULL UNIQUE
    CHECK(length(sha256) = 64 AND sha256 = lower(sha256)),
  artist_id INTEGER NOT NULL REFERENCES artists(id),
  mime_type TEXT NOT NULL,
  byte_size INTEGER NOT NULL CHECK(byte_size >= 0),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

INSERT INTO images_new (
  id, sha256, artist_id, mime_type, byte_size, created_at
)
SELECT id, sha256, artist_id, mime_type, byte_size, created_at
FROM images;

DROP TABLE images;
ALTER TABLE images_new RENAME TO images;
CREATE INDEX images_artist_id_idx ON images(artist_id);
