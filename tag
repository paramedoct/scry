#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "$0 add|remove <image-id> <tag...>" >&2
  echo "$0 list <image-id>" >&2
  exit 1
}

# shellcheck source=/dev/null
source "$ROOT_DIR/utils/source.sh"
source_modules \
  utils/db.sh \
  utils/profile.sh \
  utils/image.sh \
  utils/tag.sh

main() {
  local action
  local image_id
  local value
  [ "$#" -ge 2 ] || usage
  action=$1
  image_id=$2
  shift 2
  profile_prepare
  case "$action" in
    add | remove)
      [ "$#" -ge 1 ] || usage
      for value in "$@"; do
        "tag_$action" "$image_id" "$value"
      done
      ;;
    list)
      [ "$#" -eq 0 ] || usage
      tag_list "$image_id"
      ;;
    *) usage ;;
  esac
}

main "$@"
