# R3 damage implementation — bounded component evidence

Scope: user items 1 / 2 / 3. User clarified “导入导出” means hurt animation entry/exit. No speculative snapshot API or save-schema modification was made.

## Actual production changes

- DamageRequest carries finite hit_direction through the actual policy and receiver. A selected, actually committed Damageable hit emits its original damaged event exactly once, after fatal/return priority; rejected/deduplicated/stale/iframe requests never emit it.
- PlayerMotor alone moves the player. Accepted nonfatal monster damage queues bounded 230 x / -145 y force for .18 game seconds. It projects at walls, pauses with gameplay and clears on return/reset/death. During this window legal firing still consumes original resources/cooldown, but no recoil/ability movement is delayed into the future; normal gravity remains active. Afterward fresh shots behave normally.
- UnderworldPlayer plays its actual generated hurt frames for .32 game seconds, flashes for .65, and draws a bounded hit burst. Existing hidden PlayerFeedback remains the single player hurt-audio consumer; no duplicate cue was added. Environment HP/segment return remains synchronous. A .24-second world-anchored generated hurt silhouette remains at the true old hit point and the safe body fades in, retaining its hurt clip.
- Ordinary enemy actual committed hits now reach EnemyActor, play hurt audio, interrupt briefly and move only via EnemyMotor. Ground enemies get horizontal bounded force; this avoids permanently floating them in the existing gravity-free motor. Existing Underworld body art has hurt compression/recovery and pulsed tint.
- Boss/contact emitter can consume an owner-authoritative actual collision world rect, rather than hard-coded artwork extents. Existing epoch reset still prevents a teleport from becoming a swept attack.
- Frame bounds are no longer treated as side/top kill volumes by DamageBoundary; a whole-body bottom exit also checks actual lower landing colliders. This is defensive behavior, not evidence that framing bounds were the reproduced lower-floor bug.
- **Reproduced lower-floor bug:** the actual plains_ferry_channel definition has an unattached Rect2(200,430,400,24) local pit sensor. The original DemoApp treated this exactly like physical spikes. A real player falling through it lost 1 HP before standing on an actual lower floor. New records classify only below-all-local-solids, unattached horizontal bottom bands as fall_plane; they skip damage where actual lower landing geometry exists. Attached surfaces and explicit surface_thorns remain damaging. Original world_static_dangers and Definition/Manifest/RNG/save bytes are preserved. Records use the authoritative deduplicated order/rects.

## Executed bounded checks

`python3 tools/run_underworld_damage_r3_tests.py`: 273 assertions / 0 failures; strict no script errors / no resource leak exit. runtime.json contains real Motor/Router/contact traces, actual gear and attached-thorn 80-tick fixtures with source IDs, module IDs and epochs, old/new lower-route observations, true-pit negative, source-exit/safe-entry coordinates and three hurt/fire order fixtures. Original tests/damage_tests.gd is executed unmodified.

The unchanged player animation wrapper also passed 607 assertions / 583 actual Motor frames / 7 states on the final component source (final_player_animation.log). Parent whole-tree integration still requires its final frozen suite.

These are actual local component/assembled-module fixtures. Their spawns are explicitly initialized. They are not a natural full-region route, GPU/movie/audio-listening, phone, commercial visual quality or player-feel acceptance.

## Preserved failed probes

- final_headless.log: invalid new terminal-test HealthDefinition omitted resource_id, so two observer assertions failed. Fixed the fixture and added actual configure/register/submit success assertions; no production workaround.
- hurt_shoot_initial.log: after adding three rapid fixed-FPS shooting fixtures, the native AudioServer mix thread had not released its 12 voices, so two strict audio-cue assertions failed. A bounded test-only wait now observes real voice release before each isolated module sound check. Production voice limits, expected cue count and all original assertions are unchanged.
- Earlier successful incremental logs remain alongside final logs. They are not claimed to prove later source revisions.

implementation_receipt.json is an honest post-run hash inventory in a concurrent dirty working tree, not a fabricated whole-tree source guard. Parent integration must freeze and rerun the final suite and collect actual rendered/audio evidence.

## Optional real formal App environment capture

Producer: `tests/underworld_plains/capture_revision3_environment.gd`. Headless surface and moving-gear cases both pass 210 actual observations / 15 checks / 0 failures. Each starts an ordinary new run at full configured HP; exactly one explicitly recorded initial position assignment puts the player at an existing registered region safe anchor. Startup birth protection expires through actual game ticks. Real InputEventKey D, original KeyboardMouseAdapter, movement, emitter, policy and selective respawn then operate unchanged. No manual damage/heal, enemy pause, later position assignment, new checkpoint or clock mutation.

