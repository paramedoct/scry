sequence_validate_id() {
  case "${1:-}" in
    '' | *[!0-9]*)
      echo "invalid sequence id: ${1:-}" >&2
      return 1
      ;;
  esac
}

sequence_add() {
  local statements
  local position
  local image_id
  [ "$#" -ge 1 ] || {
    echo "sequence requires at least one image" >&2
    return 1
  }
  statements="
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
INSERT INTO sequences DEFAULT VALUES;"
  statements="$statements
INSERT INTO objects (type) VALUES ('sequence');
INSERT INTO sequence_objects (object_id, sequence_id)
SELECT max(objects.id), max(sequences.id) FROM objects, sequences;"
  position=1
  for image_id in "$@"; do
    image_require "$image_id" >/dev/null
    statements="$statements
INSERT INTO sequence_items (sequence_id, image_id, position)
SELECT sequence_objects.sequence_id, image_objects.image_id, $position
FROM sequence_objects, image_objects
WHERE sequence_objects.object_id = (SELECT max(id) FROM objects)
  AND image_objects.object_id = $image_id;"
    position=$((position + 1))
  done
  statements="$statements
SELECT max(id) FROM objects;
COMMIT;"
  db_value "$statements"
}

sequence_remove() {
  local id
  id=$1
  sequence_require "$id" >/dev/null
  db_run "
BEGIN IMMEDIATE;
DELETE FROM sequences
WHERE id = (SELECT sequence_id FROM sequence_objects WHERE object_id = $id);
DELETE FROM objects WHERE id = $id;
COMMIT;
"
}

sequence_list() {
  db_value "
SELECT sequence_objects.object_id || char(9) || count(sequence_items.image_id)
FROM sequences
JOIN sequence_objects ON sequence_objects.sequence_id = sequences.id
LEFT JOIN sequence_items ON sequence_items.sequence_id = sequences.id
GROUP BY sequences.id
ORDER BY sequence_objects.object_id;
"
}

sequence_require() {
  local id
  id=$1
  sequence_validate_id "$id"
  if [ "$(object_type "$id")" != sequence ]; then
    echo "sequence not found: $id" >&2
    return 1
  fi
  printf '%s\n' "$id"
}

sequence_image_ids() {
  local id
  id=$1
  sequence_require "$id" >/dev/null
  db_value "
SELECT image_objects.object_id
FROM sequence_items
JOIN image_objects ON image_objects.image_id = sequence_items.image_id
JOIN sequence_objects
  ON sequence_objects.sequence_id = sequence_items.sequence_id
WHERE sequence_objects.object_id = $id
ORDER BY sequence_items.position;
"
}
