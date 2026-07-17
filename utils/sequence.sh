sequence_remove() {
  local id
  local records
  local sha
  local artist
  id=$1
  sequence_require "$id" >/dev/null
  records=$(query_sequence_images "$id")
  query_sequence_remove "$id"
  while IFS=$'\t' read -r sha artist; do
    [ -n "$sha" ] || continue
    image_file_delete "$artist" "$sha"
  done <<<"$records"
}

sequence_require() {
  local id
  id=$1
  classification_validate_id sequence "$id"
  if [ -z "$(query_sequence_exists "$id")" ]; then
    echo "sequence not found: $id" >&2
    return 1
  fi
  printf '%s\n' "$id"
}

sequence_image_remove() {
  local sequence_id
  local image_id
  local current_sequence_id
  sequence_id=$1
  image_id=$2
  sequence_require "$sequence_id" >/dev/null
  current_sequence_id=$(query_image_sequence "$image_id")
  if [ "$current_sequence_id" != "$sequence_id" ]; then
    echo "image is not in sequence: $image_id" >&2
    return 1
  fi
  image_remove "$image_id"
}
