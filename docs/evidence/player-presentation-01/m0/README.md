# PLAYER-PRESENTATION-01 · M0 checkpoint

2026-10-22; System Engineering; `feature/player-presentation-01`; worktree `/workspace/worklines/player-presentation-01`. Production merge: `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`; actual audited/tested HEAD: `0ee0e79197f40e898283440d4af2d956f91f1c64`. This checkpoint changes only this task's documentation and quality record. No new animation, continuous visual result, user acceptance or device acceptance is claimed. Recover the checkpoint commit from the branch history; the runtime bytes remain those of the audited HEAD.

Skills: [player-creator](../../../../.agents/skills/player-creator/SKILL.md), [animation-vfx](../../../../.agents/skills/animation-vfx/SKILL.md), [game-quality-gate](../../../../.agents/skills/game-quality-gate/SKILL.md). Read the current task contract, current_state/handoff latest sections, action design entry/coverage plan, controls, mechanics, ability and animation contracts. This is global player presentation, with no region creation or optimization; no new regional art gate or Bible direction is invented.

## Actual consumer inventory and event chain

| Consumer | Source anchor | Actual ownership / evidence |
| --- | --- | --- |
| Ordinary Plains maps 1/2 | `scripts/demo/demo_app.gd:203`, `:2272`, `:2291` | `start_plains` → ordinary factory → `UnderworldPlayer` named `PixelPlainsActor`; original baseline actually assembles both maps. |
| Home | `scripts/demo/home_scene.gd:34`, `:53`–`:60` | Real player.tscn plus one `UnderworldPlayer`; Courier and PlayerFeedback hidden; Adapter processing disabled. Source observed; Home runtime was not executed in M0. |
| Current shared Forest | `scripts/demo/demo_app.gd:2275`, `:2291` | Same shared-region pixel predicate creates/reuses the same Underworld body. Source observed; Forest runtime unverified here. |
| Legacy/nonpixel / ActionStudio | `scripts/art/player_visual_adapter.gd:16`, `assets/characters/courier/courier_visual.gd:57` | Adapter drives Courier's body/weapon states. Preserved; never substitute its test for the formal pixel body. |
| Authoritative weapon anchor | `scripts/combat/shoot_ability.gd:101`–`:133` | Real accepted shot obtains Courier muzzle, creates projectile, emits `shot_fired`; Courier remains present while hidden. |
| Actual body and visible weapon | `scripts/underworld_plains/underworld_player.gd:22`, `:109`, `:129`; `scripts/art_foundation/windchime_actor_visual.gd:10` | Three existing body resources drive generated frames. Ancestor subscribes accepted shot flash and refreshes hidden Courier muzzle each process. Visible weapon is drawn to that actual muzzle. |
| Applied hurt / terminal / return | `scripts/underworld_plains/underworld_player.gd:33`, `:58`; `scripts/art_foundation/pixel_plains_actor.gd:8`–`:37` | Applied negative health result selects existing DamageFeedbackDefinition hurt/flash; terminal/died interrupts, segment_returned creates bounded old-world echo. Reuse; no second generic hit system. |

Important correction retained: **disabled Adapter processing does not disconnect its signals**. Adapter `_on_shot_fired` still calls hidden Courier `shot_pose`/`set_state(recoil)`; hurt/death callbacks also execute. Courier's own process still advances recoil. Therefore the initial source hypothesis “no weapon recoil” was withdrawn before implementation. A real trace must distinguish visible-body absence from already-existing hidden-anchor recoil. Source SHA/size for the explicit closure is in [source-index.json](source-index.json).

The concrete gap to test is whether a hidden Courier left in a signal-selected recoil/hurt/death state, without Adapter's periodic restoration, causes a persistent weapon-attachment pose after the visible Underworld body recovers. Underworld `_select_state` has no recoil body layer; this alone is an inventory fact, not proof that a new layer improves the picture. Existing authored frames, accepted-shot path and DamageFeedbackDefinition must be reused first.

## Actual original-consumer baseline

All shell commands below run in this worktree after `source /workspace/worklines/player-presentation-01-env.sh`.

```sh
python3 tools/cloud_inputs.py --check underworld-formal --commit 0ee0e79197f40e898283440d4af2d956f91f1c64 --output build/player-presentation-01/m0-input-plan.json
python3 tools/harness.py --check underworld-formal --jobs 1 --release
```

Preflight exit 0, ready, missing inputs 0, materialization 0 bytes; [raw input receipt](input-plan.json). Harness exit 0, fresh, original check `underworld-formal`, inner 3.603s / harness 5.185s; Godot `4.7.2.stable.official.ed1daf0bf`, fixed 60, headless/Dummy audio. Original marker: `UNDERWORLD_FORMAL checks=96 failures=0 maps=2`. [Raw harness report](harness-report.json), [unmodified native output](underworld-formal.log), [unmodified original output inventory](formal_integration.json).

