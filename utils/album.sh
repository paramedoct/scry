album_validate() {
  local album
  album=$1
  case "$album" in
    '' | '.' | '..' | *:* | */*)
      echo "invalid album: $album" >&2
      return 1
      ;;
  esac
}

album_parse_add_location() {
  local location
  local artist
  local album
  location=$1
  case "$location" in
    *:*:*)
      echo "invalid location: $location" >&2
      return 1
      ;;
    *:*) ;;
    *)
      echo "album is required: $location" >&2
      return 1
      ;;
  esac
  artist=${location%%:*}
  album=${location#*:}
  image_validate_artist "$artist" || return 1
  album_validate "$album" || return 1
  printf '%s\t%s\n' "$artist" "$album"
}
