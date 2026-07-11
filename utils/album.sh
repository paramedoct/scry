album_validate() {
  local album
  album=$1
  case "$album" in
    '' | '.' | '..' | *:* | */*)
      echo "invalid cat: $album" >&2
      return 1
      ;;
  esac
}

character_validate() {
  local character
  character=$1
  case "$character" in
    '' | '.' | '..' | *:* | */*)
      echo "invalid topic: $character" >&2
      return 1
      ;;
  esac
}

album_parse_add_location() {
  local location
  local artist
  local album
  local character
  local rest
  location=$1
  case "$location" in
    *:*:*:*)
      echo "invalid location: $location" >&2
      return 1
      ;;
    *:*:*) ;;
    *:*) ;;
    *)
      echo "cat is required: $location" >&2
      return 1
      ;;
  esac
  artist=${location%%:*}
  rest=${location#*:}
  album=${rest%%:*}
  character=
  case "$rest" in
    *:*) character=${rest#*:} ;;
  esac
  image_validate_artist "$artist" || return 1
  album_validate "$album" || return 1
  if [ -n "$character" ]; then
    character_validate "$character" || return 1
  elif [ "$rest" != "$album" ]; then
    echo "invalid topic: $character" >&2
    return 1
  fi
  printf '%s\t%s\t%s\n' "$artist" "$album" "$character"
}
