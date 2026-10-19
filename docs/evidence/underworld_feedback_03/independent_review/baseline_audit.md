# R3 independent initial audit

Baseline: `0fab13fcc446bf9abd3c6beaf21e0fc5b76bd9ad`. Reviewer `/root/r3_review`, read-only implementation role. No Godot/GPU/video executed at this stage.

The reports below are source-confirmed gaps or candidate causal paths. They are not runtime acceptance. User feedback was known before the audit; no blind-discovery claim.

## R3-IR-01 — direction_loss

Player projectile context hit_direction is not copied into DamageRequest and contact requests lack a direction.

Counterexample: Commit one real left and one real right hit. Assert response is opposite incoming direction and no second move_and_slide occurs.

## R3-IR-02 — hidden_feedback_audio

Formal Underworld hides PlayerFeedback without disabling its accepted Health audio subscriptions.

Counterexample: One accepted hit must generate exactly one hurt audio cue, no cue for denied duplicate/i-frame/stale epoch.

## R3-IR-03 — instant_environment_feedback

Environment Health change and SegmentRespawn occur in one batch before next render. A health-only local effect may render at the restored anchor or be cleared immediately.

Counterexample: Record actual hazard contact, exit at hazard, epoch invalidation, spawn entry/recovery, pause/reload transitions; no delayed duplicate HP or grants.

## R3-IR-04 — boss_attack_window

Body rejects every hit; bell damage additionally requires core_open and direction acceptance.

Counterexample: Real player swept projectile must deal damage during all active attack/telegraph/recovery modes; intro/dead/outside arena and stale shots must reject.

## R3-IR-05 — boss_contact_dimensions

Bellstrider contact emitter uses fixed half_size 25x27 rather than the authoritative encounter body bounds. Windkeeper clamps to 72x62.

Counterexample: Traverse left/right/top/bottom actual body and just-outside; moving body sweep, phase transition, death, pause, reload; compare accepted contact to true shape.

## R3-IR-06 — shortcut_parallel_path

Backside shortcut opens through W/interact proximity, outside ShotLatch path.

Counterexample: W/contact cannot open. A real current player projectile from valid side can; wrong side/enemy/stale/occluded hit cannot. Persistent opened ledger and real collision must survive reload.

## R3-IR-07 — claimed_chest_pose

Claimed chests retain closed PNG and only lower alpha to .35; reload installs same closed art.

Counterexample: Actual successful claim gives opaque open lid state; cancel/denied claim stays closed. Reload retains open pose without repeating reward.

## R3-IR-08 — home_vertical_interaction

Active NPC distance uses FLOOR_Y-18 for all entries and reserved proximity uses abs(x) only.

Counterexample: Different floors sharing x cannot open wrong NPC. Every original four function plus all eight reservations reachable with baseline legal jumps, no granted future abilities.

## R3-IR-09 — projectile_hit_vs_acceptance

Wall contacts, rejected receivers, and accepted HP changes are distinct; terrain occlusion must keep precedence when adding VFX.

Counterexample: Blocked/denied hits may show material impact but never accepted-health blood/sound/energy grant; all hostile projectile subclasses covered, pause/epoch disposal produces no fake explosion.

## R3-IR-10 — fall_under_ground_unproven

Connected region is generated_plains branch using global assembler bounds.grow(100); fixed y690 is not its consumer. Exact reported false fall source requires runtime geometry and source_id.

Counterexample: Legitimate lower floor/one-way/carrier/diagonal landing and leave-upper-room are safe; actual unsupported abyss still returns once. Record policy request source and world support, not camera viewport.

## R3-IR-11 — decoration_keepout

Adding decoration must respect dynamic platforms, hazard edges, gate shot lines, reward markers and legal landing space.

Counterexample: Same-seed before/after collision/resource/AI/RNG equality, actual camera samples both maps, no root-floating or foreground occlusion of body/projectile/sole landing.

# Freeze review requirements

Need fixed full commit, exact source guard, native original image paths and a continuous recording plus telemetry for accepted events. Review actual producer/test diffs against baseline and retained legacy fixtures. No source hash alone signs visual quality; no fixture placement signs ordinary route. All user/device/aesthetic/audio listening evidence remains separate.
