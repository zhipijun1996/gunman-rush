# Meadow soil and rooted thorn bedding

Original transparent RGBA atlas generated with `image_gen.imagegen`, generation
`exec-a030d58b-e62b-40fe-859f-49c28d2600c7`. References: the **first panel** of
`docs/references/biome_style_board_1.jpg` and the existing handpainted
`assets/plains_v3/terrain/grass_limestone.png`. No image pixels were edited;
the PNG is copied byte for byte from the generated source. SHA, exact regions,
alpha bounds and proposed uniform scale are in `manifest.json`.

The upper band is umber earth with small chalk flecks, fine roots and ivy,
without a repeating stone-brick row. The lower band is low woody rhizomes,
moss and earth intended **beneath** existing dangerous thorn tips. These are
material overlays, not new platforms, colliders or hazardous regions.

Use uniform scale, cropped/repeated middle and intact endcaps. Clip soil to
the actual solid body and thorn bedding to its existing danger base or confirmed
underlying solid. Never close a protected passage with visual roots or imply
a collision wall in empty space. Middle repetition remains a visual candidate;
no seamlessness or device acceptance is claimed. Godot import alone uses
lossy quality 0.85; source PNG stays untouched.

Validation: `python3 tools/check_plains_ground_art.py`.
