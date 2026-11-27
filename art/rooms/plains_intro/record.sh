#!/usr/bin/env bash
# Record one 60-fps room review using the project renderer and official controller.
set -euo pipefail
case "${1-}" in
  P01|P03) room="$1" ;;
  *) echo 'Usage: record.sh P01|P03 OUTPUT_DIRECTORY' >&2; exit 2 ;;
esac
output_directory="$(realpath -m "${2:?Specify the output directory}")"
repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
capture_directory="$(mktemp -d)"
trap 'rm -rf -- "$capture_directory"' EXIT
cd "$repo_root"
bash tools/godot.sh --path production --fixed-fps 60 --write-movie "$capture_directory/game.avi" \
  --script res://tests/plains_intro_rooms.gd -- "--film-${room,,}" >"$capture_directory/game.log" 2>&1 || {
    cat "$capture_directory/game.log" >&2
    exit 1
  }
python3 art/rooms/plains_intro/cut_intro.py "$room" "$capture_directory/game.avi" "$capture_directory/game.log" "$output_directory"
