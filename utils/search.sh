search_targets() {
  local location
  local artist
  local album
  local where
  if [ "$#" -eq 0 ]; then
    where='1 = 1'
  else
    location=$1
    case "$location" in
      *:*:*)
        echo "invalid location: $location" >&2
        return 1
        ;;
      :*)
        album=${location#:}
        album_validate "$album" || return 1
        where="albums.name = $(db_quote "$album")"
        ;;
      *:*)
        artist=${location%%:*}
        album=${location#*:}
        image_validate_artist "$artist" || return 1
        album_validate "$album" || return 1
        where="artists.name = $(db_quote "$artist")
  AND albums.name = $(db_quote "$album")"
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
JOIN albums ON albums.id = objects.album_id
WHERE $where
GROUP BY objects.id
ORDER BY min(images.id), objects.id;
"
}
