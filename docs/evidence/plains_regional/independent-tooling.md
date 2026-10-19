# Independent tooling review — technical scope only

Reviewer `regional_review`; production and tests read-only. Runtime/source commit `e4507341cdc6b4a52c4c6175bedd4d7a0b356445`; Harness cache-input metadata fix in working tree at review. This reviewer did not author these production/tooling changes and did not run Godot. Four Python commands were independently executed with results below. Pixel/art rejection remains in independent-native-01/02 and is not superseded.

## Exact source identities

- `tools/visual_director.py`: `b4e69015d8e47f3380be6c85d1b67f073ea212cdef6a9450bf5d584554a3a7eb`
- `tools/level_design.py`: `59c65ed922630e0f16bc373a2a1da952dcb23eb08df2372207e8d61812511e70`
- `tools/harness/profiles.json`: `5101a43d1c5616e03dcfa2dd23f3612fe96afff0edf3dd73fcab99d02b3e3ac5`
- `tests/test_level_design_routing.py`: `f02dc30f184540f07d58d7f459e3497d3fbeee4cdab9f711a502202ca0122667`
- `tools/prepare_plains_regional_review.py`: `3700ab0ff3da55029e40621c0c236e94005f23f32a5a49b4adfa419dfb2810d7`
- `tools/run_plains_regional_art_tests.py`: `b9f59de5d5c8a592123facde4faa84908e58c32bf51f1559fd3e83f3606b995f`

## Existing routing-test change justification

Old `test_level_design_routing.py` expected generic “制作风铃平原美术” to select `tools/plains_places_capture.gd`. That expectation certified the wrong scope for the current user requirement. The replacement requires `tools/plains_regional_art_capture.gd`, explicit `blocked_art_RETHINK_not_mature_production`, actual regional contract and absence of the place-only contract. Existing limited/local scene request retains its place consumer; forest write prohibition remains. This changes consumer identity to match the authorized full-region scope and **does not remove physical, source, exit, gameplay or artistic acceptance assertions**. New assertions prevent passing a finite place chain as the generic regional art task. Route is still a plan, not actual automatic production.

## Capture and package review

Regional adapter is explicitly whitelisted, and actual extension source scan follows its test/tool scripts. Original source-before/after, strict engine logs, accepted-input, health/route and postdraw normal-rate movie checks remain in `visual_director`; extended36000tick ceiling and600second postprocessing are restricted to the full-region adapter. Unique temporary raw AVI storage is recorded; failures retain original backing files, successful validated MP4 finalization removes only temporary AVI. None of these establish art quality or device performance.

New regional admission compares actual Manifest denominator with grounded visits within3world units and requires all expected areas for route success. Counterexamples include missing denominator/visit, wrong/nonfinite position, airborne visit, failed case, absent terrain/Boss/chest, changed plan hash, omission and false formal-pool flag. These guard declared technical evidence, not subjective beauty. Coverage honestly excludes Boss fight and all-edge traversal.

`prepare_plains_regional_review.py` reuses the preserved strict PR82 producer, with exact replace-interface checks. Actual full-region plan, Manifest, module/enemy/chest/Boss counts, asset hashes, terrain/object/layer counts and omissions replace the former environment-specific snapshot fields. Original raw PCK SHA, resource closure, clean empty-cwd headless/GUI checks, audio/teardown, expected source commit and capture bindings remain. **At this review the new producer has not yet actually executed; packaging success is unverified.**

## Found issue and resolution

P2 cache dependency closure: cacheable `plains-regional-art-contract` initially listed selected tool helpers but omitted imported `run_root_bell_ecology.py` and its helper closure, allowing stale reuse if those changed. Reported to root before final validation; actual profile now includes whole `tools` directory alongside native/runtime/test dependencies. This is metadata-only and leaves runtime capture inputs unchanged. No production/assertion edits by reviewer.

## Independently executed checks

- `python3 -m unittest discover -s tests -p test_level_design_routing.py`:20tests,0.675s,OK. Log `build/plains_regional/review_routing.log`.
- `python3 -m unittest discover -s tests -p test_visual_director.py`:24tests,7.204s,OK. Log `build/plains_regional/review_visual.log`.
- `python3 tests/plains_regional_art_capture_test.py`:2tests,0.002s,OK. Log `build/plains_regional/review_capture_counterexamples.log`.
- `python3 tests/plains_regional_art_graph_test.py`:3tests,0.001s,OK. Log `build/plains_regional/review_graph_counterexamples.log`. Exact graph-isomorphism checker ignores identifiers, coordinates, phases and edge labels before claiming a topological difference; actual native corpus result remains separate from these synthetic tests.

No complete native route, Harness/full CI, Linux package, full movie playback, actual audio listening, manual gameplay, user or device validation independently executed here. **ACCEPT_SCOPED tooling changes and corrected old-test expectation only**, subject to actual captured evidence/package results. Regional artistic target remains **REJECTED**, expansion blocked; successful routing/checking does not mean autonomous commercial-quality production is established.
