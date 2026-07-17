sequence_remove() {
  local id
  local records
  local sha
  local artist
  id=$1
  classification_validate_id sequence "$id"
  records=$(db_value "
SELECT images.sha256 || char(9) || artists.name
FROM images
JOIN sequences ON sequences.id = images.sequence_id
JOIN artists ON artists.id = sequences.artist_id
WHERE sequences.id = $id ORDER BY images.position;
")
  if [ -z "$records" ]; then
    echo "sequence not found: $id" >&2
    return 1
  fi
  db_run "DELETE FROM sequences WHERE id = $id;"
  while IFS=$'\t' read -r sha artist; do
    [ -n "$sha" ] || continue
    image_file_delete "$artist" "$sha"
  done <<<"$records"
}
