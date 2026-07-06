profile_prepare() {
  ARTS_HOME=${ARTS_HOME:-"$HOME/.config/arts"}
  ARTS_IMAGES_DIR=$ARTS_HOME/images
  ARTS_STATE_DIR=$ARTS_HOME/state
  ARTS_DB_FILE=$ARTS_STATE_DIR/arts.db
  mkdir -p "$ARTS_IMAGES_DIR" "$ARTS_STATE_DIR"
  db_init
}
