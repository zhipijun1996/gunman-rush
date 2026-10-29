# PLAINS-MONSTER-REVISION-01 · R2 limited code / guard review

**Verdict: ACCEPT only for the inspected code and test-consumer adaptation below. Visual/animation/auditory acceptance remains UNVERIFIED; R1's old-film REVISE is preserved.** Reviewer `/root/plains_revision_review`, independent of implementers. Read-only: no Game/test/task changes and no Godot execution by this reviewer.

Reviewed commit: `4ff79069628776ac489e3344cd3e49d390a4db56`; tree `59a566a856e6c95452761ed6b9ff4eb808599bf1`. Worktree was clean when this report was written. This report reads the actual current committed files and root's actual runtime logs. The raw logs by themselves do not embed a complete commit/input snapshot, so this reviewer does not invent an exact4ff fresh execution or claim the tests were independently run. Root must retain its execution/source receipts with the final evidence.

## Muzzle and physical-volume handling

`EnemyDefinition` is the unique source for muzzle pivot/reach; sentry definition v3 sets (8,-12)+12wu along locked aim. Other registered definitions keep zero defaults. Finite pivot and nonnegative finite reach are validated. This is an explicit sentry projectile-origin change, not a claim that its reach/origin is byte-identical to the old center-origin behavior.

`EnemyAttackBehavior._fire` constructs the same projectile/event/token and locked direction, starts at the original Actor center, then requests a true clearance sweep to the configured mouth. `EnemyAttackProjectile.launch_to_muzzle` reuses the original radius4 circle, initial overlap check, cast_motion, first-contact result and FrameDamagePolicy submission. It preserves the original wall-over-player occlusion rule independent of physics-query ordering. No flight/lifetime/visual clock advances during placement; no fake center-to-mouth visual trail is created. The same helper guards stale actor/stage tokens, dead owner, protected interval and invalid destination. Already spent seeds cannot submit another damage request. Zero-offset consumers bypass the placement query and keep original spawn/spread.

The20-case fixture is meaningful: it uses actual factory/Definition, PhysicsServer shapes and FrameDamagePolicy and explicitly discloses controlled initial placements/manual entered-attack callback. It checks horizontal/vertical/diagonal locked aims, mirrored pivot, old zero-offset fan, thin wall, initial overlap, radius-grazing corner that clears a center ray, close player first contact, simultaneous wall/player under both creation orders, ordinary subsequent flight and five cancellation/protection cases. It does not claim natural AI combat, pixels or balance. The complete root log has167 checks/0failures/20cases and clean audio/exit output; no rejected shader/script/leak text was found.

## Existing tests retain their responsibilities

The3 migrated old consumers inspect the real new charger rig rather than installing a fake feedback_body or routing tests to an unused old art branch. Diver retains original authored Frames assertions. Four old style/species libraries are independently instantiated and all8 distinct payloads plus bounds/H3 source-anchor contract remain protected.

Real accepted damage, duplicate/old epoch rejection, per-instance body ShaderMaterial isolation, true hit_flash propagation, pause/slow-time, persistent support, dead restore/reload, unique drop receipts and unload WeakRefs remain. New charger hurt evidence observes its actual shared sample, fixed mother texture/bounds and nonzero body-joint response. The death reporting intervals4..7 are explicitly continuous progress intervals, not newly authored sprite cells. Final persistent checks additionally require `_finished_death`, actual captured rig identity, texture and bounds. The ordered-death observation was moved after the original already-existing130-frame hold, without increasing total observation budget.

The new lifecycle runner uses real factory/installer/receiver/support with clearly declared disabled AI timing fixtures. It adds sampled death=0 identity over captured load/strike/hurt/recovery/turn/air poses, terminal geometry finiteness/no-ground-penetration/future-clock independence, one clock advance, pause/epoch, actual ground/air settlement, persistent-versus-fade policy and restore/unload checks. Root's native02 failed4 handoff assertions and is retained; native03 has323/0 with clean output. The migrated old native log has480/0 with clean output. These logs remain implementation-run evidence.

### Small remaining guard-coverage note (not a found production defect)

For the new rig, `feedback_frame_index==-1` is a permanently unused legacy field; by itself it cannot prove the visible rig exited hurt. The test also checks the shared hurt timer reaching0, but could more directly assert `revision_visual.pose.hurt==0` and equal current no-hurt geometry after the accepted recovery window. Current production refresh synchronizes that value each tick, so no actual stuck-hurt bug is identified. This is a narrow remaining test-coverage recommendation; it must not be silently described as exact equivalence of every old frame-index semantic.

## Formal leak diagnosis and resolution scope

Original formal01 printed66/0 but leaked52 ObjectDB/32resources; it remains FAIL. Verbose identities refuted the earlier RootBellPulseArt/static-manifest guess. Root's controlled load-only probes showed: Visual alone clean, baseline old formal with current production clean, migrated formal alone reproduces the leak. Removing nested inferred revision types from actual_final_body removed the revision resource graph but left8 old Frame resources; removing that branch's nested inferred frame calls through Object.get/RefCounted/call gave a clean second load-only probe.

The final helper still checks exact new-remains script identity, index7, `_finished_death`, same actual rig/texture/bounds; its old branch checks actual final texture/bounds. This repairs test compilation/dependency resolution; it does not suppress an engine warning or waive a runtime check. The original full formal02 log now contains66/0, normal audio drain and no script/shader/ObjectDB/resource/RID failure. Root reports the wrapper exit clean. The complete diagnosis trail, including withdrawn hypotheses, is retained at `/tmp/plains_revision_leak_review.md`. Neither a clean probe nor this code review is a full gameplay/art/device Release verdict.

