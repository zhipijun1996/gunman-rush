# Final existing-map presentation boundary

Three-file candidate against exact 2d44aaebbda52977f6ec347379242ec01a9ee62a. Main and engine untouched. No test, registration, budget, algorithm, asset, schema, factory or player rule changes. App has zero remaining `.assembler` reads after this patch.

GeneratedDemoStage.route_debug_summary returns existing index+1, flow string and module count. Its reads retain index→mirrored flow→count ordering. App formats the identical text, reads player world X and camera X at the original consumer point, and keeps visibility logic. Camera behavior is not changed.

PlainsRegionStage.hud_world_regions interprets only the former concrete module-definition portion: anchors and the windchime well's second platform bank. It returns fresh world-space Rect2 arrays using the exact original offsets/sizes and original module traversal order. No Node, assembler, definition, state container, mutable owner array, App context or new class is exposed. Forest inherits the same source behavior, including an empty module collection where that is its original layout.

App retains all player/actor/projectile geometry, critical_count before world regions, canvas transform and viewport reads, projection/intersection/clipping and scoring. It consumes blocker rectangles in original anchor order and required rectangles in original bank order. Its entire original latch loop and all subsequent code are byte-identical: latch is_open is still queried only after that latch intersects the viewport, and latches remain after modules in each output list. This is the smallest two-query boundary; it deliberately does not migrate unrelated live actor/latch APIs.

The pure canvas multiplications formerly interleaved with world-field reads now occur after world-value collection. All world reads retain original order, and each actual output list retains its own ordering and filtering. These are synchronous read-only operations with no await, callback or world mutation; this is not claimed as instruction-by-instruction execution identity. No cache, fallback for malformed current content or new lookup policy was added.

prepare.py demonstrates exact entire-source inversion for all three files, plus external git patch application and reversal. It additionally proves the latch-and-later App suffix remains exact. candidate.json records full hashes and zero remaining App assembler references. This does not substitute for native/GPU validation.

Existing-check mapping:
- tests/underworld_plains/test_fine_hud_bounds.gd: actual formal map2, camera extrema, viewport containment/touch reservations and debug/normal controls. Preserve all existing actions/assertions.
- Existing actual App Plains and Forest loading/lifecycle consumers: source-specific inheritance, empty module collections and debug text access. Normal and debug HUD must both remain loadable.
- tests/level_plan_runner.gd: unchanged plan/runtime contract and source-free shared assembly; no claim of complete new-source App support.
- Focused query equality on actual installed anchors/windchime banks can compare old expressions to new values externally or in an existing meaningful runner; do not create a parallel production geometry implementation.

Rollback: 2d44aaeb. The independent architectural review remains /workspace/refactor-evidence/final-map-boundary-review.json. Its new-source gate remains outstanding: existing legacy Stage/App still require compatibility source data. This patch finishes the two concrete App assembler presentation leaks; it does not implement a new Provider/module library or promise that an empty legacy_generated envelope works through the entire formal App.