Frozen original-baseline conditions: actual `DemoApp.start_plains("underworld-formal-integrated")`, normal initial spawn, no move/shoot injection, eight physics frames per map, map 2 requested through the original test's director/load-stage path; actual formal camera and project viewport configuration. Headless baseline has **no rendered image or claimed pixel resolution evidence**. It checks normal pause/unpause, epochs and teardown, not continuous combat or new animation.

| Map | Derived Seed | Actual Manifest |
| --- | --- | --- |
| 1 | `underworld-formal-integrated` | `ac5a6654b8aab5ceb53451a767b9efaa665b3d0ec3a45e661ce976cbdb967d5f` |
| 2 | `underworld-formal-integrated/plains/map_2` | `fe31fdf3a71087e20f689e389e7d5ae23b2fe0150e95d9d3e7f4aebadbfaa269` |

Other checks, full docs/profile/Integration/Release, continuous animation, Home/Forest runtime, GUI, audio listening, user and physical device: **unverified**. Diagnostic path guesses `scripts/pixel_plains/pixel_plains_actor.gd` and `resources/quality` did not exist; corrected to actual `scripts/art_foundation/pixel_plains_actor.gd` and task quality directory. A source-search command returned exit 1 for no nested AGENTS; neither is a test pass or production blocker.

Additional record checks: the first `quality.py check` rejected malformed local criterion/creative-decision fields; [first raw result](record-validation-first.log) is preserved. Fields were corrected without changing acceptance states; [corrected raw result](record-validation-corrected.log) has zero structure errors and remains incomplete. `python3 tools/check_quality.py` actually exited 1 because this sparse tree lacks historical skill/asset evidence; [full failure output](global-check-quality-sparse-failure.log) is retained. No broad history hydration or full-profile retry was attempted. This is a real failed global check, not a pass or a content-completion claim.

## First representative sample and falsifiable target

M1 is a real accepted-input trace before production edits. Freeze `DemoApp.start_plains` with root Seed `underworld-formal-integrated`, map 1 normal spawn, actual run camera, viewport 1280×720, 60 physics/render FPS, same driver/source/input schedule for before/after. The exact successful input schedule and its SHA must be committed before the first comparison; this M0 checkpoint does not claim it has run. Target segment: move right → reverse left while aiming right → accepted single shot and recoil → accepted nonterminal hurt interrupt → natural recovery → terminal lifecycle. Damage lifecycle fixtures must be labelled if submitted to HealthState; they cannot be called natural combat.

Falsification: observe actual Underworld state/frame, hidden Courier state/arm/muzzle, accepted shot ID, health result, session/router epoch and Motor channels each frame. If the hidden anchor already restores continuously without residual error, reject the stale-anchor hypothesis and preserve it in the evidence. Never create a second recoil path just to satisfy the proposal. A fix must preserve projectile muzzle, feet baseline, body source pixels, Motor motion, resource accounting and accepted event counts under identical inputs. Death/return/epoch/pause must not replay stale recoil or hurt.

## Ownership, coordination and recovery

M0 write set is `docs/evidence/player-presentation-01/m0/*` plus `docs/quality/records/PLAYER-PRESENTATION-01.json`. Contract production write set remains `scripts/underworld_plains/underworld_player.gd`, `scripts/art/player_visual_adapter.gd`, `assets/characters/courier/courier_visual.gd`, their existing UID identities and task-specific new files. No central task/state/handoff/Harness/config/scene, Motor, input, physics, damage, resource or capability changes.

Proposed M1 new paths: `tests/player_presentation_01_trace.gd`, `tools/player_presentation_01_trace.py`, `scenes/dev/player_presentation_01.tscn`, `scripts/dev/player_presentation_01.gd` and task-specific evidence. No new Definition class is presumed necessary. Begin with the trace; only then select minimal implementation. The controller's existing accepted signals suffice; no new shared signal is requested.

Any Underworld script change affects style-v4's explicit character SHA and both regional creative bindings. Keep style-v4/body atlases/build metadata unchanged. Record old/new script SHA and exact visual/consumer effects; total controller must schedule independent review plus explicit versioned style rebind and Plains/Forest/Home revalidation. Pending rebind checks remain pending. Enemy feedback coordination: reuse current `health.changed` / `died` / DamageFeedbackDefinition; no generic feedback interface change requested.

Next command after recovering and sourcing the dedicated env: `git status --short`, then inspect `tests/underworld_plains/test_underworld_player_animation.gd` and implement the task-specific real-consumer trace. M0 has not registered a fake runner, created a PR, run full CI, merged main or published a Preview. The coordinator has explicitly authorized this workline to continue M1 after the recoverable M0 commit/push; M1 must produce a real short continuous Godot film, followed by the coordinated playable Preview.
