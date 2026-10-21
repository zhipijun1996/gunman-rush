# Independent fixed-adapter review

Verdict: **PASS for the offline acceptance repair only.** Tool SHA256 `5e3f3c20399d2be00423b8e524ab6d66a8cbc92f92d7cf4666d551c0fa779b2c`. All six frozen sources matched the owner's `freeze-v2.json` before and after the independent checks. No engine ran and no production/test/tool source was changed.

- Independently replayed all nine original false-accept controls against the fixed actual functions: all rejected. The original actual F05 native report remained accepted.
- Replayed the real synthetic 12-frame black AVI with 1ms all-zero PCM: rejected for incomplete PCM duration. This is an explicit synthetic media fixture, not a native gameplay report.
- Independently validated both historical actual native route reports: F05 3129 samples / 32 legs, F08 3551 samples / 31 legs. No movie counters were added to these reports.
- Twelve independent timeline controls all gave their expected outcomes. These cover narrowly valid process/modal and real-identity-bound preincrement shapes, unknown physical identity, two-tick mismatch, wrong draw/process count, duplicate identity, unknown process reason, next-physics-boundary violation, and misplaced modal/pointer rows. All raw inputs remained unchanged.
- The existing narrow offline suite passed all eight tests in 0.705 seconds, including actual ffmpeg media rejection and decoded PNG static-frame rejection.

Static inspection confirms that the four new Bible observer/runner edits export original observations and stamp actual Engine counters. `_mouse` delegates to the same original input action and records it only during movie capture; no new gameplay action, resource injection, Motor call, route or native-budget change was introduced. The original source/import/error guards and 90-second import / 240-second native budgets remain.

The previous validator's preincrement problem is handled by matching each physics observation to a unique real `Engine.get_physics_frames()` sample, enforcing exact draw/process identity, allowing only its declared tick or the immediately preceding auxiliary tick, and normalizing a detached validation view. Raw trace ticks are preserved. Process observations retain finite, explicitly allowed semantics and actual half-open draw/process windows; modal/pointer rows also carry their actual tick and are checked individually. Engine global physics counters may advance while SceneTree nodes are paused, so process counters are not falsely required to equal the last Motor observation's engine identity.

This result does **not** certify native movie scheduling, F05/F08 real AV success, continuous visual quality, physical audio playback, or the forest's visual style. Historical no-movie reports and synthetic counter fixtures cannot establish those claims. The next step is the parent's exclusive-lease, fresh source-bound native AV run at the original budget; any real counter mismatch or native failure must retain raw artifacts for diagnosis.

Evidence: `review.json`, `probe-report.json`, `independent-final-check.py`, `independent-replay.py`, and the exact reviewed source snapshot `adapter-reviewed.py.source.txt` in this directory. The original failed-adapter evidence remains unchanged in `../av-adapter-independent-review-first/`.
