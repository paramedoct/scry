environment_prepare() {
  SCRY_HOME=${SCRY_HOME:-"$HOME/.config/scry"}
  SCRY_IMAGES_DIR=$SCRY_HOME/images
  SCRY_STATE_DIR=$SCRY_HOME/state
  SCRY_DB_FILE=$SCRY_STATE_DIR/scry.db
  mkdir -p "$SCRY_IMAGES_DIR" "$SCRY_STATE_DIR"
  db_init
  SCRY_DISPLAY_FORMAT=$(db_value "
SELECT display_format FROM settings WHERE id = 1;
")
}
