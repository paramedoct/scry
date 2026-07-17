db_quote() {
  local value
  value=$1
  value=${value//\'/\'\'}
  printf "'%s'\n" "$value"
}

db_run() {
  sqlite3 -batch -bail -cmd 'PRAGMA foreign_keys = ON;' "$SCRY_DB_FILE" "$1"
}

db_value() {
  sqlite3 -batch -bail -noheader -cmd 'PRAGMA foreign_keys = ON;' \
    "$SCRY_DB_FILE" "$1"
}

db_init() {
  local sql
  local violations
  sql=$(<"$ROOT_DIR/schema.sql")
  db_run "$sql"
  violations=$(db_value "PRAGMA foreign_key_check;")
  if [ -n "$violations" ]; then
    echo "foreign key check failed" >&2
    return 1
  fi
}
