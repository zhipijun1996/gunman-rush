#!/usr/bin/env bash
# Capture a production v29 room at native size and its real-time touch route.
set -euo pipefail
case "${1-}" in
  P01|P02|P03) room=$1 ;;
  *) echo 'Usage: record.sh P01|P02|P03 OUTPUT_DIRECTORY' >&2; exit 2 ;;
esac
out=$(realpath -m "${2:?Specify an output directory}")
here=$(cd "$(dirname "$0")" && pwd)
cd "$here/../../../.."
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$out"
inputs() {
  python3 "$here/sources.py" "$room"
}
inputs >"$scratch/$room-sources.json"
capture() {
  local title=$1
  shift
  GUNMAN_DATA_HOME="$scratch/profile-$title" bash tools/godot.sh --path production --audio-driver Dummy "$@" >"$scratch/$title.log" 2>&1 || {
    cat "$scratch/$title.log" >&2
    return 1
  }
  cat "$scratch/$title.log"
  if rg -q '^(ERROR|SCRIPT ERROR|V29_FAIL|WARNING: [0-9]+ ObjectDB instances)' "$scratch/$title.log"; then return 1; fi
}
capture overview --fixed-fps 60 --script "$here/overview.gd" -- "$room" "$scratch/$room-overview.png"
capture play --fixed-fps 30 --resolution 1280x720 --write-movie "$scratch/world.avi" --script "$here/play.gd" -- "$room"
python3 "$here/export.py" "$room" "$scratch/world.avi" "$scratch/play.log" "$scratch"
inputs >"$scratch/after.json"
if ! cmp -s "$scratch/$room-sources.json" "$scratch/after.json"; then
  echo 'The room or one of its scenery textures changed during recording.' >&2
  exit 1
fi
for suffix in overview.png play.mp4 cover.jpg sources.json; do cp "$scratch/$room-$suffix" "$out/"; done
