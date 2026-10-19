# Runtime V2: all upper-platform routes

Actual Godot 4.7.2 test result: **17215 checks / 0 failures; 20 lower main-route round trips and 80 upper module visits with returns**. All five styles and seeds 0, 101, 307, 911 use the same geometry for a given seed. The source fingerprints are in `source_sha256.json`.

`final_runtime/runtime.log` is the native completion. `runtime_report.json` contains all 20 lower route records and 80 upper records, including every step's actual grounded position, accepted jump counts, Motor steps, and unchanged actor epoch. The upper chains start at the common spawn, walk between modules, and never reset or write player position within a chain. Initial setup restart is explicit and separate from each recorded route epoch. Physics, abilities and player tuning were unchanged.

## Necessary geometry repair

The actual held base jump rises about 150.38 world pixels. The old arch/bowl one-way step at y480 could not reach their y320 lips/roof (160 pixel rise). Layout `windchime-comparison-layout-v2` adds a two-cell one-way step at local x1/y12 to these two module kinds, which gives a 96 pixel rise followed by a 64 pixel rise. Solid terrain and the main route stay unchanged; the width avoids overlap with the arch's x3 solid post.

The final test genuinely removes the new arch step in an isolated runtime negative fixture, walks from spawn and lands on the original lower one-way, then fails to reach the roof with the same base Motor. The native log retains `EXPECTED_UPPER_REFUSAL`. The subsequent sample reset restores the production geometry. This refusal is an expected counterexample, not a skipped route or a hidden engine error.

| Module | Actual upper traversal and return |
| --- | --- |
| Meadow | First one-way y480 → solid overlook y384 → first one-way → drop to main ground |
| Arch | First one-way y480 → new step y384 → roof y320 → walk full roof → roof return → new step → drop to first one-way → main ground |
| Bowl | First one-way y480 → new step y384 → left lip y320 → inner floor y384 → right lip y320 → inner floor → left lip → new step → lower one-way → main ground |
| Wind terrace | Existing lower terrace y576 → one-way y448 → high island y352 → one-way → main ground |

Every one of these paths is exercised for all five styles and all four seeds (80 completed module visits). `upper_first_pass/` retains the preceding successful 80-module pass before the camera-scope assertions and old-geometry refusal were added.

## Camera screenshots are separate evidence

`camera_only/native.log` and its JSON receipt record an actual GPU capture with camera x1800 while the real avatar stays at x80. The receipt says `kind=camera_only_art_capture` and `traversal_claim=false`; it also records the actual player position, Motor step count and actor epoch. The corresponding PNG is at `build/style_exploration/runtime_v2_camera/camera_only_1800.png`. An off-screen avatar in an art frame therefore cannot establish that the player reached that camera location. All future capture invocations now write the same explicit receipt next to the PNG.

## Reproduce

```sh
python3 tools/run_style_exploration_tests.py
DISPLAY=:99 bash tools/godot.sh --audio-driver Dummy --path . res://scenes/style_exploration/style_lab.tscn -- --style=underworld --sample=0 --camera-x=1800 --capture=/absolute/camera_only.png
```

This is technical movement/composition evidence, not a user aesthetics, audio, player feel or physical-device approval. Previous V1 evidence and failures remain preserved separately.
