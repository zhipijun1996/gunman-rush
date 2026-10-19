# Scenery camera / local light validation

Godot 4.7.2, OpenGL compatibility, DISPLAY=:99, Mesa llvmpipe. These are visual integration checks, not player traversal or device acceptance.

## Preserved failure

`basic_camera_limit_before_300.png` and `basic_camera_limit_before_2240.png` reproduce the old implementation using requested `camera.position` for parallax. Camera2D limits clamp the actual visible center. The former exposed a right vertical strip (~65 px); the latter exposed a left strip (~48 px). Both were visually inspected.

Old expressions:

```gdscript
node.position = (_camera.position - Vector2(640, 360)) * (1.0 - float(layer.factor))
var distance := absf(glow.global_position.x - _camera.position.x)
```

Both expressions now use `get_screen_center_position()` so background movement and local-light selection follow the rendered viewport.

## Reproducible checks

```sh
/workspace/toolchains/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path /workspace/clock-style-lab --script res://docs/evidence/style_exploration/scenery_validation/check.gd
DISPLAY=:99 /workspace/toolchains/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/clock-style-lab --audio-driver Dummy --rendering-method gl_compatibility --script res://docs/evidence/style_exploration/scenery_validation/follow_camera_check.gd
```

`check.gd`: five styles × four seeds × five requested camera positions (300, 640, 1280, 1920, 2240). Checks actual left/center/right camera limits, single-panorama coverage of the rendered 1280×720 viewport, three distinct parallax groups, bound glow transforms, a maximum of two visible bell glows, and light/decor switch behavior. All five players must report generated experimental art.

`follow_camera_check.gd`: instantiate actual StyleLab, relocate the player to three test endpoints (explicit fixture; not traversal), then allow 150 physics frames per case for ordinary lab camera follow to settle. Requested camera centers settle at 300 / 1280 / 2700 while rendered centers settle at 640 / 1280 / 1920. Captures `basic_follow_after_left/middle/right.png`; all three were visually inspected, with no exposed background strips. Local lights remained attached to actual source bells and never exceeded two per viewport.

`run.log` and `follow_camera_run.log` both finish with explicit success markers and process exit 0.

The archived scripts write fresh captures to `build/style_exploration/scenery_validation/`; these evidence PNGs preserve the observed run. They do not substitute a traversal test, independent aesthetic approval, or physical-device acceptance.
