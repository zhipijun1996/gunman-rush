# ENEMY-FEEDBACK-01 · independent review v2

Reviewer `/root/feedback_review`, separate agent from production/test authors. Reviewed commit `82940b7f057d74bfadf5855b1d489c38619c4a00`; baseline `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`. No production or test edits by reviewer. Original v1 findings remain in [review-v1](review-v1.md).

**ACCEPT for the bounded two-enemy technical sample:** both rendering chains consume the shared accepted-damage state, real projectile deaths remain single, and the independently repeated default Plains consumer preserves drop receipts and restored corpse silence. **Full Integration/content completion remains UNVERIFIED**, including the existing forest charger consumer, full normal-speed video/audio review, user and physical-device acceptance. This report does not authorize a main merge or broad rollout.

## Independent execution

Under root-granted exclusive engine lease, ran these actual commands sequentially in the implementation worktree:

```sh
timeout 120 bash tools/godot.sh --headless --path . --fixed-fps 60 --script res://tests/enemy_feedback_01_tests.gd
timeout 120 bash tools/godot.sh --headless --path . --fixed-fps 60 --script res://tests/enemy_feedback_01_formal.gd
```

Both returned exit 0 with Godot `4.7.2.stable.official.ed1daf0bf`, native marker `ENEMY_FEEDBACK_01 checks=154 failures=0`, formal marker `ENEMY_FEEDBACK_01_FORMAL checks=44 failures=0`. Full reviewer logs contain no ERROR/SCRIPT ERROR/FAIL/leak marker. Logs and distinct raw result copies are `build/enemy-feedback-01/review-v2-{native,formal}.log`, `review-v2-runtime.json`, `review-v2-formal-runtime.json`; source and evidence SHA256 below.

- Native matrix: charger/diver × original EnemyPresentation/real Underworld installer; actual Router→ShootAbility→PlayerProjectile swept collision→FrameDamagePolicy→HP. Pause/hurt/death clocks, scaled engine delta, old health/stage epoch, replay/friendly/nonfinite rejection, terminal restore and signal/component release passed. Component/feedback methods were not used to fake an accepted hit.
- Formal consumer: default `DemoApp.start_plains("enemy-feedback-01-formal")`, actual generated actors and formal skin. Explicit initial player Motor positioning on preexisting safe terrain is a fixture, not natural campaign traversal; enemy AI/HP/collision/reward/Manifest were unmodified.
- Generated charger `plains/enemy/tutorial`: three actual shot contexts, 2 ordinary hurts, 1 accepted death; configured coin drop has exactly one pickup. Generated diver `plains/enemy/window/plains/passage/area_1_2/area_2_2_0/ferry_air_intercept`: three contexts, 2 hurts, 1 death; legitimate configured none creates zero pickups.
- Actual asynchronous same-map `_load_stage` was awaited to readiness; old stage released, actor epoch increased, Manifest and drop receipt retained, terminal enemies hidden/restored without fresh hurt/death/defeat audio. Audio playback ownership was drained within the existing bounded teardown. Backend release is not a listening test.

## Source/contract review

Verified the eight directly relevant controller-owned source/resources remain byte-identical to baseline: EnemyActor, PixelPlainsEnemy, WindchimeEnemyVisual, ForestBibleActors, EnemyDropService, feedback.tres, and both enemy Definitions. Production diff is limited to the two allowed presentation scripts and the task component/UID.

The selected Underworld child skips the legacy anonymous hurt-only `_ready`, then preserves the parent's `_process` ownership of death clock/alpha/visibility. Original and formal presentation exit paths disconnect the shared RefCounted listener. Component has no damage, movement, audio, defeated, reward, node, timer or tween side effects. APPLIED/damage/current epoch/nonempty unique event filtering and lethal latch align with the real HealthState/FrameDamagePolicy contract. Nonselected definitions and prototype candidates with distinct stable IDs stay on their existing presentation branch.

## Actual pixel observations (sampled, not full playback)

Opened the actual 1280×720 candidate video frame 662, then viewed per-case baseline/candidate strips (every 15th video frame over the ranges below), and candidate adjacent-frame crops. Strips/crops are diagnostic views of decoded actual MP4 frames; they are not delivery animation or substitute video.

