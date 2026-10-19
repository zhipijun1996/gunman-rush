# FOREST-GRAPPLE-02 independent neighboring geometry / encounter audit 01

Reviewer: `/root/forest_neighbor_audit`, independent of production/driver/reader authors. Read-only source and original actual Motor captures; no production modification, no engine run and no pixels/movie/audio observed. Scope is v12 neighboring collision/encounter integration and the reported formal09 contact-token discrepancy. Overall **REVISE**, not a fun, visual, device, complete-region or release acceptance.

## Observed identities

- `build/forest_grapple02/formal08/00-map1-fast/capture.json` SHA256 `fb556c36cec960b318e5be695f6bf3d5666f388981e96916a7ed08f2fa309bed`.
- `build/forest_grapple02/formal09/00-map1-fast/capture.json` SHA256 `a65b7e9c3a3c7c5313548e9d14a30a1238a9874d46fe32f47e20ee193e2c5e62`.
- Reviewed live producer `scripts/generation/forest_vertical_expedition.gd` SHA256 `623199919dc4b1c0f75d5832de37596c23de401a0b00fde78580d687c57c6558` (dirty working source, parent HEAD `6c61faadd511c48a267b975550da897e701fd09f`; hashes, not HEAD alone, bind this review).

## N01 — forced receiver contact is stationary contact, not dash

Actual formal09 leg5 damage tick353 has source `thorn_mouth_bark_keeper_contact`, player center `[-1401.926,1213.321]`, enemy center `[-1385.400,1244]`, enemy state **telegraph**, state_time `.116667`. Its attack goal is `[-1405,1244]`; it has not entered attack. The player lands on the thorn-mouth/middle-fork shared receiver at tick360. Thus the authored `.9s` dash telegraph cannot make that early receiving collision avoidable: the body's contact hazard already occupies the trajectory. Relocating an enemy merely across the same narrow receiver did not solve integration.

Minimal repair: retain this monster on a separately visible flank bough outside the entire forced H→R receiving corridor, with its patrol/body bounds supported there and a meaningful optional encounter. Do not disable its contact damage, shorten its warning or remove the monster just to pass. Re-run the actual formal route and inspect approach/late phase. Author has been sent this causal distinction directly.

## N02 — the H-contact assertion has a genuine alternative restoration cause

The actual arch leg9 emits R serial5 at553, projectile session2/packet5/owner157454174437, then Hcast562 with token used=true. At571, actual projectile Policy damage reduces `middle_gleam` health2→1, its first-hit map and combat packet appear, and20 energy is credited; pending airborne round1 is consumed next tick572. Contact583 and kick590 legitimately have used=false. Independent invocation of the existing `actual_projectile_energy_credits` on raw tick571 returns that one exact credit and **no errors**.

The existing per-tick resource/token ledger already models this real cause; the unconditional contact-used=true condition is narrower than production mechanics. A valid correction can require a verified airborne projectile credit **after this actual H cast and no later than its contact**, while preserving all six H states, mapped actual target, genuine Router origin, range, stop/body, duration, token ledger, and shot/energy/queued-grant ledger. A reported credit alone, forged packet, wrong session/epoch, missing actual enemy HP delta, a ground-fired shot, or a credit before this cast must not waive the condition. Do not turn the assertion into a blanket false-or-true check. This is a strictly scoped causal correction, not permission to hide the unrelated leg5 damage failure.

## N03 — optional old branch can bury new upper ring

Static actual producer data: optional `far_reward_branch=[-610,268,290,24]`; original upper_spiral final ring is world`[-345,286]`, inside that platform. This is not a renderer issue: the ring center overlaps an actual support/collision shape in affected Seeds. Formal09 does not include this branch and cannot validate the affected variant.

Author's proposed instance shift local`[140,-640]` gives world`[-295,316]`,25px to the right of the branch end and24px below its underside. From formal09 last-cast origin`[-423.194,470.029]` the center range is about200.4px, within231. This is a feasible **candidate**, not actual movement proof. Need real affected-Seed pull/contact/kick/body trace, particularly changed sidekick direction and underside/corner clearance. The strict reader must derive any regional instance change from actual producer source, not trust captured self-report geometry. Other current formal09 v12 ring centers had no platform proximity less than22px in a full manifest sweep; that result does not cover other Seeds.

## N04 — recovery floor may supply a three-phrase internal bypass (unproven candidate)

Actual formal09 geometry: root_spiral crown top1340; thorn-mouth recovery `[-2005,1420,1190,40]` extends under future middle_fork crown `[-1090,1214,320,24]` (one-way). From the crown after first root shaft, a player may drop onto this catch, walk right to the future receiver's x interval, then jump plus upward recoil to cross the206px vertical gap. This could skip lower_fork RH, thorn-mouth HR and middle_fork RH. A full-map no-H attempt stopped by the first560px shaft does not refute this internal bypass.

This review has not performed that actual Motor route, so it is a concrete geometry/physics candidate rather than a certified exploitable route. Sent author a bounded real-input probe request using the normal first-root prefix, genuine drop, walk, jump and recoil (no teleport/resources). If it succeeds, shorten/reshape this catch away from future receiver footprint while retaining a readable broad retry bank and same-mouth return, then test error recovery as well as intended passage. If it fails, retain the actual trajectory and collision reason; do not delete a floor solely on this static suspicion.

## Required bounded follow-up

N01 current formal09 remains actual failing encounter admission. N02 raw causal diagnosis verified; implementation and forged-credit negatives still need review. N03 affected variant real-body proof missing. N04 actual internal bypass attempt missing. No claim about enjoyable pacing or commercial quality is made from these traces.
