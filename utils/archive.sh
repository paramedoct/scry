archive_require_unzip() {
  if ! command -v unzip >/dev/null 2>&1; then
    echo "unzip command not found" >&2
    return 1
  fi
}

archive_remove_images() {
  local image_id
  for image_id in "$@"; do
    image_remove "$image_id"
  done
}

archive_add() {
  local artist
  local cat
  local topic
  local archive
  local work_dir
  local entries_file
  local entry
  local file
  local mime
  local image_id
  local sequence_id
  local count
  local status
  local -a image_ids
  local -a files
  artist=$1
  cat=$2
  topic=$3
  archive=$4
  archive_require_unzip
  work_dir=$(mktemp -d "$ARTS_STATE_DIR/.archive.XXXXXX")
  entries_file=$work_dir/entries
  image_ids=()
  files=()
  if ! unzip -Z1 "$archive" >"$entries_file"; then
    rm -rf "$work_dir"
    echo "invalid zip archive" >&2
    return 1
  fi
  count=0
  while IFS= read -r entry; do
    case "$entry" in
      '' | */) continue ;;
    esac
    count=$((count + 1))
    file=$work_dir/$count
    if ! unzip -p "$archive" "$entry" >"$file"; then
      rm -rf "$work_dir"
      echo "could not extract zip entry: $entry" >&2
      return 1
    fi
    mime=$(file -b --mime-type -- "$file")
    case "$mime" in
      image/*) ;;
      *)
        rm -rf "$work_dir"
        echo "zip entry is not an image: $entry" >&2
        return 1
        ;;
    esac
    files+=("$file")
  done <"$entries_file"
  if [ "${#files[@]}" -eq 0 ]; then
    rm -rf "$work_dir"
    echo "zip archive contains no images" >&2
    return 1
  fi
  for file in "${files[@]}"; do
    if image_id=$(image_add "$artist" "$cat" "$topic" "$file" id); then
      image_ids+=("$image_id")
      continue
    else
      status=$?
    fi
    archive_remove_images "${image_ids[@]}"
    rm -rf "$work_dir"
    if [ "$status" -eq 2 ]; then
      echo "sequence skipped: zip contains a duplicate image" >&2
      return 2
    fi
    return "$status"
  done
  sequence_id=$(db_value \
    "SELECT sequence_id FROM images WHERE id = ${image_ids[0]};")
  rm -rf "$work_dir"
  printf '%s\n' "$sequence_id"
}
