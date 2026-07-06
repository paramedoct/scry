CREATE TABLE objects (
  id INTEGER PRIMARY KEY,
  type TEXT NOT NULL CHECK(type IN ('image', 'sequence'))
);

CREATE TABLE image_objects (
  object_id INTEGER PRIMARY KEY REFERENCES objects(id) ON DELETE CASCADE,
  image_id INTEGER NOT NULL UNIQUE REFERENCES images(id) ON DELETE CASCADE
);

INSERT INTO objects (id, type)
SELECT id, 'image' FROM images;

INSERT INTO image_objects (object_id, image_id)
SELECT id, id FROM images;

CREATE TABLE sequence_objects (
  object_id INTEGER PRIMARY KEY REFERENCES objects(id) ON DELETE CASCADE,
  sequence_id INTEGER NOT NULL UNIQUE REFERENCES sequences(id) ON DELETE CASCADE
);

INSERT INTO objects (id, type)
SELECT COALESCE((SELECT max(id) FROM images), 0) + id, 'sequence'
FROM sequences;

INSERT INTO sequence_objects (object_id, sequence_id)
SELECT COALESCE((SELECT max(id) FROM images), 0) + id, id
FROM sequences;

CREATE TABLE object_tags (
  object_id INTEGER NOT NULL REFERENCES objects(id) ON DELETE CASCADE,
  tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (object_id, tag_id)
);

INSERT INTO object_tags (object_id, tag_id)
SELECT image_objects.object_id, image_tags.tag_id
FROM image_tags
JOIN image_objects ON image_objects.image_id = image_tags.image_id;

DROP TABLE image_tags;