## Collider, pulse and remaining visual work

Root-bell definition v2 now declares40×48 main collision, as authorized by the user's body-fit request. Current admitted v3 placement derives home from the actual definition half-height; parent contact assembly derives its actual collision size. Collider changes also affect any existing behavior predicates that read that dimension (e.g. the root-bell vertical target band); do not describe these derived consequences as literally unchanged geometry/AI input. Latest actual formal scale/collision comparison is still required. Historical legacy-v10 fixed-20 placement is not claimed revalidated here.

RootBellPulseArt draws the existing authored burst only for the real active attack and brief tail. Its1wu/nearest material is body-independent, and actual active pulse display size still comes from Definition.pulse_size. It replaces a colored hitbox display with the prior authored active roots, not a new damage authority. Death and epoch cancellation remain Actor/Behavior-owned; rig/corpse/particles do not add Damageables.

R1 code-level findings have corresponding implementation changes (death bridge, real readonly aim, signed pending turn, body early cull, organ darkening and fuller ground-death depth), but their effectiveness needs the new actual GPU movie. The old patrol thin-corpse film remains rejected. This report has not viewed the new six other species, the pending review02 movie, the actual plains comparison, or listened to the new low bell. Overall7-monster art/animation/user/device status remains review/unverified.

## Files and raw log SHA256 read

```json
{
  "scripts/enemies/enemy_definition.gd": "7c0b0d9f0a820ee9aafb6169594dc59fe66d0e34bad5bd25ff738f154a5e57a9",
  "scripts/enemies/enemy_attack_behavior.gd": "388c62cc373081e9cd4a0de18accc523ebb6f5d985f2830dd60ff36832a243c9",
  "scripts/enemies/enemy_attack_projectile.gd": "2095c5ec63ec9d710ef0d8f617a575413e0674a0352d84726eed0dba02573eb7",
  "resources/enemies/plains_sentry.tres": "cd8defc9e43624a38a1a3184cf9a3815b87241eed4d671c650669cd1f4595768",
  "resources/enemies/plains_root_bell.tres": "8b063c74820570a8be89841c83993299c2afa9e9b317aaa453d8c295c95167c8",
  "scripts/enemies/root_bell_pulse_art.gd": "4b803dee19516b52185ef2f586ffc38c102a3fe1444391b7fd0ef3c8ba0f4bdb",
  "scripts/enemies/plains_revision_skin.gd": "10a76c7e0a0cc804c13eccf5faadbf2bfdc9e755202e7bbf59ffa454f0e8ae34",
  "scripts/enemies/plains_revision_visual.gd": "cfc08821c52af9b7076fa7560aebce6f2c1022b41dea2ae72388a3c6ffda76ea",
  "scripts/enemies/plains_revision_remains.gd": "e894ca5f306fcb527c64690d9e79d859a4b7d619e2ec2663904ec0d753cd0924",
  "scripts/enemies/plains_revision_ground.gd": "2c91c7e9e6df16918036c7daffe07d66217e9318cba9b7f625d35960d9d225ef",
  "scripts/enemies/plains_revision_flora.gd": "8bfe61b9fcdfec4cc655a6818656b23fc3465869272e96187072e38fad352391",
  "tests/plains_revision_01_muzzle.gd": "be40c9a55e76dc70204e56c1f9214d3799eecd5df53c3764bfe8eb281ad0ed85",
  "tests/plains_revision_01_runner.gd": "699d886305696c6ef0985949468c96003477403f4c7a8b8953c3e53e0a5c38c0",
  "tests/enemy_feedback_01_tests.gd": "ff9c0647436a98803f1a3616bc88c35d5e8cf856cf947d6862e1dc95028832c7",
  "tests/enemy_all_02_plains_lifecycle.gd": "503d11ab54dbd2d8053e205f1b25c0bedd6b1a58bff922af38faa014dc4a69c2",
  "tests/enemy_feedback_01_formal.gd": "b17695690b87539bbec6ff32c05cc7636910ea804cb873b8df4ba390c010c84a",
  "build/plains-revision-muzzle-native-01.log": "6aa615ea774ec57d6d18336a1c5d4b7e22cd0d3709f86df3e6d259688b31b3ec",
  "build/plains-revision-native-02.log": "2332c41d52ce30edde348b00feebc34300b4f2db2d05fc71cf202bd6f0d8190a",
  "build/plains-revision-native-03.log": "463656a114a998ee2c1c6ac189851cedf19a1ab033ddda994e6980fe8bf7f276",
  "build/plains-revision-legacy-native-02.log": "64e6b06056581950adcd87ba8371115c2cad5ebb27e3319cd7dfd241b4e950e2",
  "build/plains-revision-formal-01.log": "5dbbcf5e6bae5c09325e44f2cd00f4e967b23ecb8f1edbb8d2da14de18bdc8ad",
  "build/plains-revision-formal-verbose-01.log": "563df3ecdd87d83b0633fe5b22ca1e6701ca834b93f5bcfe78f92cdaf4a034c8",
  "build/plains-revision-formal-dynamic-load-probe-02.log": "f6a0b62bb810b2cee37ef31cb43caddf533fc57e280b2abb3b9edbf54820b205",
  "build/plains-revision-formal-02.log": "37fd125b66ea970c8df9200c4aa333d34f9dde329293d95c8bb11a7c6cd76b3e"
}
```
