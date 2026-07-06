sequence_validate_name() {
  if [ -z "${1:-}" ]; then
    echo "sequence name must not be empty" >&2
    return 1
  fi
}

sequence_set() {
  local name
  local name_sql
  local statements
  local position
  local image_id
  name=$1
  shift
  sequence_validate_name "$name"
  [ "$#" -ge 1 ] || {
    echo "sequence requires at least one image" >&2
    return 1
  }
  name_sql=$(db_quote "$name")
  statements="
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
INSERT OR IGNORE INTO sequences (name) VALUES ($name_sql);
DELETE FROM sequence_items
WHERE sequence_id = (SELECT id FROM sequences WHERE name = $name_sql);"
  position=1
  for image_id in "$@"; do
    image_require "$image_id" >/dev/null
    statements="$statements
INSERT INTO sequence_items (sequence_id, image_id, position)
SELECT id, $image_id, $position FROM sequences WHERE name = $name_sql;"
    position=$((position + 1))
  done
  statements="$statements
COMMIT;"
  db_run "$statements"
}

sequence_remove() {
  local name
  name=$1
  sequence_validate_name "$name"
  if [ -z "$(db_value "SELECT id FROM sequences WHERE name = $(db_quote "$name");")" ]; then
    echo "sequence not found: $name" >&2
    return 1
  fi
  db_run "DELETE FROM sequences WHERE name = $(db_quote "$name");"
}

sequence_list() {
  db_value "
SELECT sequences.name || char(9) || count(sequence_items.image_id)
FROM sequences
LEFT JOIN sequence_items ON sequence_items.sequence_id = sequences.id
GROUP BY sequences.id
ORDER BY sequences.name;
"
}

sequence_image_ids() {
  local name
  name=$1
  sequence_validate_name "$name"
  if [ -z "$(db_value "SELECT id FROM sequences WHERE name = $(db_quote "$name");")" ]; then
    echo "sequence not found: $name" >&2
    return 1
  fi
  db_value "
SELECT sequence_items.image_id
FROM sequence_items
JOIN sequences ON sequences.id = sequence_items.sequence_id
WHERE sequences.name = $(db_quote "$name")
ORDER BY sequence_items.position;
"
}
