search_targets() {
  local tag
  local tag_list
  local tag_count
  if [ "$#" -eq 0 ]; then
    db_value "
SELECT target FROM (
  SELECT image_objects.object_id AS target, image_objects.object_id AS sort_id
  FROM images
  JOIN image_objects ON image_objects.image_id = images.id
  LEFT JOIN sequence_items ON sequence_items.image_id = images.id
  WHERE sequence_items.image_id IS NULL
  UNION ALL
  SELECT sequence_objects.object_id,
         (SELECT first_objects.object_id FROM sequence_items AS first
          JOIN image_objects AS first_objects
            ON first_objects.image_id = first.image_id
          WHERE first.sequence_id = sequence_items.sequence_id
          ORDER BY first.position LIMIT 1)
  FROM sequence_items
  JOIN sequence_objects
    ON sequence_objects.sequence_id = sequence_items.sequence_id
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
  SELECT objects.id, objects.type
  FROM objects
  JOIN object_tags ON object_tags.object_id = objects.id
  JOIN tags ON tags.id = object_tags.tag_id
  WHERE tags.name IN ($tag_list)
  GROUP BY objects.id
  HAVING count(DISTINCT tags.name) = $tag_count
), results AS (
  SELECT matched.id AS target, matched.id AS sort_id
  FROM matched
  LEFT JOIN image_objects ON image_objects.object_id = matched.id
  LEFT JOIN sequence_items ON sequence_items.image_id = image_objects.image_id
  WHERE matched.type = 'image' AND sequence_items.image_id IS NULL
  UNION
  SELECT sequence_objects.object_id,
         (SELECT first_objects.object_id FROM sequence_items AS first
          JOIN image_objects AS first_objects
            ON first_objects.image_id = first.image_id
          WHERE first.sequence_id = sequence_items.sequence_id
          ORDER BY first.position LIMIT 1)
  FROM matched
  JOIN image_objects ON image_objects.object_id = matched.id
  JOIN sequence_items ON sequence_items.image_id = image_objects.image_id
  JOIN sequence_objects
    ON sequence_objects.sequence_id = sequence_items.sequence_id
  WHERE matched.type = 'image'
  UNION
  SELECT matched.id, matched.id
  FROM matched
  WHERE matched.type = 'sequence'
)
SELECT target FROM results ORDER BY sort_id, target;
"
}
