search_targets() {
  local fields
  local artist
  local cat
  local topic
  if [ "$#" -eq 0 ]; then
    artist=
    cat=
    topic=
  else
    fields=$(classification_parse_location "$1" search) || return 1
    IFS=$'\t' read -r artist cat topic <<<"$fields"
  fi
  query_search_targets "$artist" "$cat" "$topic"
}
