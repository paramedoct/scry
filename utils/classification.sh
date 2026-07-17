classification_validate_cat() {
  local cat
  cat=$1
  case "$cat" in
    '' | '.' | '..' | *:* | */*)
      echo "invalid cat: $cat" >&2
      return 1
      ;;
  esac
}

classification_validate_topic() {
  local topic
  topic=$1
  case "$topic" in
    '' | '.' | '..' | *:* | */*)
      echo "invalid topic: $topic" >&2
      return 1
      ;;
  esac
}

classification_parse_add_location() {
  local location
  local artist
  local cat
  local topic
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
  cat=${rest%%:*}
  topic=
  case "$rest" in
    *:*) topic=${rest#*:} ;;
  esac
  image_validate_artist "$artist" || return 1
  classification_validate_cat "$cat" || return 1
  if [ -n "$topic" ]; then
    classification_validate_topic "$topic" || return 1
  elif [ "$rest" != "$cat" ]; then
    echo "invalid topic: $topic" >&2
    return 1
  fi
  printf '%s\t%s\t%s\n' "$artist" "$cat" "$topic"
}
