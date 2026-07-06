search_image_ids() {
  local tag
  local tag_list
  local tag_count
  if [ "$#" -eq 0 ]; then
    db_value "SELECT id FROM images ORDER BY id;"
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
SELECT images.id
FROM images
JOIN image_tags ON image_tags.image_id = images.id
JOIN tags ON tags.id = image_tags.tag_id
WHERE tags.name IN ($tag_list)
GROUP BY images.id
HAVING count(DISTINCT tags.name) = $tag_count
ORDER BY images.id;
"
}
