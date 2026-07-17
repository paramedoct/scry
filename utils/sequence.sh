sequence_remove() {
  local id
  local records
  local sha
  local artist
  id=$1
  sequence_require "$id" >/dev/null
  records=$(db_value "
SELECT images.sha256 || char(9) || artists.name
FROM images
JOIN sequences ON sequences.id = images.sequence_id
JOIN artists ON artists.id = sequences.artist_id
WHERE sequences.id = $id ORDER BY images.position;
")
  db_run "
BEGIN IMMEDIATE;
DELETE FROM sequences WHERE id = $id;
DELETE FROM topics WHERE NOT EXISTS (
  SELECT 1 FROM sequences WHERE sequences.topic_id = topics.id
);
DELETE FROM cats WHERE NOT EXISTS (
  SELECT 1 FROM sequences WHERE sequences.cat_id = cats.id
);
DELETE FROM artists WHERE NOT EXISTS (
  SELECT 1 FROM sequences WHERE sequences.artist_id = artists.id
);
COMMIT;
"
  while IFS=$'\t' read -r sha artist; do
    [ -n "$sha" ] || continue
    image_file_delete "$artist" "$sha"
  done <<<"$records"
}

sequence_require() {
  local id
  id=$1
  classification_validate_id sequence "$id"
  if [ -z "$(db_value "SELECT id FROM sequences WHERE id = $id;")" ]; then
    echo "sequence not found: $id" >&2
    return 1
  fi
  printf '%s\n' "$id"
}
