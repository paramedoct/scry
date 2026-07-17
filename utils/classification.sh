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
  local artist
  local cat
  local topic
  local rest
  location=$1
  mode=$2
  cat=
  topic=
  rest=
  case "$location" in
    *:*:*:*)
      echo "invalid location: $location" >&2
      return 1
      ;;
    *) ;;
  esac
  artist=${location%%:*}
  if [ "$artist" != "$location" ]; then
    rest=${location#*:}
    cat=${rest%%:*}
    if [ "$cat" != "$rest" ]; then
      topic=${rest#*:}
      classification_validate_name topic "$topic" || return 1
    fi
  fi
  if [ "$mode" = add ]; then
    if [ "$artist" = "$location" ]; then
      echo "cat is required: $location" >&2
      return 1
    fi
    classification_validate_name artist "$artist" || return 1
    classification_validate_name cat "$cat" || return 1
  elif [ "$artist" = "$location" ] || [ -n "$artist" ]; then
    classification_validate_name artist "$artist" || return 1
  fi
  if [ "$mode" = search ] && [ "$artist" != "$location" ] &&
    { [ "$cat" = "$rest" ] || [ -n "$cat" ]; }; then
    classification_validate_name cat "$cat" || return 1
  fi
  printf '%s\t%s\t%s\n' "$artist" "$cat" "$topic"
}
