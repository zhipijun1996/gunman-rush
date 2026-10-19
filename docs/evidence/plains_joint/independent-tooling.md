# Independent implementation / consumer guard review

Reviewer `joint_review`, read-only production/code/assets/Skills; code and fixture tests authored by root/other agents. Reviewed frozen `f959e4a9591f3fec28d81ab8205b5fcf775f0db0` against baseline PR84 `f8dead080f2195c5c3b332966ec76fe4ba2181e3`. This is a technical scope review, not art approval.

## Actual production method

`_joint_measurement` derives whole-body collision and displayed-source transform from the same source polygon/anchor/scale. Surface semantic fractions produce safe stands, actual route waypoints, entry/exit and objects. Volume relations build bridge bank / foundation positions. Tree chooses among declared root candidates subject to explicit waypoint-X clearance. Scene layers take surface-relative anchors and derived design camera, then retain original global parallax model. Actual composer queries installed CollisionPolygon2D global points and displayed Sprite2D transforms and reports point errors. This is executed compiler and actual consumer logic, not only matching metadata.

Limitations remain substantive: all local terrain variants are uniform-scaled copies of existing complete sources; clear-region rectangles are recorded after placement and do not generally constrain background, alpha silhouette or every attachment. Specific root check is one-dimensional declared waypoint-X clearance, not image-based exclusion. Design camera is a target, not a new runtime camera controller. A new shape/composition family is not established by seven numerical variants.

## Failure correction and preserved guards

The first film actually lacked bridge artwork. `_source_world` now computes scalar float64 x/y before one final Vector2 conversion, avoiding an intermediate .3 f32 multiplication. This changes producer precision rather than accepting a 499.999969 span as500. Original `PlainsEnvironmentComposer` lines253–257 still reject distances outside original `world_span_range` exactly; diff against PR84 for that file is empty.

Actual capture validation now checks initial and final art omissions and, for joint plans, actual body/profile bindings, finite error/tolerance, point count, terrain bodies, bridges, attachment IDs, and layer IDs. Tests explicitly reject missing consumers, forged agreement, wrong solids, NaN, excessive error, wrong version, missing bindings/layers, and original source/input/engine/leak failures. No engine guard was removed. Diff for original real route driver `tests/plains_places_trace.gd`, PlayerMotor and tuning is empty.

Independently executed `python3 tests/test_plains_places_capture.py` at this frozen source: **6 tests passed**, 2.222s, exit0. These are deliberately synthetic validator counterexamples, not real Godot proof. Fresh source-bound native footage still required after producer fix; no engine run by this reviewer.

## Native contract / numeric variety audit

Reviewed `tests/plains_places_plan_runner.gd` and `tools/run_plains_places_tests.py` changes by other authors. Original deterministic replay, rehashed altered measurement rejection, finite attempts, original five mutation failures, invalid port/span/source/scale preflights remain. The formerly `measurement`-path mutations were moved onto the actual consumed `joint_synthesis` / source-family fields; retaining obsolete dead-field mutation would no longer test a consumer. New real contour/body drift counterexamples supplement rather than replace original source rejection. New mutation `composition-blocked` exhausts the same bound. Source/profile/focal/layer correspondence checks do not claim Motor or art approval.

The wrapper additionally compares actual within-place numeric collision polygons after removing world translation and normalizing polygon vertex cycle/direction and place/polygon order. It excludes names, phases and ordering; missing/non-numeric/non-finite data fail. This addresses the old fixed-local-place permutation loophole. Independently read actual frozen contract corpus `build/plains_places/contract/20261018T053140Z/actual.json`: 7 actual variant combinations and 7 normalized numeric shapes, one shape per combination (no apparent false extra uniqueness from translated float roundoff in this corpus). This inspection is not an independent engine execution. Root/native's175 assertions are recorded by their original runner; reviewer independently ran only the6 Python validator tests above.

## Reviewed bytes

- `scripts/generation/plains_place_plan.gd` SHA256 `f29720c5e45fe52c861590d642814882884b75685423340d09e5caf0710c2aa7`
- `scripts/art/plains_place_composer.gd` SHA256 `12fbb98becc0699ebaba22bb5078371cb723c32444f435355375147383f00a70`
- `scripts/art/plains_environment_composer.gd` SHA256 `e682dba152b93046d7a9c5c0b1cbd36cecec9f98d496c73c964fefb457fff511`
- `tools/visual_director.py` SHA256 `ca765b80d66a7ebdc0864af00554ac84e70c5864c93ca1a7ac95083289f79b1c`
- `tests/test_plains_places_capture.py` SHA256 `86c632d716abee720897d4a9ca68dcc78abb55d25676054c55084c64a06af3c6`
- `tests/plains_places_plan_runner.gd` SHA256 `4f87eabcc8fc6217ddee50da367cb5430077f48ec3f671cf4dd39357eb9dae1a`
- `tools/run_plains_places_tests.py` SHA256 `63c669bcb229bdb53c4dec3db3270ec0399daea292b7fdc16060c9f295686f23`
