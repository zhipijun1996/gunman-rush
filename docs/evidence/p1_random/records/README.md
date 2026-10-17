# Ordinary generated plains capture records

All three seeds were registered before full capture in `build/p1_random/registered_seeds.json`. These records use the ordinary `DemoApp.start_plains` entry and original `LevelFormalTrace` fast route, with P1 terrain presentation and the girl avatar. They do not use the three-shore golden fixture.

| Record | Actual native result | Scope |
|---|---|---|
| seed_01 | Strict clean exit; 2323 ticks, route target reached | `courtyard_weave`, 20 areas, 61 nodes; original fast-route scope only |
| seed_02 | Strict clean exit; 2707 ticks, route target reached | `hub_satellites`, 20 areas, 60 nodes; original fast-route scope only |
| seed_03 | Cancelled after 39.319 seconds, exit -15 | User steering requested whole-screen artistic REWORK; partial AVI is not a completed route or deliverable |

`structural_comparison.json` lists actual occupied cells, connection/module differences and collider coordinates/sizes. The two captures contain 200/193 actual colliders (146/139 static terrain); their static geometry has 125/118 unique entries and 21 shared entries. This establishes different generated structures without relying on manifest hashes alone.

The first two technical results do not grant artistic acceptance. The user identified inconsistency between P1 terrain and the whole screen; the third recording, baseline and package were stopped. No three-seed success, full-region traversal, full G2, release, listening or device acceptance is claimed.

The original three seed records each compare all 1286 captured source paths against the actual Git blob at `31912d1c10f70855c99c61fbe93628f6348e18ec`. All match byte for byte; source-before and source-after also match. Recover with:

```sh
git worktree add --detach /tmp/p1-random-replay 31912d1c10f70855c99c61fbe93628f6348e18ec
```

The exact capture argv is stored in each index and original `visual_capture.json`. Godot 4.7.2 Standard and the existing cloud toolchain are required. The original build directories remain intact. Selected extracted media are video-frame samples, not exact physics-tick screenshots. No full extracted-frame collection is duplicated here. The cancelled third AVI is retained in its original build directory with its hash in the index.

Avatar GUI diagnostics and planner failures are preserved separately by the root agent under `../diagnostics/`. Actual GUI functionality passed 25 checks with native XTest mouse dropdown selection, but its complex diagnostic helper still reported 34 script/resources at exit and remains a strict failure. Independent minimal ordinary P1 previews with Courier and girl exited cleanly; these do not waive the diagnostic failure.

## Whole-screen semantic component correction

`unity_01` is a separate source-bound capture at `c0975dbafb720156b46b8ee98a9ad52f08725bde`, not a replacement for the original seed01 record. Its 1294 source paths individually match that commit and source-before/after match. It uses the identical ordinary seed01 route, camera, capabilities, driver and original strict checks. Native 2323 ticks / 5 edges reach the target; no Godot or cleanup errors were reported.

The unmodified original comparison accepted the conditions for review. Across all 2323 physics samples, numeric player state and collision geometry match the earlier capture; 387 sampled runtime snapshots, including camera/enemy/mechanism state, match. Raw input timestamps and process-object identity fields differ and remain explicitly listed in `unity_trajectory_01.json`. This is separate from artistic acceptance. Root reviewed the actual full-screen frames and marked unity_01 REWORK: stretched bridge decoration, attached narrow-soil members still using the deep-body treatment, remaining old branches and uncovered non-ShotLatch bells. A final bounded consumer correction was authorized; the original unity_01 evidence remains unchanged.

Observed final consumers include 80 structural presentations (62 one-way, 10 floating and 8 moving), four chest presentations, two wind-note icons and seven shot-latch bells. Coin, heart and non-RootBell enemy presentation remain disclosed gaps. The generated paintover is a design reference, not an in-game screenshot. No third-seed continuation, baseline or package followed automatically.

## Final stop of this method

The user rejected continued local component patching and requested joint design of the complete environment/space. Unity01 remains final artistic REWORK. A last bounded consumer correction existed only as unvalidated working source: unity02 was never started, its checks were not run, and no package was built. Root separately preserves or rolls back that WIP reversibly; it must not inherit the c097 native result. This record set is retained as engineering evidence and failed artistic-method evidence, not as a completed environmental design.
