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
  object_id=$1
  values=$(tag_list "$object_id")
  if [ -z "$values" ]; then
    printf 'no tags to remove\n' >/dev/tty
    return 1
  fi
  printf '%s\n' "$values" >/dev/tty
  value=$(action_read_line 'tag to remove: ')
  [ -n "$value" ] || return 1
  tag_remove "$object_id" "$value"
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
