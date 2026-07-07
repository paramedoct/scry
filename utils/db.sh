db_quote() {
  local value
  value=$1
  value=${value//\'/\'\'}
  printf "'%s'\n" "$value"
}

db_run() {
  sqlite3 -batch -bail -cmd 'PRAGMA foreign_keys = ON;' "$ARTS_DB_FILE" "$1"
}

db_value() {
  sqlite3 -batch -bail -noheader -cmd 'PRAGMA foreign_keys = ON;' \
    "$ARTS_DB_FILE" "$1"
}

db_init() {
  local migration
  local name
  local sql
  local violations
  local invalid
  db_run "
CREATE TABLE IF NOT EXISTS schema_migrations (
  name TEXT PRIMARY KEY,
  applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
"
  for migration in "$ROOT_DIR"/schema/*.sql; do
    [ -f "$migration" ] || continue
    name=${migration##*/}
    if [ -n "$(db_value "
SELECT name FROM schema_migrations WHERE name = $(db_quote "$name");
")" ]; then
      continue
    fi
    sql=$(<"$migration")
    if [ "$name" = 006_object_images.sql ]; then
      invalid=$(db_value "
SELECT sequence_objects.object_id || char(9) || group_concat(name, ',')
FROM sequence_objects
LEFT JOIN sequence_items
  ON sequence_items.sequence_id = sequence_objects.sequence_id
LEFT JOIN images ON images.id = sequence_items.image_id
LEFT JOIN artists ON artists.id = images.artist_id
GROUP BY sequence_objects.object_id
HAVING count(DISTINCT images.artist_id) <> 1;
")
      if [ -n "$invalid" ]; then
        echo "sequence artist migration requires exactly one artist:" >&2
        echo "$invalid" >&2
        return 1
      fi
    fi
    sqlite3 -batch -bail -cmd 'PRAGMA foreign_keys = OFF;' \
      "$ARTS_DB_FILE" "
BEGIN IMMEDIATE;
$sql
INSERT INTO schema_migrations (name) VALUES ($(db_quote "$name"));
COMMIT;
"
    violations=$(db_value "PRAGMA foreign_key_check;")
    if [ -n "$violations" ]; then
      echo "foreign key check failed after migration: $name" >&2
      return 1
    fi
  done
}
