# Seed01 growth: independent aim-sampling review

**SCOPED ACCEPT:** the patch expands legal v15 consumer aim samples while retaining the physical guards, and the previously failing actual seed01/map1/growth case now passes. This does not establish that the fresh 80-case corpus has passed.

Only `tests/forest_bible_trace_support.gd` differs from the original failed case's 3600-entry source inventory: `a85e5d6e…` → `039c94affdfc07cfa96be5540340494601ac2cffb80acf9b115fbb1e72840e27`. The fixed case's complete source inventory matches before/after and current files. Runtime mechanics, actor definitions, geometry, projectile radius, historical driver, assertions and budgets are unchanged.

The original three samples remain first, in the same order. Only after those fail does the pilot try two inner body-edge samples, `±max(0, half_height - projectile_radius - 1)`. For this actual spider, half-height 14 and actual radius 3 yield ±10, leaving one unit inside the existing radius-shrunken body. Every candidate still passes the original body-hit predicate, body→actual-muzzle circle clearance and actual-muzzle→body-point circle clearance. The original ground/recoil envelope, resource/readiness checks, 600-tick encounter limit and 12-request limit remain. No seed-specific branch, actor movement, health grant, wall removal or producer/layout change was added.

The original failed trace stopped after 18/27 legs with `forest_encounter_bounded_return/hollow_route__borer_entry_thread`. The spider took one actual hit and remained at health 1 after its ordinary recoil moved x310→293.8.

The fresh full CLI result is source-bound capture SHA256 `81cc4e3d5c63b99c4dcdcab52b4348d02f15e2cdb39c9d0a9c99714eb8a412e9`, native 12.547 seconds. The original validator was independently replayed with **zero errors**. All 27 route legs complete with 1999 contiguous ordinary Motor samples, health 5 throughout, no player-damage events, and unchanged actor/stage epochs 3/3.

The old and new manifests and initial snapshots match exactly. Physical position, velocity, health, resources, support, enemy state and lifecycle fields match through tick **1366**. Their first difference is at tick **1367**, the new second actual shot and its ordinary recoil/resource effect. This is direct evidence of a changed legal consumer input, rather than an altered starting world.

Both real Router requests and actual projectile custody are present: serial 9 fires at tick 1341 and commits damage at 1348, reducing spider health 2→1; serial 10 fires at 1367 and commits damage at 1375, reducing health 1→0. The pilot then returns to the original `hollow__belly_entry` shore at tick 1406 with the unchanged 12-full-foot-frame condition. The actual second-muzzle ray's cross-section clears the perch's right corner by approximately 1.856 units beyond the real radius; this straight-line calculation is supporting geometry only. The actual native projectile damage establishes collision success.

This is a finite v15 **test-consumer input** repair. It does not establish every seed/route, aesthetic quality or player skill expectations. The fresh original 80-case corpus remains a separate acceptance requirement. Existing F05/F08 movies retain their original clean048 source attribution and were not changed or reattributed to this later helper patch.

Evidence: `review.json`, `actual-source-diff.patch`, `patched-helper.source.txt`, the preserved original failure, and `build/forest_depth/region/v15-seed01-growth-second/`. No engine or production-source edit was performed by this reviewer.
