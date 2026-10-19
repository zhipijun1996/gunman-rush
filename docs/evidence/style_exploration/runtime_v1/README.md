# Runtime V1 evidence

Godot 4.7.2 Standard; five real TileSet/TileMapLayer consumers, 32 world units per tile. Geometry is identical across styles for the same seed. Four layouts: authored seed 0 and randomized seeds 101, 307, 911.

- `final_runtime/runtime.log`: **16429 checks, 0 failures, 20 routes**. Each route has real PlayerMotor movement, accepted base jumps and forward-and-return travel; no route position writes, no actor epoch change. Tests also check canonical cells, collision union, one-way landing/drop-through, style position/camera/session/collision preservation, and actual T/R input while paused. This final run consumes packaged `assets/style_exploration/<style>/terrain.tres` files.
- `final_runtime/runtime_report.json`: individual style/seed route measurements.
- `gpu_v1/`: actual native logs for 20 gameplay screenshots and five atlas catalogs, all successful and cleanly exited. The PNGs remain at `build/style_exploration/20261019T081913264768Z/`; final art captures are produced separately by the parent task. These are genuine 1280x720 GPU frames on DISPLAY :99 (Mesa llvmpipe), not concept images.
- `initial_full/`: first imported consumer run, 16427 checks/0 failures.
- `initial_failures/`: preserved missing baseline ridge, terrain absent/not yet imported errors.
- `pause_observation_failure/`: first actual-input regression observed only one process frame and failed T-close (other 20 routes passed). An isolated check established native input delivery occurs on the second process frame. The final test waits two frames and keeps the actual native input requirement.

Runtime source and packaged terrain fingerprints are in `runtime_source_sha256.json`. The GPU V1 baseline predates the pause-safe key relay and packaged-resource consumer; those changes preserve visible art and geometry. The later final runtime separately verifies them.

## Reproduce

```sh
python3 tools/run_style_exploration_tests.py
DISPLAY=:99 python3 tools/run_style_exploration_tests.py --skip-import --capture
```

Play `scenes/style_exploration/style_lab.tscn`, or one of the five named scene files. Keys 1–5 compare styles; Shift 0–3 selects authored/random samples; A/D + Space uses unchanged gameplay; T toggles the atlas; R restarts. GUI buttons also expose background/decor/light/grid/pause/Home. Style changes retain player and camera position; sample changes restart from the common spawn.

```sh
DISPLAY=:99 bash tools/godot.sh --audio-driver Dummy --path . res://scenes/style_exploration/style_lab.tscn -- --style=basic --sample=2 --capture=/absolute/capture.png
```

The technical evidence covers safe lower routes and semantic composition. Optional elevated routes, player aesthetics, complete audio, real devices and commercial art acceptance remain unverified. Saved `.tres` resources use only permanent `res://assets/style_exploration/…/terrain.png` texture references.
