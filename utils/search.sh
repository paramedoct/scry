search_targets() {
  local fields
  local artist
  local cat
  local topic
  local where
  if [ "$#" -eq 0 ]; then
    artist=
    cat=
    topic=
  else
    fields=$(classification_parse_location "$1" search) || return 1
    IFS=: read -r artist cat topic <<<"$fields"
  fi
  where='1 = 1'
  if [ -n "$artist" ]; then
    where="$where AND images.artist = $(db_quote "$artist")"
  fi
  if [ -n "$cat" ]; then
    where="$where AND images.cat = $(db_quote "$cat")"
  fi
  if [ -n "$topic" ]; then
    where="$where AND images.topic = $(db_quote "$topic")"
  fi
  db_value "
SELECT images.id
FROM images
WHERE $where
ORDER BY images.id;
"
}
