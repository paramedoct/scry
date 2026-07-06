search_targets() {
  local tag
  local tag_list
  local tag_count
  if [ "$#" -eq 0 ]; then
    db_value "
SELECT target FROM (
  SELECT 'image:' || images.id AS target, images.id AS sort_id
  FROM images
  LEFT JOIN sequence_items ON sequence_items.image_id = images.id
  WHERE sequence_items.image_id IS NULL
  UNION ALL
  SELECT 'sequence:' || sequence_items.sequence_id,
         (SELECT first.image_id FROM sequence_items AS first
          WHERE first.sequence_id = sequence_items.sequence_id
          ORDER BY first.position LIMIT 1)
  FROM sequence_items
  GROUP BY sequence_items.sequence_id
) ORDER BY sort_id, target;
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
WITH matched AS (
  SELECT images.id
  FROM images
  JOIN image_tags ON image_tags.image_id = images.id
  JOIN tags ON tags.id = image_tags.tag_id
  WHERE tags.name IN ($tag_list)
  GROUP BY images.id
  HAVING count(DISTINCT tags.name) = $tag_count
), results AS (
  SELECT 'image:' || matched.id AS target, matched.id AS sort_id
  FROM matched
  LEFT JOIN sequence_items ON sequence_items.image_id = matched.id
  WHERE sequence_items.image_id IS NULL
  UNION
  SELECT 'sequence:' || sequence_items.sequence_id,
         (SELECT first.image_id FROM sequence_items AS first
          WHERE first.sequence_id = sequence_items.sequence_id
          ORDER BY first.position LIMIT 1)
  FROM matched
  JOIN sequence_items ON sequence_items.image_id = matched.id
)
SELECT target FROM results ORDER BY sort_id, target;
"
}
