# FOREST-V11-DEFINITION-LOCK-01

This is a historical-content defect fix, separate from behavior-preserving architecture changes.

The original forest-depth-versions data test fails 280 assertions / 2 failures on both the integration baseline and the refactor. Root retained the baseline run at `/workspace/refactor-evidence/baseline-forest-versions.log`; no engine was run by this change's implementer.

`ThornForestRegionV2V11._candidate` delegates initial ecology to the v10 producer. That producer read the current `plains_charger.tres`, used its collision size for standing position and patrol sweep, and serialized its current file SHA. The fixture was committed by `7ba2e92d2c3cb5449ac6648b820f79679548ee89`; its exact historical resource is also present at `ff4fd36b`. Commit `7edda9f5f2a20c5406391ff3f7edebbeb2322047` later changed the current Definition from v2 / 28×32 to v3 / 28×28. Baseline `2ce4ffa6` already contains that change. Map1 has the affected charger; map2 does not.

The retained resource is byte-identical to `7ba2e92d:resources/enemies/plains_charger.tres`: SHA-256 `1afd5e34d497e3850d794b028fd5fe5407d3722fcd451d862f4c14a67ca98fc0`. Its existing `patrol_health.tres` dependency is unchanged from that commit. The current default remains SHA-256 `39513bce9f2d604514a88838d733db24b723ce965402ce5579e8260f5a83a232` and 28×28.

The existing EnemyBehaviorRegistry owns the finite historical revision mapping. Only the v11 producer explicitly selects it. Manifest logical resource paths, recorded SHA values, IDs, RNG calls and ordering remain original. The legacy LevelPlan adapter passes the same explicit revision to the existing factory so the historical live actor uses the recorded 28×32 collision as well. Unknown revisions or changed retained bytes reject instead of choosing current content. Current/v15 selection and current factory defaults remain unchanged.

No original fixtures, expected hashes, assertions or test budgets were edited. Added `tests/forest_v11_definition_runner.gd` checks both exact recorded maps, revision rejection, repeated generation, actual historical App collision, current default collision and current v15 admission. Required root validation: original forest-depth-versions data/world/App phases and the new runner. Runtime result: pending; static checks do not constitute native acceptance.

The v7/v9/v10 producers also read live enemy definitions and retain a related potential drift risk. This fix does not change their outputs or claim that all historical content is fully frozen. AI, art and audio remain current; this explicitly pins the recorded Definition resource, not an archived simulation engine.
