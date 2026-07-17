classification_validate_name() {
  local type
  local name
  type=$1
  name=$2
  case "$name" in
    '' | '.' | '..' | *:* | */*)
      echo "invalid $type: $name" >&2
      return 1
      ;;
  esac
}

classification_validate_id() {
  local type
  local id
  type=$1
  id=$2
  case "$id" in
    '' | *[!0-9]*)
      echo "invalid $type id: $id" >&2
      return 1
      ;;
  esac
}

classification_parse_location() {
  local location
  local mode
  local parts
  local artist
  local cat
  local topic
  local rest
  location=$1
  mode=$2
  artist=
  cat=
  topic=
  case "$location" in
    *:*:*:*)
      echo "invalid location: $location" >&2
      return 1
      ;;
    *:*:*)
      parts=3
      artist=${location%%:*}
      rest=${location#*:}
      cat=${rest%%:*}
      topic=${rest#*:}
      classification_validate_name topic "$topic" || return 1
      ;;
    *:*)
      parts=2
      artist=${location%%:*}
      cat=${location#*:}
      ;;
    *)
      parts=1
      artist=$location
      ;;
  esac
  if [ "$mode" = add ]; then
    if [ "$parts" -eq 1 ]; then
      echo "cat is required: $location" >&2
      return 1
    fi
    classification_validate_name artist "$artist" || return 1
    classification_validate_name cat "$cat" || return 1
  elif [ -n "$artist" ]; then
    classification_validate_name artist "$artist" || return 1
  fi
  if [ "$mode" = search ] &&
    { [ "$parts" -eq 2 ] || [ -n "$cat" ]; }; then
    classification_validate_name cat "$cat" || return 1
  fi
  printf '%s\t%s\t%s\n' "$artist" "$cat" "$topic"
}