Both use map 1, seed `level-design-v2-baseline/08`. Attached surface: actual slalom_first / generated_spikes_6, starting/return anchor (4200,1210), HP5→4. Moving gear: actual rhythm_first in plains_twin_gears, starting/return anchor (1760,-700), HP5→4. The receipt records actual committed source and epochs, HealthState commit tick/old point, real postphysics renderer hurt/flash, old-world echo and safe-body fade. `--capture` additionally awaits every real frame_post_draw and writes all 210 original native PNGs. MovieMaker can be enabled separately with `--write-movie`.

Commands and exact current producer/trace SHA are in formal_capture_readiness.json. GPU captures were deliberately not started; parent will run them serially. Initial failed source assertion and its original trace are preserved rather than relabeled: first fixture selected a nonregistered module subanchor and approached during legitimate spawn protection, passed the first thorn and was actually hit by the later moving gear. Corrected fixture uses original registered region anchor and natural birth-protection expiry, with all source assertions intact.

## L follow-up: independently discovered ground-enemy cliff regression

The reviewer proposed a real edge case missing from the original 273 checks. A new helper `tests/underworld_plains/damage_enemy_edge_cases.gd` uses the unchanged actual plains_sentry definition (stationary by its authored speed, not paused AI), an actual narrow static platform, actual player Router/Shoot/projectile, original policy and EnemyActor. The original accepted-hurt force pushed a right-edge ground enemy from x585 to601.2002 beyond a floor ending x600; its mirrored left case moved x15 to-1.2002 beyond floor x0. Actual foot-center rays had no floor, and the gravity-free motor left it floating. `ground_edge_before_fix.log` preserves 297 checks / 2 failures, and `ground_edge_before_fix_runtime.json` preserves all observations.

Fix is limited to the new ordinary accepted-hurt path: `EnemyActor._accepted_hit` opts into `EnemyMotor.request_knockback(..., require_floor=true)` only for ground definitions. The next actual collision leading foot must find a standable floor on the actor collision mask; otherwise that hit force stops. Ordinary patrol/attack/attraction and preexisting skill-knockback calls retain their previous default behavior. No global gravity, AI pause, new platform or edge teleport was introduced.

After the fix the same right/left ground enemies remain x585/x15 with actual support. A wide-floor positive still moves x585 to601.2002. The actual aerial-diver definition still moves past the edge to605.4561, retaining real force without the ground guard. Source output includes all accepted event IDs, directions, HP and per-tick force/support state.

The old 273 assertions remain present. New actual enemy audio checks prove exactly one accepted hurt cue and no replay cue; the edge matrix adds real negative/positive cases. `final_edge_guard.log`: **297 assertions / 0 failures**, strict clean engine teardown. This is a local component follow-up in a shared dirty tree, not a replacement for parent final source-frozen whole-tree regression or physical/GPU acceptance.

## Final owner correction: preserve grapple and active-skill physical contracts

Full applicable regression found a real new production bug beyond the earlier297 component checks: all12 original moving-hook combinations failed because `damage_type=grapple` actual HP events entered the newly added ordinary.12s stun/135-force listener. This stopped the real patrol target and violated its original moving-hook contract. The independent single shadow_shuriken30Hz budget outlier had no accepted player damage, so it was not assigned the same cause.

Only three production files changed in this correction: EnemyActor branches on the actual accepted attack owner; PlayerProjectile carries its already-existing skill_attack boolean in the actual damage context; WeaponActionRuntime.hit carries its existing skill boolean likewise. Accepted grapple/skills keep shared hurt audio and actual Health-driven visuals, while original grapple/skill owners retain movement/stagger/force. Ordinary new hurt motion remains. No generic API, Callable-bound-argument inference, TTL extension or old assertion change was introduced.

Added real cases preserve all original297 assertions and extend the damage suite to **317/0**. Actual moving grapple AI ran28 ticks at90/sec and ended x322 exactly. Actual blade_bloom physical projectiles carry skill=true through the actual FrameDamagePolicy, use original.12s stagger (row13→21) and500 authored force; actual charged laser_cannon ray through WeaponActionRuntime.hit preserves original.12s stagger (row17→25) and0 force. Neither gets an additional ordinary.12s delay. Ordinary hurt/edge/audio297 checks still pass.

The original unmodified `python3 tools/run_action_budget_tests.py` then completed **7305 assertions / 0 failures**, strict exit0. Its twelve original hook cases pass across30/60/120Hz and both target/patrol directions. Logs/complete traces are retained independently in `action_budget_after_response_owner*`; original7305/13 trace is separately preserved. Root independently collected real input packet/age evidence for the unrelated budget outlier (including age>.1 original TTL); the unchanged budget later passing is not described as the hurt fix directly resolving that separate host timing event.

`response_owner_fix_report.json` provides honest dirty-tree source SHA attribution and actual component provenance. Root's later exact-N frozen Core/Foundry/export/movies must retain their own source bindings; these earlier local results are not retagged N. No additional engine/GPU runs or source edits were performed to write this final report/portable selection.