| Case | Viewed baseline + candidate video-frame range | Candidate contiguous neighbors actually viewed |
| --- | --- | --- |
| Original chain charger | 55–220 every 15 frames | 61–68 and 184–191 |
| Original chain diver | 355–520 every 15 frames | 363–370 and 490–497 |
| Formal Underworld charger | 660–825 every 15 frames | 666–673 and 789–796 |
| Formal Underworld diver | 965–1130 every 15 frames | 969–976 and 1096–1103 |

Observed: distinct beetle/winged silhouettes and their authored textures remain, real projectiles precede visible contact feedback, hurt settles toward the authored pose, grounded bodies retain the support line, aerial flutter/heading remain, and terminal bodies enter one bounded fade. Sampled candidate old-chain final frames fade to empty, rather than retaining the old corpse. No visible one-frame teleport or repeated death was found in these inspected windows. This is a bounded expert visual observation, not a commercial-quality score or a claim that both complete movies were played or their audio heard.

Actual baseline/candidate MP4 SHA256 were independently recomputed and match their capture reports:

- before: `bbdbc3ed7275fe759b34610f82bb67aeffee3b6934b53702cae9c91956b85cde`
- after: `b7faf7a276ef310616ea0a77e32b9916edf18c3c53e1078a5b7614e92ea91bad`

Independent Python comparison of all 1200 recorded driver frames found exact equality of case/local frame/pause/player position+velocity/enemy position+velocity/HP/AI state; report source_stable=true for each run. The MP4s are 20.233333s each. Driver trace frame and video frame have setup/teardown offsets; this review labels actual decoded video-frame indices and does not invent tick↔video identity. Frames/crops live under `build/enemy-feedback-01/review-v2-pixels/`.

## Findings disposition and remaining scope

- EF01-R2 fixed in reviewed source: selected old-chain body alpha is `.8 * max(0, 1 - t/.5)` and mote alpha is `max(0, 1 - t/.5)` before the .5s draw cutoff. Both approach zero; sampled final frames confirm the prior opaque hard-cut candidate no longer appears. No parent timing or visibility change was needed.
- EF01-R1 retained as integration coverage obligation. Existing ForestBibleActors/ThornForestRegionStage charger is also a selected-definition consumer; documentation now names it, while full affected Integration remains pending. No forest runtime/visual PASS is granted here.
- Existing parent same-instance dead→alive reset visibility is unchanged and remains outside the validated stage-rebuild scope.
- Audio perceptual quality/sync listening, complete normal-speed movie continuity, full consumer Integration, natural traversal, user visual/feel acceptance, and physical-device performance remain UNVERIFIED. FFprobe stereo audio and headless/backend teardown do not close them.

## Reviewed source and executed evidence SHA256

```json
{
  "scripts/enemies/enemy_feedback_01.gd": "1bda8f9241f04e735cc3d121b29c33d92a501075e90907e860c0059b82a591a2",
  "scripts/enemies/enemy_presentation.gd": "f4e4c28a0d06adf808b570b83f9358d45d29c3d6bd70fb35d28d59cb25ba3ec4",
  "scripts/underworld_plains/underworld_enemy.gd": "a6a6f59359fa992bde7b6d8f674b5b87ae3267653446c0844dfff4622ef35d54",
  "build/enemy-feedback-01/review-v2-native.log": "8da029ece18e48db4bf6c9f4c18b4c98b4de9e494829a58b0775af74dbbe8747",
  "build/enemy-feedback-01/review-v2-formal.log": "515c2ed3a09a6225b9f9926128d902e1e99533935ca884a17259c0a889a85bda",
  "build/enemy-feedback-01/review-v2-runtime.json": "cee274ef210063949a1c071ce081ce3b6b3143d27af8dc5251c24095ec7f4bb9",
  "build/enemy-feedback-01/review-v2-formal-runtime.json": "919831d44cf483fe510003267a00d63ad411fdd300d6902d2b15ce467abddc9e"
}
```
