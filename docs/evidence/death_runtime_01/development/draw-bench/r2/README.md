# Actual Skin.draw_pose CPU/vertex-update benchmark R2 (not run by author)

R1 failed parsing because nested `Skin` collided with Godot's native Skin class. Its actual `/tmp/death-runtime-01/draw-bench/run.log` and all R1 files are preserved; `r1-preserved.json` records exact SHA/size. R2 bounded fix uses identical non-native lexical class names `DrawPose/DrawGround/DrawFlora/DrawSkin` on both sides. It also checks625 uploads outside settled cache (zero) so shared culling cannot false-pass.

`base.gd` contains original5d four-source snapshots. `candidate.gd` contains the current temp source (Skin360228b6, Groundd871a81f, Floraa408e248, Posebdcbda3e). `control.gd` is byte-identical to base but a separate resource with independent nested classes/statics. A/B and A/A runners share identical bodies except mode/right resource/output filename. Source and generated SHA are in manifest.json.

Exactly symmetric test-copy edits: remove global class registration/static_unload while wrapping lexical classes; add observed_vertices packed-array field; assign observed_vertices=vertices immediately before the unchanged `_mesh.surface_update_vertex_region`; remove only final canvas.draw_mesh call because the test invokes draw_pose outside CanvasItem._draw. Actual topology/mesh initialization, body visibility, pose preparation, weights, live-prefix/settled caches, PackedArray allocation/packing, RenderingServer vertex-region submission, and four material parameter calls remain. Canvas is a real tree child at(100,180) with actual skin ShaderMaterial; root size1280×720. No Actor/Stage consumers are installed.

Three rounds, six kinds,21 live changing-clock/stride samples. Each of three death cases primes3 actual alive samples then freezes motion and traverses death0→1 in21 samples. Cases: grounded, aerial, and air false→true→false. Landing impulse remains nonzero early. Each case adds3 settled draws. Every adjacent A/B pair reverses order; each round reverses its first side. `first_death`, `collapse_steady`, `prime_live`, `live_first`, `live_steady` and `settled_cache` rows are separate. Mesh construction and observation reset occur outside per-draw timing. Each sample preserves raw a_us/b_us, order, phase, progress/clock/air/landing, upload sizes and byte equality. Failed comparisons preserve exact byte hex. Expected1836 pairs/3672 individual draws per run. No sample is silently discarded as warmup.

Run through the existing engine wrapper, separately for AA/AB, retaining logs and the original budgets (parse20s, run120s):

```python
import sys
sys.path.insert(0, '/workspace/gunman-rush-refactor/tools')
from run_tests import run_engine
source='/tmp/gunman-first-use-web-source'
for mode in ['aa','ab']:
    script=f'/tmp/death-runtime-01/draw-bench/r2/{mode}_bench.gd'
    run_engine(['--headless','--path',source,'--check-only','--script',script],20)
    run_engine(['--headless','--path',source,'--script',script],120)
```

Success marker DEATH_DRAW_PIPELINE identifies mode,1836 pairs,zero mismatches and output path. Results go to aa-results.json/ab-results.json. No result is preclaimed; author ran only generator/static checks. A/A establishes variation between independent instances of identical code before interpreting A/B. Analyze each round/kind/case/phase with raw timings and both AB/BA orders; retain any parse/runtime/equivalence failure without loosening timeout or filtering failed samples.

Limits: this measures draw_pose CPU work and the actual vertex-region API submission, **not GPU completion**. The final Canvas draw is intentionally absent. It excludes AI, physics, audio, loot, browser and phone FPS; it cannot establish whole-frame stutter removal or visual/device acceptance. Test observation retains a vertex array symmetrically and its serialization/checking are outside timing. No production file was edited.
