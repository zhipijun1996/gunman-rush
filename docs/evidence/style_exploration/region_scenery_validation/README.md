# Three-region environment studies: scenery evidence

This is a visual region study in the isolated StyleLab. It does not open the formal thorn forest or gear city, grant abilities, change random-map geometry, or claim production content for all 16 regions.

## Scope and actual observations

Underworld and Cavern each have plains / forest / gear presentations on identical solid cells, one-way bridge geometry, player Motor and camera behavior. Terrain still uses each style's original tile family with a separately recorded source-luminance material ramp. This is not a claim of three newly painted regional TileSets.

All 10 new source PNGs (five prop sheets and five panoramas) were visually inspected. All 12 Godot GPU captures here were also inspected: six style/biome combinations at actual camera centers x640 and x1800. These are camera-only art captures; the x1800 pictures intentionally do not relocate the player or claim a traversal. Core traversal and pure-presentation state checks are separate evidence.

The three region identities differ beyond hue: the plains show open sky, low hills, windmills and a broad daylight vista; the forest encloses the view with trunks, hanging growth, canopy light and broad exposed roots; the gear city uses hard gantries, boilers, pipes, distant catwalks and smoke silhouettes. Cavern plains now use warm gray / moss / wheat colors; original purple Cavern assets remain preserved separately.

Main landmarks use real solid support only. Metadata support widths (measured from opaque root/foot bands) fit the three existing support spans for every tested seed. No additional collision or invisible support was introduced. Forest and gear ground decorations consume only their own prop sheets. Industrial gantries remain rigid; tree sway pivots about the supported root.

Warm additive soft glows follow explicit local anchors in actual source bells, lamps or boiler fire windows. The visible budget is two sources per viewport. Turning off Light hides the whole lighting layer; turning off Decor suppresses source-bound glows as well. General floating motes are separate atmospheric decoration and are not presented as source illumination.

## Limits and artistic judgment

These captures show clear region identity and no exposed panorama edges at the sampled positions. The 120-camera technical check also covers actual left/center/right Camera2D limits. Technical passing does not establish commercial art quality, user preference, mobile performance, or the remaining 13 region identities.

The new Underworld forest foreground contains more fine texture than its sparse original pack. Its very dark tile mass and lower-detail silhouettes still differ from Cavern, but some prop detail converges. This remains an artistic comparison point rather than a signed claim that AI preserved every original style constraint.

## Reproduce

```sh
/workspace/toolchains/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path /workspace/clock-style-lab --script res://docs/evidence/style_exploration/region_scenery_validation/check.gd
DISPLAY=:99 /workspace/toolchains/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/clock-style-lab --audio-driver Dummy --rendering-method gl_compatibility res://scenes/style_exploration/style_lab.tscn -- --style=cavern --biome=forest --camera-x=640 --capture=build/region_forest_recheck.png
```

`run.log` completed with exit 0 and `REGION_SCENERY_VALIDATION_OK styles=2 biomes=3 seeds=4 combinations=24 camera_samples=120 rooted_light_max=2 foreign_decor_sources=0`. Each archived PNG has a capture receipt and log reporting `error=0`; all 12 processes completed with exit 0. The live engine was Godot 4.7.2, GL Compatibility on Mesa llvmpipe via Xvfb :99. This is not physical-device evidence.

Per-region manual light anchors are reproducible via each source folder's `anchor_adjustments.json`, consumed by `tools/prepare_style_region_assets.py`. No image pixels or source bytes were changed to establish these anchors.
