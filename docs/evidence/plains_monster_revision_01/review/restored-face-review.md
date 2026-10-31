# Plains restored-corpse facing · independent review

**Verdict: ACCEPT, limited to the saved-terminal facing reconciliation fix.** Reviewed clean fix commit `ad89bf4fb827d8e6f2f1a2d97abbcc5a50e791d7`. Production leaf `scripts/enemies/plains_revision_visual.gd` SHA256 `bfde3788b84321725e368356bdfe86289a071c29a889403c5b00ea0ec4d82a78`. Independent reviewer `/root/restored_face_review`; implementer `/root`. Applied repository gameplay-reviewer instructions to this bounded code review. I did not edit production/tests or run Godot.

## Confirmed original defect and untouched consumer

I read the actual original full05 artifact, not merely its completion marker: `build/verification/harness/20261029T213858.959138Z/artifacts/enemy-feedback-support/build/enemy_feedback_01/v8/support_runtime.json` and the original support log/report under `build/verification/harness/20261029T213858.959138Z/`. Full05 was frozen at bc9024ff, reached72 passing checks, then enemy-feedback-support failed145 assertions/2 failures. Its two late-saved-transform cases (original and Underworld) had x540/y380, terminal frame7, age0/starts0 and resting/settled/visible state as expected, but face+1 despite the recorded Motor brain facing−1. The two failures are precisely the combined next-physics saved-x/frame/facing assertion.

The real cause is the visual leaf's cached live `_face`: terminal `refresh()` returns before its direction update. Official saved health initializes before Stage writes the recorded Motor transform and brain facing; the inherited one-shot next-physics recapture saw the correct current transform but the stale live facing.

I byte-compared the original support test, integration wrapper, accepted-feedback state, parent remains and rig remains to bc9024ff: all are unchanged. No assertions, observation windows, support geometry, collision slop, timeouts, counters or failure thresholds were edited.

## Scope and counterpaths examined

Only `remains_view()` selects authoritative `actor.brain.direction` when `sample.restored_terminal` is true. It preserves `_face` for genuine accepted lethal handoff. In the existing sample state, initialization synchronizes restored_terminal from terminal health; accepted lethal APPLIED damage explicitly clears it before corpse capture. The sample connects its health observer before remains binds. Thus both initially dead installation and later official zero-health initialization take the saved-state path, while a live patrol mid-turn/accepted death continues to capture exactly the currently visible orientation. No new clock or mutation of Motor/brain/HP is introduced.

I traced the parent `_restore_static()` path: an explicit saved corpse-presentation face still overrides the captured fallback after `_capture()`, so recorded settled-corpse orientation is not replaced with the Motor direction. Contact validation, current-stage foot claim, weak support following/release, unsupported bounded fall, duplicate suppression and accepted/reward semantics remain unchanged. Pause/epoch guards still control when the pending recapture runs. Transient restored corpses retain their existing hidden terminal policy.

## Actual implementer run independently inspected

I independently read `build/verification/harness/20261029T221042.129826Z/artifacts/enemy-feedback-support/build/enemy_feedback_01/v8/support_runtime.json` plus its actual Harness result at `build/verification/harness/20261029T221042.129826Z/report.json`: fresh exit0,145 assertions/0 failures,14.959seconds. In both real rendering chains the late-saved-transform snapshot is now face−1 while position(540,380), frame7, age0, starts0 and all other support/rest flags retain the prior values. The unchanged145 assertions also cover actual Router projectile death, unsupported void, translated/released weak support, silent saved restore and object release. This is implementer execution inspected by me, not reviewer-run native evidence. The development run started before fix commit, so it is not a fresh full-profile run of clean `ad89bf4fb827d8e6f2f1a2d97abbcc5a50e791d7`.

## Media reuse and unresolved boundaries

The existing combat and same-screen videos remain attributed to original clean source7edda9f5; they must not be retagged as this fix commit. The changed conditional affects cold saved-terminal fallback only. Actual accepted deaths retain the identical cached-face branch; rig art, joints, shader/1wu sampling, live refresh, collision, animation timing and draw path are unchanged. Therefore continued *limited* use of those original videos for the already observed art/pixel/accepted-death review is technically justified, with the saved-facing fix disclosed separately. I did not watch new media, hear an audio track, inspect devices or grant new whole-monster aesthetic/G5 acceptance.

I subsequently read the clean-fix targeted Harness report `build/verification/harness/20261029T221136.871457Z/report.json`: commit ad89bf4fb827d8e6f2f1a2d97abbcc5a50e791d7, empty git_status, passed; corpse-save, corpse-snapshot and enemy-structure-native each fresh/exit0/passed. These are implementer runs inspected by me, separate from the earlier dirty-source145/0 support run. Final applicable163 is still pending and is not accepted in advance. Historical full05 failure remains a failure; targeted evidence does not sign the whole suite.
