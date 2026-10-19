# Independent input and grapple review

Reviewer: `/root/experience_audit`. Production files were read only. Source identity is the exact SHA256 snapshot in `reviewed_sources.json`, against baseline `6c61faadd511c48a267b975550da897e701fd09f`; this is an uncommitted implementation review, not a final release identity. Used the project's gameplay-reviewer and challenge-choreographer instructions. The reviewer authored only review reports and independent counterexample scripts/evidence in this directory.

## Decisions

**Scoped technical ACCEPT:** changed H arrival, near-vertical kick policy, explicit hold-ring behavior, and dual-aim input logic at the recorded source snapshot. This does not accept the forest's new route design, actual visual feedback, device controls, user handfeel, enjoyment or commercial quality. Those remain **UNVERIFIED** here.

The initial touch implementation was **REJECTED** on independently reproduced ownership loss. Its failure log remains unchanged. The subsequent fix has passed the same independent script without changing its assertion. This acceptance applies to the fixed TouchOverlay SHA `927a10b417d87ab935e6d4ad4317daba05ac4b8ec9126fa2a4e67d69294ff7db`.

## Executed independently

All commands used Godot 4.7.2 through the repository's tool and shared engine lock. Engine execution was bounded at 45 seconds, with a separate 45-second lock-acquisition bound; waiting did not consume the engine's execution bound. All below completed rather than being inferred from file existence.

1. `flock -w 45 build/verification/engine.lock timeout 45 bash tools/godot.sh --headless --path . --script res://tests/grapple_feel_runner.gd -- --output=res://docs/quality/reviews/FOREST-GRAPPLE-02/grapple_feel_independent01.json` — exit 0, **38 checks / 0 failures**, original stdout `grapple_feel_independent01.log`.
2. Same engine invocation with `--script res://docs/quality/reviews/FOREST-GRAPPLE-02/grapple_counterexamples.gd -- --output=res://docs/quality/reviews/FOREST-GRAPPLE-02/grapple_counterexamples01.json` — exit 0, **9 checks / 0 failures**, original stdout `grapple_counterexamples01.log`.
3. Same invocation with `--script res://docs/quality/reviews/FOREST-GRAPPLE-02/input_counterexample.gd` — initial exit 1, retained `input_counterexample01.log`; fixed-source exit 0, retained `input_counterexample02.log`. Exact same reader and assertion: a captured upward H aim must remain upward H aim when the older gun finger drags left. Initial observation was `grapple/(0,-1) → attack/(-1,0)`; fixed observation was `grapple/(0,-1) → grapple/(0,-1)`.

The independent resource counterexample spends an actual airborne shot through InputRouter and Controller before attaching: charges become 1, remain 1 on arrival and after 60 hold ticks, and `is_on_floor()` remains false. This strengthens the author's original hold test, which begins at the resource cap and could conceal an attempted refill. The other added cases reach the diagonal-down anchor with mirrored actual-body edge approaches on both sides.

## Evidence and source inspection

The author's complete input `build/grapple_aim_input05.log` records **119 / 0**, and the repeated shared actor suite `build/grapple_actor_actions02.log` records **2872 / 0**. These are author executions read by the reviewer, not independent executions. The earlier portable `input01` records and its initial failure were also inspected. The legacy actor-test diff changes the explicit old LB press contract to held aim followed by one release cast and preserves the primary-shot rejection; it does not merely delete the previous assertion. The actual AirFocus tests retain resource/budget/death/pause/global-world-and-projectile checks with `.15` replacing the explicitly superseded `.20` expectation.

The exact historical `after_move()` causal-control override was compared to `git show 6c61faad:.../traversal_ability.gd`; its method text is identical. Author execution `build/verification/grapple_feel_legacy_complete.log` records actual target-hit/pull and body-edge-clear PASS but arrival FAIL, with 3 checks / 1 failure. This isolates the previous collision termination policy; it is explicitly **not** a complete frozen historical engine/game build.

The updated pull retains real collision and range limits, accepts useful floor-slide approach, and terminates non-progressing obstruction. All body displacement continues through PlayerMotor; the inspected implementation introduces no direct player-position assignment, collision exception against terrain, range increase, body-size change or invincibility. The `.2` near-vertical horizontal-direction cone removes the sign ambiguity while the actual ±70-offset tests retain deliberate side kicks; this does not prove all boundary angles feel smooth to a human.

Explicit holding uses the real reached offset. The source and fresh 38-case trace cover fixed hold, jump exit, accepted recoil exit, rejected shot staying held, next-anchor H/guide, target removal, ability removal, death, input cancellation, small ring movement and obstructed movement detachment. The ShapeCast exclusion is only the current held Area2D during its guide or the exact departed hold ring during cast/fly; terrain ray obstruction remains intact. This is a bounded way to avoid self-recapture, not permission to ignore arbitrary targets or walls. Actual fixed-ring arrival restores H eligibility; the independent depleted-charge test demonstrates that this is distinct from landing or shot replenishment.

PC right/E sources aggregate until their last release. Holding captures H aim, while cancel/device changes disarm and suppress stale release. Controller LB remembers its meaningful direction through centering, releases once, and requires neutral before primary aiming can arm again. Touch now keeps H capture priority during either old or fresh gun-finger movement. Old suppressed gun gestures remain suppressed after H release; a fresh gun capture made during H may regain aim after H release. Both release orders are covered by the expanded 119-check author suite and directly inspected source.

## Limits and remaining admission

No normal-speed gameplay pixels, animations, audio, physical controller or phone have been viewed for this review. The visible ring mark and reused hold pose have been inspected only in source. The real-world feel of hold-to-aim/release-to-cast, the vertical deadzone boundary, input loading under long chains, the actual target camera visibility, and fairness under varied human errors remain unverified. Tests do not establish that these actions are fun. Final source changes invalidate only the affected part of this scoped acceptance and require appropriate re-review.

The forest golden's `spiral04/capture.json` was read separately: it binds three actual H contacts and one accepted recoil before the 560px-high receiver, followed by real return/recovery. That supports its specific vertical-transfer hypothesis. It does not establish formal-map density, absence of strong no-H shortcuts, readable camera motion, or route diversity. Those need formal adjacent-geometry trajectories and action ablations before map-wide acceptance.
