#!/usr/bin/env bash
set -euo pipefail
bundle_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
review_cwd="$(mktemp -d "${TMPDIR:-/tmp}/plains-environment.XXXXXXXX")"
trap 'rm -rf -- "$review_cwd"' EXIT
cd "$review_cwd"
"$bundle_dir/bin/Godot_v4.7.2-stable_linux.x86_64" --path "$review_cwd" --main-pack "$bundle_dir/environment-review.pck" --script res://tools/plains_regional_art_preview.gd -- --seed=regional-art-02 "$@"
