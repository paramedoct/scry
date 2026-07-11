CREATE TABLE albums (
  id INTEGER PRIMARY KEY,
  artist_id INTEGER NOT NULL REFERENCES artists(id),
  name TEXT NOT NULL CHECK(name <> ''),
  UNIQUE(artist_id, name)
);

INSERT INTO albums (artist_id, name)
SELECT DISTINCT artist_id, 'unsorted' FROM objects;

CREATE TABLE objects_new (
  id INTEGER PRIMARY KEY,
  type TEXT NOT NULL CHECK(type IN ('image', 'sequence')),
  artist_id INTEGER NOT NULL REFERENCES artists(id),
  album_id INTEGER NOT NULL REFERENCES albums(id)
);

INSERT INTO objects_new (id, type, artist_id, album_id)
SELECT objects.id, objects.type, objects.artist_id, albums.id
FROM objects
JOIN albums ON albums.artist_id = objects.artist_id
WHERE albums.name = 'unsorted';

DROP TABLE objects;
ALTER TABLE objects_new RENAME TO objects;

CREATE INDEX objects_artist_id_idx ON objects(artist_id);
CREATE INDEX objects_album_id_idx ON objects(album_id);
