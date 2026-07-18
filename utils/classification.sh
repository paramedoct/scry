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
  local subject
  local source
  location=$1
  mode=$2
  subject=${location%%:*}
  source=
  case "$location" in
    *:*:*)
      echo "invalid location: $location" >&2
      return 1
      ;;
    *:*)
      source=${location#*:}
      classification_validate_name source "$source" || return 1
      ;;
    *)
      if [ "$mode" = add ]; then
        echo "source is required: $location" >&2
        return 1
      fi
      ;;
  esac
  if [ "$mode" = add ] || [ "$subject" = "$location" ] ||
    [ -n "$subject" ]; then
    classification_validate_name subject "$subject" || return 1
  fi
  printf '%s:%s\n' "$subject" "$source"
}
