object_validate_id() {
  case "${1:-}" in
    '' | *[!0-9]*)
      echo "invalid object id: ${1:-}" >&2
      return 1
      ;;
  esac
}

object_type() {
  local id
  local type
  id=$1
  object_validate_id "$id"
  type=$(db_value "SELECT type FROM objects WHERE id = $id;")
  if [ -z "$type" ]; then
    echo "object not found: $id" >&2
    return 1
  fi
  printf '%s\n' "$type"
}

object_artist() {
  local id
  id=$1
  object_type "$id" >/dev/null
  db_value "
SELECT artists.name
FROM objects
JOIN artists ON artists.id = objects.artist_id
WHERE objects.id = $id;
"
}
