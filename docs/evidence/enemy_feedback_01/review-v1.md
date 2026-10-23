# ENEMY-FEEDBACK-01 · independent review v1

Reviewer: `/root/feedback_review`, separate read-only agent; author `/root`. Baseline `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`; candidate working-tree bytes are bound below. Review method: gameplay-reviewer and `docs/quality/review_method.md`. No production/test changes, no Godot run, no media playback or audio listening in this review (root owns engine/capture lease).

**Verdict: UNVERIFIED for runtime/content completion.** Source inspection supports the narrow accepted-event/lifecycle design; no confirmed AI, damage, collision, reward, audio, parent-death-clock or visibility writes outside the authorized presentation scripts were found. This is not a runtime, visual, user or device PASS.

## Inspected consumer matrix

| Consumer | Source result | Remaining evidence |
| --- | --- | --- |
| Original `patrol_drone.tscn` with `plains_charger`/`plains_diver` Definition | Each selected EnemyPresentation creates the shared component, replacing its old HP listener. Nonselected definitions take the old path. | Fresh two-object/two-chain runtime and real pixels. |
| UnderworldActorInstaller → UnderworldEnemy → PixelPlainsEnemy/WindchimeEnemyVisual | Selected child skips only the legacy hurt-only `_ready`; its `_process` still calls the parent. `_death`, `visible`, and `modulate.a` remain parent-owned. | Actual installer substitution and lifecycle run. |
| Default DemoApp PlainsRegionStage | Factory duplicates original definitions without changing selected stable IDs, so new component is consumed by actual generated charger/diver. | Official projectile, drop, same-map rebuild evidence. |
| ForestBibleActors installer / retained forest charger | Forest stage explicitly loads plains_charger; Bible installer replaces it with UnderworldEnemy. This is the same selected species, but an additional formal consumer. | Include in actual consumer inventory; fresh affected forest integration before merge. Plain-only evidence must not sign this consumer. |
| ActionStudio ordinary actors / PrototypeEnemyPresentation candidate subclass | Ordinary charger/diver also consume shared base. Candidate guard/moth change stable IDs, so remain on old path. | Existing actor-actions and actual consumer regression. |

## Contract inspection

- Shared state reads `HealthState.changed`, requiring APPLIED + damage + negative applied amount + current health epoch + nonempty unique event ID; REPLAY/STALE/TERMINAL and set_max/heal changes cannot start selected feedback through the normal API.
- `_terminal` latches lethal feedback and initialize synchronizes from actual current HP, clearing short clocks and epoch receipts. Restored terminal snapshots set `restored_terminal` without accepted death/hurt counters.
- Both selected `_exit_tree` paths call component.dispose; its named signal is disconnected, releasing the HealthState/RefCounted ownership cycle. No Timer/Tween/async callback/effect node is created by the component.
- Component has no damage, motion, audio, defeated or drop call. Existing EnemyActor/Damageable and DemoApp/EnemyDropService retain those outcomes; idempotence still needs runtime proof at their formal consumer.
- Previous weight-multiplication concern is repaired in inspected bytes: profile multiplies `desired` before lerp, rather than accumulating into `_weight` each frame. A pure-Python 121-step reproduction remained within the authored target envelope and returned toward authored telegraph/attack scale. This mathematical check does not sign silhouette quality.
- Existing parent same-instance dead→alive visibility/death-clock reset limitation is documented and not modified. Rebuilding a stage is a separate supported consumer. Do not generalize the latter evidence to the former.

## Findings and follow-up

### EF01-R1 · formal consumer coverage (integration, medium)

Fact: `scripts/demo/thorn_forest_region_stage.gd` loads plains_charger for charger rows; `scripts/presentation/forest_bible_actor_presentation.gd:install` replaces that body with UnderworldEnemy. New stable-ID selection therefore reaches existing forest chargers too. This does not add a new species or authorize new ForestBibleActors writes. Add those actual consumers to inventory and execute affected integration before merge. Missing that evidence remains UNVERIFIED, not evidence that the code is broken.

### EF01-R2 · old-chain death cutoff (animation candidate, medium)

At inspected EnemyPresentation line 51, death_active=false skips all drawing after 0.5s. Immediately before the cutoff, its existing body tint alpha approaches `0.8 - 0.5*0.5 = 0.55`, and mote alpha approaches `1 - 0.5*1.6 = 0.2`. This creates a new discontinuity in submitted alpha. Whether pixels make it visibly abrupt needs the actual normal-speed movie. Consider fading the selected old-chain body/motes to zero inside the owned 0.5s window; parent timing must remain untouched. This is a calculated review candidate, not an invented observed visual failure.

## Evidence boundary

Read root-produced `runtime-v3-charger.log` (154 checks/0 failures) and `formal-v1.log` (44 checks/0 failures), including actual default map assembly/rebuild and bounded audio release. These are author executions and are not represented as my independent engine reruns. First parser failure and old patrol evidence remain historical. Fresh full affected integration, pixel/audio observation, user acceptance, and physical device evidence are not supplied by this review.

## Reviewed bytes (SHA256)

```json
{
  "scripts/enemies/enemy_feedback_01.gd": "1bda8f9241f04e735cc3d121b29c33d92a501075e90907e860c0059b82a591a2",
  "scripts/enemies/enemy_presentation.gd": "f4e4c28a0d06adf808b570b83f9358d45d29c3d6bd70fb35d28d59cb25ba3ec4",
  "scripts/underworld_plains/underworld_enemy.gd": "a6a6f59359fa992bde7b6d8f674b5b87ae3267653446c0844dfff4622ef35d54",
  "scripts/art_foundation/pixel_plains_enemy.gd": "babba1d1270e9ddca01373a1d5282187e2086a82899635a37edf58706a81d166",
  "scripts/art_foundation/windchime_enemy_visual.gd": "60e2aa69ae7be4a10ac3fab6eb50899a5d120a3050bd1f676f1502701a0f2040"
}
```
