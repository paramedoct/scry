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
  sqlite3 -batch -bail -noheader -separator $'\t' \
    -cmd 'PRAGMA foreign_keys = ON;' "$SCRY_DB_FILE" "$1"
}

db_init() {
  local sql
  local violations
  sql=$(<"$ROOT_DIR/schema/schema.sql")
  db_run "$sql"
  violations=$(db_value "PRAGMA foreign_key_check;")
  if [ -n "$violations" ]; then
    echo "foreign key check failed" >&2
    return 1
  fi
}

state_prepare() {
  SCRY_HOME=${SCRY_HOME:-"$HOME/.config/scry"}
  SCRY_IMAGES_DIR=$SCRY_HOME/images
  SCRY_STATE_DIR=$SCRY_HOME/state
  SCRY_DB_FILE=$SCRY_STATE_DIR/scry.db
  mkdir -p "$SCRY_IMAGES_DIR" "$SCRY_STATE_DIR"
  db_init
  # shellcheck disable=SC2034
  SCRY_DISPLAY_FORMAT=$(db_value \
    "SELECT display_format FROM settings WHERE id = 1;")
}
