CREATE TABLE IF NOT EXISTS images (
  id INTEGER PRIMARY KEY,
  subject TEXT NOT NULL CHECK(subject <> ''),
  source TEXT NOT NULL CHECK(source <> ''),
  sha256 TEXT NOT NULL UNIQUE
    CHECK(length(sha256) = 64 AND sha256 = lower(sha256)),
  mime_type TEXT NOT NULL,
  byte_size INTEGER NOT NULL CHECK(byte_size >= 0),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS settings (
  id INTEGER PRIMARY KEY CHECK(id = 1),
  display_format TEXT NOT NULL
    CHECK(display_format IN ('iterm', 'kitty', 'sixels', 'symbols'))
);

CREATE INDEX IF NOT EXISTS images_classification_idx
ON images(subject, source);

INSERT OR IGNORE INTO settings (id, display_format) VALUES (1, 'symbols');
