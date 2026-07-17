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

classification_parse_location() {
  local location
  local mode
  local artist
  local cat
  local topic
  local rest
  local depth
  location=$1
  mode=$2
  artist=${location%%:*}
  cat=
  topic=
  case "$location" in
    *:*:*:*)
      echo "invalid location: $location" >&2
      return 1
      ;;
    *:*:*)
      depth=3
      rest=${location#*:}
      cat=${rest%%:*}
      topic=${rest#*:}
      classification_validate_name topic "$topic" || return 1
      ;;
    *:*)
      depth=2
      cat=${location#*:}
      ;;
    *) depth=1 ;;
  esac
  if [ "$mode" = add ]; then
    if [ "$depth" -eq 1 ]; then
      echo "cat is required: $location" >&2
      return 1
    fi
    classification_validate_name artist "$artist" || return 1
    classification_validate_name cat "$cat" || return 1
  elif [ "$depth" -eq 1 ] || [ -n "$artist" ]; then
    classification_validate_name artist "$artist" || return 1
  fi
  if [ "$mode" = search ] &&
    { [ "$depth" -eq 2 ] || [ -n "$cat" ]; }; then
    classification_validate_name cat "$cat" || return 1
  fi
  printf '%s:%s:%s\n' "$artist" "$cat" "$topic"
}
