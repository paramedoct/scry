action_read_line() {
  local prompt
  local value
  prompt=$1
  printf '%s' "$prompt" >/dev/tty
  IFS= read -r value </dev/tty
  printf '%s\n' "$value"
}

action_confirm() {
  local prompt
  local answer
  prompt=$1
  answer=$(action_read_line "$prompt [y/N]: ")
  case "$answer" in
    y | Y) return 0 ;;
    *) return 1 ;;
  esac
}

action_tag_add() {
  local object_id
  local value
  object_id=$1
  value=$(action_read_line 'tag to add: ')
  [ -n "$value" ] || return 1
  tag_add "$object_id" "$value"
}

action_tag_remove() {
  local object_id
  local values
  local value
  local choice
  local index
  local -a tags
  object_id=$1
  tags=()
  values=$(tag_list "$object_id")
  while IFS= read -r value; do
    [ -n "$value" ] || continue
    tags+=("$value")
  done <<<"$values"
  if [ "${#tags[@]}" -eq 0 ]; then
    printf 'no tags to remove\n' >/dev/tty
    return 1
  fi
  index=0
  while [ "$index" -lt "${#tags[@]}" ]; do
    printf '%s) %s\n' "$((index + 1))" "${tags[$index]}" >/dev/tty
    index=$((index + 1))
  done
  choice=$(action_read_line 'tag number to remove: ')
  case "$choice" in
    '' | *[!0-9]* | 0) return 1 ;;
  esac
  if [ "$choice" -gt "${#tags[@]}" ]; then
    return 1
  fi
  tag_remove "$object_id" "${tags[$((choice - 1))]}"
}

action_remove() {
  local object_id
  local type
  object_id=$1
  type=$(object_type "$object_id")
  action_confirm "remove $type $object_id" || return 1
  case "$type" in
    image) image_remove "$object_id" ;;
    sequence) sequence_remove "$object_id" ;;
  esac
}

action_sequence_image_remove() {
  local sequence_id
  local image_id
  local position
  sequence_id=$1
  image_id=$2
  position=$3
  action_confirm "remove image $position from sequence $sequence_id" || return 1
  sequence_image_remove "$sequence_id" "$image_id"
}
