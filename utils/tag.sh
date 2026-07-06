tag_validate() {
  if [ -z "${1:-}" ]; then
    echo "tag must not be empty" >&2
    return 1
  fi
}

tag_add() {
  local image_id
  local tag
  image_id=$1
  tag=$2
  image_require "$image_id" >/dev/null
  tag_validate "$tag"
  db_run "
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
INSERT OR IGNORE INTO tags (name) VALUES ($(db_quote "$tag"));
INSERT OR IGNORE INTO image_tags (image_id, tag_id)
SELECT $image_id, id FROM tags WHERE name = $(db_quote "$tag");
COMMIT;
"
}

tag_remove() {
  local image_id
  local tag
  image_id=$1
  tag=$2
  image_require "$image_id" >/dev/null
  tag_validate "$tag"
  db_run "
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
DELETE FROM image_tags
WHERE image_id = $image_id
  AND tag_id = (SELECT id FROM tags WHERE name = $(db_quote "$tag"));
DELETE FROM tags WHERE NOT EXISTS (
  SELECT 1 FROM image_tags WHERE image_tags.tag_id = tags.id
);
COMMIT;
"
}

tag_list() {
  local image_id
  image_id=$1
  image_require "$image_id" >/dev/null
  db_value "
SELECT tags.name
FROM tags
JOIN image_tags ON image_tags.tag_id = tags.id
WHERE image_tags.image_id = $image_id
ORDER BY tags.name;
"
}
