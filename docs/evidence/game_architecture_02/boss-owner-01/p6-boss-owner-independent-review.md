# P6 Boss state ownership: independent static review

Verdict: **ACCEPT for the bounded source relocation and original test preservation only.** Native execution, full182, export and device acceptance remain unverified.

Reviewer: /root/ci_audit. Implementer: /root/items_refactor. Reviewer did not modify candidate production/test files.
Baseline: `6584d48bca916de100eed3801af6f0973ae49767`. Reviewed frozen working bytes:

| File | SHA256 |
|---|---|
| game/bosses/encounter/boss_encounter.gd | `86f6df7f8a80a8fab03d4fbbd7d6d0ac96ebb7aa5add4dba4d78ff4fc070641f` |
| game/bosses/windkeeper/windkeeper_encounter.gd | `b6bad0306339152167dade9458c0d8547d9154a3c377c767865a81c392127566` |
| game/bosses/bellstrider/bellstrider_encounter.gd | `58c682404af6e9279099f6d2d63982702d4d001b0b4b6b56817b366400eaf6e9` |
| game/bosses/thorn_forest/thorn_forest_encounter.gd | `6e4b5064dd3a4402c9490fceeec2700dd80d550d9d5b192a86cf39aecaf91432` |
| game/world/levels/providers/plains_region_stage.gd | `a98521042831129c796cd03b497b977efe95546c43a8960735623993867c93ba` |
| game/world/levels/providers/thorn_forest_region_stage.gd | `74e1959bc5ceec2aac77d8659a92ab968f16c49d0fff8c8f5d8012f256be17f4` |
| game/application/demo_app.gd | `77674db1b78a94b2ab25ffa679282e9bf7ba9da396165fc84fa095f69bb34f85` |
| tests/forest_depth_restore_runner.gd | `1eb6cabaae222619a49c1eb44ff2bcfbbf6114b64679b1604727d2a1579ecbc9` |

## Verified source constraints

- All 8 current file hashes match frozen candidate; old text read independently from Git6584
- game/bosses/encounter/boss_encounter.gd: all existing method bodies byte-preserved
- game/bosses/windkeeper/windkeeper_encounter.gd: all existing method bodies byte-preserved
- game/bosses/bellstrider/bellstrider_encounter.gd: all existing method bodies byte-preserved
- game/bosses/thorn_forest/thorn_forest_encounter.gd: all existing method bodies byte-preserved
- Original forest validation/restore body exact after receiver qualification and four-statement health extraction
- Plains String-key literal exact field/order; merge(true); Forest dynamic snapshot then original StringName dot order; Stage seal remains external
- No base-derived dependency; Bell terminal prepare before health/phase/default pattern preserved
- Forest runner exact allowed3 call+4 diagnostic substitutions; all41 checks and full loops unchanged
- Position restore remains in original nonduel branch with exact scalar expression and no added guards;9 actual scene Encounter.motor references parent body
- Forest comment now correctly describes App schedules entity restore; no new behavior
- Whole-project dependency scan842 sources has0 errors; no Godot executed

## Test change justification

The removed App restore wrapper is now owned by ThornForestEncounter. The existing forest_depth_restore_runner migrates exactly three malformed-input invocations to that real owner and changes four diagnostic labels. All 41 check calls, malformed value matrices, expected conditions, frame loops, actual App stage unload/rebuild and activation remain unchanged. This is caller migration, not a lowered assertion or replacement synthetic runner.

## Limitations

The source proof cannot establish Godot parse/type success, signal/epoch runtime behavior or resource leak freedom. Run the existing plains-region, Bellstrider/Pressure, forest-depth-restore, forest duel/canopy and level-plan/state checks with their original budgets and strict exit guards.

App intro_seen cross-map policy injection, Arena rune_platform/phase contract and ordinary-enemy Stage.position unchanged, outside this bounded candidate

Snapshot construction now completes a local value dictionary before assigning Stage.boss_state. The actual family combat_snapshot methods are reads/value construction without callbacks into Stage; this review does not cover hypothetical arbitrary monkeypatched snapshot implementations.

## Exact commit binding

Reviewed commit and evidence source commit: `063d6ccbd7a6ab659fd27abcb20a5c59c7308c53`. Baseline remains `6584d48bca916de100eed3801af6f0973ae49767`.

The independent static review first covered the frozen working-tree candidate. The commit changes exactly the same8 files, and each committed blob SHA256 equals the reviewed source table above. This binds the existing bounded static ACCEPT to the committed bytes; it does not rerun or certify native/full182/export/device results. No production or test file was modified by the reviewer.
