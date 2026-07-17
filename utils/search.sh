search_targets() {
  local location
  local artist
  local cat
  local topic
  local rest
  artist=
  cat=
  topic=
  if [ "$#" -eq 0 ]; then
    :
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
        if [ -n "$artist" ]; then
          image_validate_artist "$artist" || return 1
        fi
        if [ -n "$cat" ]; then
          cat_validate "$cat" || return 1
        fi
        ;;
      :*)
        cat=${location#:}
        cat_validate "$cat" || return 1
        ;;
      *:*)
        artist=${location%%:*}
        cat=${location#*:}
        image_validate_artist "$artist" || return 1
        cat_validate "$cat" || return 1
        ;;
      *)
        image_validate_artist "$location" || return 1
        artist=$location
        ;;
    esac
  fi
  query_search_targets "$artist" "$cat" "$topic"
}
