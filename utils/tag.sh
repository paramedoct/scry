tag_validate() {
  if [ -z "${1:-}" ]; then
    echo "tag must not be empty" >&2
    return 1
  fi
}

tag_add() {
  local object_id
  local tag
  object_id=$1
  tag=$2
  object_type "$object_id" >/dev/null
  tag_validate "$tag"
  db_run "
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
INSERT OR IGNORE INTO tags (name) VALUES ($(db_quote "$tag"));
INSERT OR IGNORE INTO object_tags (object_id, tag_id)
SELECT $object_id, id FROM tags WHERE name = $(db_quote "$tag");
COMMIT;
"
}

tag_remove() {
  local object_id
  local tag
  object_id=$1
  tag=$2
  object_type "$object_id" >/dev/null
  tag_validate "$tag"
  db_run "
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
DELETE FROM object_tags
WHERE object_id = $object_id
  AND tag_id = (SELECT id FROM tags WHERE name = $(db_quote "$tag"));
DELETE FROM tags WHERE NOT EXISTS (
  SELECT 1 FROM object_tags WHERE object_tags.tag_id = tags.id
);
COMMIT;
"
}

tag_list() {
  local object_id
  object_id=$1
  object_type "$object_id" >/dev/null
  db_value "
SELECT tags.name
FROM tags
JOIN object_tags ON object_tags.tag_id = tags.id
WHERE object_tags.object_id = $object_id
ORDER BY tags.name;
"
}
