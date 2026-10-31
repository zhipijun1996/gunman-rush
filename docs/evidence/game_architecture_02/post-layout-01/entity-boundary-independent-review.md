# P6 independent enemy-boundary review

Verdict: **ACCEPT within the bounded static scope; no blocking findings.** Reviewer `items_refactor` did not implement P6. Reviewed `f44f8eec` plus the exact-key-type correction `efb202db`, and their real consumer integration at snapshot `d8144d39fbee9b0f6166369f25399702ac7f8b20`, against baseline `2ce4ffa6`. Sources were read through immutable Git; no production/test/asset changes and no engine execution were made.

## Actual consumers

- PlainsRegionStage (`scripts/demo/plains_region_stage.gd:287`) and PlainsEnvironmentStage (`scripts/demo/plains_environment_stage.gd:85`) use `actor.region_snapshot()`.
- ThornForestRegionStage (`scripts/demo/thorn_forest_region_stage.gd:199`) uses `actor.region_snapshot(false,true)`.
- DemoApp (`scripts/demo/demo_app.gd:693`) uses `attack_behavior.restore_region_state(saved)` after encounter and authored shore/transfer/strand/line binding.

The old per-Stage enemy dictionary assembly and App direct generic attack assignments were removed. This is actual consumer migration, not an unused helper.

## Schema and ordering

The plains/environment record keeps eleven fields in original insertion order: health, position, state, state_time, cooldown, serial, locked_direction, attack_goal, attack_origin, home, direction. Forest keeps its original eight fields without the attack vectors. All original literal fields remain **String** keys. Only the forest depth_state extension remains its historically dot-appended **StringName**. The interim f44 dot-insertion problem is corrected by efb; acceptance covers that correction.

All eight registered enemy scenes bind Actor.motor to `NodePath("..")`, so motor.position is the same local coordinate source as the old enemies[i].position. No world-coordinate substitution, actor reset, phase advance or epoch mutation is introduced by snapshot.

An independent normalized source comparison confirms that restore assignment statements and order match the old App block exactly after removing the owner prefix: phase, time, cooldown, serial, optional home, optional vectors, facing, then depth restore. Stage health/position restoration still precedes this; attack concurrency limits, presentation and contacts still follow it.

## Species-specific refusal semantics

**Weaver:** generic outer fields are assigned before depth validation. Depth checks compare against those fields and the already-authored strands. On rejection, those outer assignments intentionally remain, and App abandons the run. This preserves the previous partial-write behavior; the refactor does not claim atomic rollback or accept geometry from save.

**Crossbranch:** its override only invokes depth restoration and skips all generic outer writes, including home/facing. Its actual restore_depth_state implementation is unchanged: complete physical record validation precedes applying transit state, and target actor epoch is rebound as before. App/Stage retain required-depth checks; absence in the low-level optional extension still remains the previous no-op.

## Candidate registry

EnemyFactory now reads candidate behavior from the existing registry, removing the second behavior mapping from recipe data. Registry tables, admission/refusal, script/scene/definition and strategy lookup are unchanged. ModuleEnemyPrototypes and ActionStudio remain real Factory consumers. Lab/review and Studio keep their intentionally different width/speed/defaults; prototype guard and moth script mapping are unchanged.

## Evidence limits

The independent static checks are recorded in `entity-boundary-independent-static-checks.json`; the adjacent review JSON records exact source hashes. Root reported the original dedicated runner at **61 checks / 0 failures**. The reviewer did not run it or any Godot process. The dedicated runner is a labeled real-Actor fixture, not a natural App/three-Stage playthrough.

This bounded acceptance is not release approval. The separate formal teardown leak was bisected by root to P3 and must still be resolved by the integration owner. No cache-clearing workaround was introduced.
