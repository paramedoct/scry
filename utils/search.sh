search_targets() {
  local location
  local artist
  local cat
  local topic
  local rest
  local where
  if [ "$#" -eq 0 ]; then
    where='1 = 1'
  else
    location=$1
    case "$location" in
      *:*:*:*)
        echo "invalid location: $location" >&2
        return 1
        ;;
      *:*:*)
        artist=${location%%:*}
        rest=${location#*:}
        cat=${rest%%:*}
        topic=${rest#*:}
        topic_validate "$topic" || return 1
        where="topics.name = $(db_quote "$topic")"
        if [ -n "$artist" ]; then
          image_validate_artist "$artist" || return 1
          where="$where AND artists.name = $(db_quote "$artist")"
        fi
        if [ -n "$cat" ]; then
          cat_validate "$cat" || return 1
          where="$where AND cats.name = $(db_quote "$cat")"
        fi
        ;;
      :*)
        cat=${location#:}
        cat_validate "$cat" || return 1
        where="cats.name = $(db_quote "$cat")"
        ;;
      *:*)
        artist=${location%%:*}
        cat=${location#*:}
        image_validate_artist "$artist" || return 1
        cat_validate "$cat" || return 1
        where="artists.name = $(db_quote "$artist")
  AND cats.name = $(db_quote "$cat")"
        ;;
      *)
        image_validate_artist "$location" || return 1
        where="artists.name = $(db_quote "$location")"
        ;;
    esac
  fi
  db_value "
SELECT objects.id
FROM objects
JOIN images ON images.object_id = objects.id
JOIN artists ON artists.id = objects.artist_id
JOIN cats ON cats.id = objects.cat_id
LEFT JOIN topics ON topics.id = objects.topic_id
WHERE $where
GROUP BY objects.id
ORDER BY min(images.id), objects.id;
"
}
