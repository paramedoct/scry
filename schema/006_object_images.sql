CREATE TABLE objects_new (
  id INTEGER PRIMARY KEY,
  type TEXT NOT NULL CHECK(type IN ('image', 'sequence')),
  artist_id INTEGER NOT NULL REFERENCES artists(id)
);

INSERT INTO objects_new (id, type, artist_id)
SELECT image_objects.object_id, 'image', images.artist_id
FROM images
JOIN image_objects ON image_objects.image_id = images.id
LEFT JOIN sequence_items ON sequence_items.image_id = images.id
WHERE sequence_items.image_id IS NULL;

INSERT INTO objects_new (id, type, artist_id)
SELECT sequence_objects.object_id, 'sequence', min(images.artist_id)
FROM sequence_objects
JOIN sequence_items
  ON sequence_items.sequence_id = sequence_objects.sequence_id
JOIN images ON images.id = sequence_items.image_id
GROUP BY sequence_objects.object_id;

CREATE TABLE images_new (
  id INTEGER PRIMARY KEY,
  object_id INTEGER NOT NULL REFERENCES objects_new(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK(position > 0),
  sha256 TEXT NOT NULL UNIQUE
    CHECK(length(sha256) = 64 AND sha256 = lower(sha256)),
  mime_type TEXT NOT NULL,
  byte_size INTEGER NOT NULL CHECK(byte_size >= 0),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  UNIQUE(object_id, position)
);

INSERT INTO images_new (
  id, object_id, position, sha256, mime_type, byte_size, created_at
)
SELECT images.id,
       COALESCE(sequence_objects.object_id, image_objects.object_id),
       COALESCE(sequence_items.position, 1),
       images.sha256, images.mime_type, images.byte_size, images.created_at
FROM images
JOIN image_objects ON image_objects.image_id = images.id
LEFT JOIN sequence_items ON sequence_items.image_id = images.id
LEFT JOIN sequence_objects
  ON sequence_objects.sequence_id = sequence_items.sequence_id;

CREATE TABLE object_tags_new (
  object_id INTEGER NOT NULL REFERENCES objects_new(id) ON DELETE CASCADE,
  tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (object_id, tag_id)
);

INSERT OR IGNORE INTO object_tags_new (object_id, tag_id)
SELECT COALESCE(sequence_objects.object_id, object_tags.object_id),
       object_tags.tag_id
FROM object_tags
JOIN image_objects ON image_objects.object_id = object_tags.object_id
LEFT JOIN sequence_items ON sequence_items.image_id = image_objects.image_id
LEFT JOIN sequence_objects
  ON sequence_objects.sequence_id = sequence_items.sequence_id;

INSERT OR IGNORE INTO object_tags_new (object_id, tag_id)
SELECT object_tags.object_id, object_tags.tag_id
FROM object_tags
JOIN sequence_objects ON sequence_objects.object_id = object_tags.object_id;

DROP TABLE object_tags;
DROP TABLE sequence_items;
DROP TABLE image_objects;
DROP TABLE sequence_objects;
DROP TABLE images;
DROP TABLE sequences;
DROP TABLE objects;

ALTER TABLE objects_new RENAME TO objects;
ALTER TABLE images_new RENAME TO images;
ALTER TABLE object_tags_new RENAME TO object_tags;

CREATE INDEX objects_artist_id_idx ON objects(artist_id);
CREATE INDEX images_object_id_idx ON images(object_id);
