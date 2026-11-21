#!/usr/bin/env bash
# Preserve the reusable terrain sources without packaging a level or importing a branch.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ref=6af82000eae0c1b8a8fb1f9a36c5ee03b3a7dcd8
output="${1:-$root/build/archives/tileset-6af82000.zip}"
if ! git -C "$root" cat-file -e "$ref^{commit}" 2>/dev/null; then
    echo "Missing source revision. Run: git fetch origin $ref" >&2
    exit 1
fi
kit=art/world-art-v2
paths=(
    "$kit/godot/terrain47" "$kit/assets/terrain47" "$kit/autotile"
    "$kit/build-autotiles.py" "$kit/requirements-bake.txt"
    "$kit/assets/pixel/manifest.json" "$kit/assets/pixel/*_terrain.png"
    "$kit/assets/pixel/fine32-terrain.png"
    "$kit/references/underworld-origin" "$kit/asset-provenance.json"
    "$kit/v2-corner-prompts.json" "$kit/v2-source-generation-record.json"
    assets/style_exploration/underworld/source/licenses assets/authored_terrain_study
    assets/region_thresholds assets/underworld_plains/terrain/fine_32
    assets/underworld_plains/hazards assets/underworld_plains/mechanisms
    'assets/plains_v07/native/mill_masonry*' 'assets/plains_v07/native/grass_masonry_transitions*'
    'assets/plains_v07/source/grass-masonry-transitions*' assets/plains_v07/manifest.json
    art/world-elements assets/world_elements config/terrain_materials.json config/surface_styles.json
    game/presentation/world/terrain 'game/presentation/world/art_foundation/blob47*'
    'game/presentation/world/underworld_plains/underworld_terrain.gd*'
    'game/presentation/world/underworld_plains/underworld_polygon_terrain.gd*'
    'game/presentation/world/plains_v07/world_module_terrain.gd*'
    'game/presentation/world/plains_v07/world_spike_art.gd*' 'shaders/formal_fine*'
    tools/art/bake_region_thresholds.py 'tools/art/bake_world_elements.gd*'
    tools/run_terrain_material_tests.py 'tests/world/terrain_materials*.gd*'
    docs/bible/terrain_materials.md .agents/skills/godot-room-art/references/autotile-47.md
)
mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
temporary="$(mktemp "$output.XXXXXX")"
trap 'rm -f "$temporary"' EXIT
git -C "$root" archive --format=zip --output="$temporary" "$ref" -- "${paths[@]}"
mv -- "$temporary" "$output"
