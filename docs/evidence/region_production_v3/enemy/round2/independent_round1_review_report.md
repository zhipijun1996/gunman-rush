# V3-ENEMY-01 round 1 independent review — REJECT

Actual reviewer `/root/v3_independent_engineering`; actual implementer metadata `/root/v3_enemy_ecology`. Bound request hash `e7bed1e0274711e3a419675475ec73673ad615571be0f0a490940d1e678cff14`, attempt1. Request/source/skill hashes verified, current fourteen gameplay/art/producer files match `g1_report.source_before=source_after`; exact values are in `counterexample_results.json`. Source remained unchanged by this read-only review. No Godot/ffmpeg/native suite was run by the reviewer.

## Required correction V3-ENEMY-REVIEW-001 — essential evidence can disappear

**Location:** `tools/run_root_bell_tests.py::validate_capture`, lines45–85, especially the interruption and restored-pulse checks. **Severity:** high acceptance-consumer defect; not a claim that current original runtime facts are false.

The design explicitly requires refusal of erased warning frames and lifecycle evidence. I imported and ran the actual Python consumer on the original native165-assertion capture. The original passes and its original five event-erasure negatives all reject. The following independently mutated original captures still pass:

1. Remove entire `pause_actor_epoch`, `inactive_target`, `actual_stage_capture_and_ledger_roundtrip`, `duplicate_hit_does_not_interrupt` cases. The validator never requires these case IDs.
2. Delete every telegraph frame from `real_projectile_interrupt`. The validator only counts shot/damage/interrupt events and inspects final enemyHP2, so no observed warning remains to establish interruption of that warning.
3. Empty both frames and events in `restored_pending_pulse_is_cancelled`. The no-damage/no-pulse predicate is vacuously true with no observation at all.

**Minimal repair:** require each declared essential case exactly once and nonempty coherent native frame traces, require observed warning/committed-HP/recovery causality, and require restored recovery debt/serial/time/HP evidence rather than only absence of bad events. Preserve the original165 assertions/five negatives and these original failed validator counterexamples. Add new pure-Python negatives to the invoked validation path. This can be repaired in the observer/validator without changing gameplay or admission.

## Required correction V3-ENEMY-REVIEW-002 — width/direction coverage collapses to count

**Location:** same function, lines71–83. **Severity:** medium acceptance-consumer defect. Replace all six calibrated cases with six copies of the actual400px/+1 trace, changing only IDs. `len(calibrated)==6` and each local contact-envelope predicate pass, so the consumer still accepts the declared two-direction400/440/560 matrix.

**Minimal repair:** require exact unique Cartesian coverage `{400,440,560} x {-1,+1}`, unique case IDs and coherent actual support/start/takeoff/finish travel for each direction. Do not infer six independent runs from array length. The authentic original capture does contain all six directions; this finding concerns refusal of missing coverage.

Full standalone reproduction `evidence_counterexamples.py`, JSON results, and all mutated original captures are retained beside this report. These are actual Python acceptance-consumer executions, not simulated model/native-content runs. Source/scope mutation was also tried and accepted by `validate_capture`; because that API currently does not accept or validate the external source receipt, this is recorded as an interface boundary rather than a separate proven bypass of the whole native CLI. The actual original receipt/source/log/capture chain was independently verified. A reusable full-evidence validator should keep this source binding explicit.

## Facts independently checked and scope retained

All portable indexed artifact byte counts/SHA256 values match. Original `g1_report` capture/log hashes match and runtime log has `ROOT BELL:165 assertions,0 failures` with actual spacing in the original log. All fourteen original movie source files in ZIP hash-match their source manifest. The old wrapper is explicitly labelled SHA-verified inverse-patch reconstruction; it is not claimed to have survived unchanged. The current unique-output observer bridge is separate. No fresh movie claim is made for the changed wrapper.

Source audit: new actor factory binds RootBellBehavior and independent presentation; HealthState.changed requires APPLIED negative actualHP delta while telegraphing, rather than Damageable.damaged or a shot request. Pulse damage uses FrameDamagePolicy with stable serial-based eventIDs. EnemyActor death cancels/stops collision and DemoApp disables contact from terminalHP. RootBellBehavior checks active/lifetime and actor epoch; first restored targeted warning/attack is cancelled with inherited recovery debt/serial. Existing PlainsRegionStage/DemoApp save fields are reused. I did not find a definite new gameplay-source violation in these inspected paths. Source inspection and supplied authentic fixture traces do not establish a complete formal DemoApp reload.

PRODUCTION_ADMITTED remains false; actual generated20 manifests have no admitted root enemy and explicit candidate placement preserves budget. Unique-landing/ferry/thorn/lowarch/merchant/Boss and broad optional-lane guard policies are present. Six native width samples are independent fixture traversals, not continuous out/return or formal region success rates;560 threshold and1/20 candidate result remain. Formal new-enemy encounter G3, normal audiovisual admission G2, listening judgment, user/device/performance G5, complete regions and promotion remain unverified.

**Irrecoverable history stays explicit:** two early failed full-frame captures were overwritten by the original fixed-output producer. No original carrier survives. Their logs survive; neither this review nor source reconstruction recovers those frames or converts them to passed historical evidence. Current unique-output protection is an improvement, not a reversal of that loss.

G0 design is a substantive technical candidate; G0/G1 stage acceptance is rejected for the two evidence-consumer defects pending bounded repair/review. Parent-reported core5676/0 was not rerun by this reviewer. No continuous movie was played or audio heard by this reviewer, and no visual/audio/player/device approval is implied.
