archive_add() (
  local subject
  local source
  local archive
  local work_dir
  local entries_file
  local entry
  local file
  local mime
  local image_id
  local count
  local status
  local -a image_ids
  local -a files
  subject=$1
  source=$2
  archive=$3
  if ! command -v unzip >/dev/null 2>&1; then
    echo "unzip command not found" >&2
    return 1
  fi
  work_dir=$(mktemp -d "$SCRY_STATE_DIR/.archive.XXXXXX")
  trap 'rm -rf "$work_dir"' EXIT
  entries_file=$work_dir/entries
  image_ids=()
  files=()
  if ! unzip -Z1 "$archive" >"$entries_file"; then
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
      echo "could not extract zip entry: $entry" >&2
      return 1
    fi
    mime=$(file -b --mime-type -- "$file")
    case "$mime" in
      image/*) ;;
      *)
        echo "zip entry is not an image: $entry" >&2
        return 1
        ;;
    esac
    files+=("$file")
  done <"$entries_file"
  if [ "${#files[@]}" -eq 0 ]; then
    echo "zip archive contains no images" >&2
    return 1
  fi
  for file in "${files[@]}"; do
    if image_id=$(image_add "$subject" "$source" "$file"); then
      image_ids+=("$image_id")
      continue
    else
      status=$?
    fi
    for image_id in "${image_ids[@]}"; do
      image_remove "$image_id"
    done
    if [ "$status" -eq 2 ]; then
      echo "archive skipped: zip contains a duplicate image" >&2
      return 2
    fi
    return "$status"
  done
  printf '%s\n' "${image_ids[@]}"
)
