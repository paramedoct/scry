search_targets() {
  local fields
  local subject
  local source
  local where
  if [ "$#" -eq 0 ]; then
    subject=
    source=
  else
    fields=$(classification_parse_location "$1" search) || return 1
    IFS=: read -r subject source <<<"$fields"
  fi
  where='1 = 1'
  if [ -n "$subject" ]; then
    where="$where AND images.subject = $(db_quote "$subject")"
  fi
  if [ -n "$source" ]; then
    where="$where AND images.source = $(db_quote "$source")"
  fi
  db_value "
SELECT images.id
FROM images
WHERE $where
ORDER BY images.id;
"
}
