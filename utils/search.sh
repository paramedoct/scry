search_targets() {
  local tag
  local tag_list
  local tag_count
  if [ "$#" -eq 0 ]; then
    db_value "
SELECT objects.id
FROM objects
JOIN images ON images.object_id = objects.id
GROUP BY objects.id
ORDER BY min(images.id), objects.id;
"
    return 0
  fi
  tag_list=
  tag_count=0
  for tag in "$@"; do
    tag_validate "$tag"
    if [ -n "$tag_list" ]; then
      tag_list="$tag_list, "
    fi
    tag_list="$tag_list$(db_quote "$tag")"
    tag_count=$((tag_count + 1))
  done
  db_value "
SELECT objects.id
  FROM objects
  JOIN images ON images.object_id = objects.id
  JOIN object_tags ON object_tags.object_id = objects.id
  JOIN tags ON tags.id = object_tags.tag_id
  WHERE tags.name IN ($tag_list)
  GROUP BY objects.id
  HAVING count(DISTINCT tags.name) = $tag_count
  ORDER BY min(images.id), objects.id;
"
}
