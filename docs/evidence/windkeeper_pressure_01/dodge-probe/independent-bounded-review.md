# Windkeeper bounded actual-App dodge review

Reviewer: `/root/windkeeper_evasion_probe`. This agent authored the diagnostic script and now reads its coordinator-run receipts; it did not implement or modify the production Boss or legal-input pilot, and did not run Godot. This is independent of those implementations, not an independent rerun of the diagnostic and not whole-encounter approval.

## Actual evidence inspected

- Script `/tmp/windkeeper_dodge_probe.gd`, SHA256 `56a5b041912602b4eebc99e3275984fdfd8340bc94a9eb4339538815b40ef262`.
- Actual root-run report `build/windkeeper_pressure_01/dodge-probe-01.json`, SHA256 `185185f47e79ef095c53e7edae1c3fc9c62fc81aeaa04b18d5eda624875376a4`.
- Actual log `build/windkeeper_pressure_01/dodge-probe-01.log`, SHA256 `0810ba64d1b847da33dc964670c08da365daa5532643ff80d88ccda553e11fd8`.
- Log terminal: `WINDKEEPER DODGE PROBE: 12 trials; setup_failures=0`. Report: 192 scaffold assertions, zero setup failures, **5 safe and 7 unsafe trials**. The seven unsafe input strategies remain actual HP-loss observations, not hidden or converted to passing evasion results.
- Reviewer HEAD at read: `b8499fc7dbdc331bfcad4d00ff850de9f85334b4`, clean. Do not label that as the probe execution commit: the receipt does not embed one. Current production Encounter SHA256 `cfb76b613f4b6208861f57094ddea8ea2072d3fb0c289cd078ae168991eaf3ef`, Rig `37a9f92078742dd5d0845ecf43aef1e9addbed031dc0be52461f6dd5445e475f`; current pilot inspected SHA256 `4a58c758dc637b7c47205036e747d232a9a379869c4a02f5952135c79a07a2dc`.

Each trial creates an actual fresh formal map2 App at `windkeeper-pressure-formal-01`; the actual module in this seed is translated relative to the continuous-film arena. Right platform edge player centre is `(7008,-640)`, actual phase2 single-attack group and Boss initial placement are disclosed pretrial fixtures. Original Player has 5HP, real support and no initial body overlap in every trial. After warning begins the script only submits ordinary Router inputs; no further phase/position/HP/resource/clock/AI/collider mutation. These are controlled local dodge tests, not natural campaign or three-stage battle.

## Observed outcomes

| Trial | Actual initial gap | Input relative to warning start | HP | Result |
|---|---:|---|---|---|
| sweep-still | 128 | Stand | 5→4 | Actual high leaf hit |
| sweep-jump0 | 128 | Vertical held jump at frame0 | 5→4 | Actual high leaf hit |
| sweep-jump12 | 128 | Vertical held jump at frame12 | 5→4 | Actual high leaf hit |
| sweep-jump24 | 128 | Vertical held jump at frame24 | 5→4 | Actual high leaf hit |
| sweep-cross0-recoil18 | 128 | Left+jump frame0, down-right shot frame18 | 5→5 | Safe through108frames; still airborne at end |
| sweep-cross12-recoil30 | 128 | Left+jump frame12, down-right shot frame30 | 5→5 | Safe through108frames; actual grounded at end |
| lunge-still | 240 | Stand | 5→3 | Two actual body hits |
| lunge-cross0 | 240 | Left+jump frame0, no shot | 5→4 | Actual body hit |
| lunge-cross6 | 240 | Left+jump frame6, no shot | 5→4 | Actual body hit |
| lunge-cross12-recoil30 | 240 | Left+jump frame12, down-right shot frame30 | 5→5 | Safe through108frames; actual grounded at end |
| lunge-cross0-recoil18 | 240 | Left+jump frame0, down-right shot frame18 | 5→5 | Safe through108frames; still airborne at end |
| lunge-close180-cross0 | 180 | Left+jump frame0, down-right shot frame18 | 5→5 | Safe through108frames; still airborne at end |

All held jumps use29 input frames. All tested escape shots request **`Vector2(.65,1).normalized()`**, actual observed direction `(0.544988,0.838444)`. Leftward input continues from jump start through the observed interval; it is not stopped by a forward contact forecast. Shots are actual primary-weapon events and real recoil, not fabricated damage or an added movement capability.

Observed warning clocks and executions are exact across corresponding cases: sweep warning `.72`, actual `sweep` at traceframe44, `recover` at70; lunge warning `.60`, actual `lunge` at36, `recover` at69. Router shot submitted frame30 becomes actual shot at physics offset31 (and18→19 in early cases).

The shared preferred late-input trajectory (sweep gap128 and lunge gap240) stays still for12frames, submits left+jump at12, submits shot30, and has:

- frame30 before accepted shot: player `(6929.959,-785.5793)`, normal velocity `(-260,-180.6667)`.
- actual shot at31, direction `(0.544988,0.838444)`, airborne.
- peak at39: player `(6846.033,-914.6996)`, 274.70wu above initial root; every recorded body-contact query is false.
- frame90: player `(6625.025,-640.0748)`, grounded on the actual neighbouring platform.
- frame107: player `(6551.355,-640.0748)`, still grounded, HP5.

The no-shot lunge trajectory disproves the earlier static suggestion that a basic jump alone would necessarily suffice: jump0 peaks at22 but descends to `(6834.623,-669.1015)` at40 and receives real body damage. Keep that failed observation; the real upward recoil is material to the proven route.

## Minimal producer mapping derived from these cases

For the **same observed phase2, supported right-edge single-attack setup**:

1. High sweep at gap128: at warning age `.20s` (remaining about `.52s`), arm a **toward-Boss** crossing, submit left+jump and retain that movement. At18 input frames after jump submission request down-right `(.65,1).normalized()` once. This is the actually tested late route that also reaches a real grounded landing. The early route at warning age0 is also locally safe, but did not demonstrate grounded landing by108frames.
2. Lunge at gap240: the same warning age `.20s` (remaining about `.40s`), continuous left+jump and shot18frames later is actually safe and lands. At gap180, the tested safe route starts at warning age0; no trial establishes that waiting `.20s` at180 is equally safe.
3. Mirror the direction algebraically only as a **candidate**: `toward=sign(Boss.x-player.x)`, shot `Vector2(-toward*.65,1).normalized()`. Only right-edge/leftward travel was run; a mirrored left-edge trial remains unverified.
4. Preserve the actual landing corridor and reevaluate after landing. Do not infer that the full108frame leftward hold is optimal for the next combo member; the late tested route ends near the neighbouring slab's left edge. This probe does not test two recovery shots or continued gust/sweep combinations from that landing.

## Current pilot is not the tested recipe

The inspected current producer has several material differences:

- Raised lunge `.40` remaining corresponds to the tested gap240 `.20s` onset, but it allows gaps up to300. Neither300 nor all intermediate gaps were tested. Gap180 was only proved with immediate jump.
- General corner crossing uses `.85` diagonal and lunge crossing `.55`, while **every successful probe uses `.65`**. They cannot be reported as the same validated recipe: `.55` has less horizontal/more vertical recoil; `.85` more horizontal/less vertical recoil. Landing placement is part of the observation and must be rerun for a different diagonal.
- Current crossing can set axis0 when `_cross_motion_safe` predicts overlap. The successful probe kept continuous left input. The probe does not validate the forecast-gated trajectory.
- Current air-frame counter begins on the first observed airborne frame, then generally fires at `air_ticks>=18`; the probe fires at18 frames after the jump submission and observes the actual shot one tick later. Use the submitted-jump frame for an exact mapping, or record and verify the actual new offset rather than call them identical.
- Current high-sweep branch retreats away and uses a late vertical jump plus **straight-down shot12 airframes later**. General proactive crossing only arms at gaps180–300, so it does not cover the tested gap128. That current high-sweep branch is materially different from both safe sweep trials.

**Scoped verdict:** ACCEPT only that these two controlled attacks have at least one real reachable jump/recoil escape with the current original physics/damage and that the five safe receipts prove their stated intervals. No need to reduce Boss damage/speed is established by these cases. Current pilot equivalence, mirrored/other-gap cases, combo followups, phase3, two/third-shot windows, normal-speed visual/audio quality and a complete natural battle remain UNVERIFIED.

## Ground variant actual receipt — appended after coordinator run

Actually read `dodge-probe-ground-01.json`: **192 scaffold assertions, zero setup failures, 3 safe lunge trials and 9 unsafe trials**. All six low-sweep strategies on actual ground failed; neither jump alone nor the two crossing/recoil recipes may be described as a proven ground low-sweep dodge.

Ground SHA256 values:

- `/tmp/windkeeper_dodge_probe_ground.gd`: `b991bc4acefad2e690e9e50b07e99c31bd8e857d1ddd15de59f58e4b68cfd03d`.
- Report: `b011729d4de57a813ece9dd08587625711c9082795e7150eccd41d50c908374a`.
- Log: `4f1ba11a9098c56fa95e86cb7b1a3892e33dcbdc3797c6cd0fc7710d4981c6b6`.

The three safe lunge recipes exactly match the supported variant: gap240/jump12/shot30, gap240/jump0/shot18, and gap180/jump0/shot18, always continuous left and `.65` diagonal. All begin at actual ground root `(7008,-510)` and HP5. The gap240 late recipe actually finishes at `(6551.356,-640.0748)` **grounded on the raised neighbouring platform**, despite starting130wu lower on the ground. Early recipes remain airborne at108; don't upgrade them to a settled landing result. Gap280/300 are not covered by this report and are reserved for the separate followup probe.

### Actual first three injuries in headless-assault-02

Read the full trace and input events; these are not all covered by the supported high-sweep fixture:

- Frame1804/group8/phase1 is a **ground** lunge hit (player y699.925). At warning1741 player x5977.20/Boss6248 gap270.80; normal ground retreat logic flips around the arena200wu-room threshold and then submits no jump, leaving player x5997.70 when the lunge arrives. This is not failure of the supported escape recipe, because it was never armed.
- Frame2285/group10/phase2 is also a **ground** lunge. It starts the old ground crossing at2264 with gap190.79 and warningremaining.25, then sends `.55` diagonal shot at2283 (actual shot2284), gets body hit2285. That delayed `.25`-remaining/.55 route differs materially from the actual ground-positive immediate180 or `.40`-remaining240/.65 routes.
- Frame2551/group10/phase2 is a **low sweep while player is on a raised platform**. `sweep_high=false` was frozen when the group began with player on ground. By2506–2507, player is grounded at x6707.99/y569.924; Boss6581.60/653. The producer's supported-escape eligibility requires `sweep_high=true`, so it never arms. Player remains still during the entire warning and the actual low leaf hits on its first execution tick. The new ground-low report does not cover this mixed state: it starts player on the ground, not on the platform. Followup cases explicitly test this separate state.

### Actual phase3 environment hit is a walk-off after a real landing

The trace does **not** show an unavoidable bridge-removal failure or a missing real platform. At4116 the pilot requests a new jump from middle platform x6281 while heading left; by4120 its ordinary withdrawal reverses right. It lands at4160 x6441.59/y569.925, `grounded=true`, on the middle platform's right lip (slab ends6430; centre overhang11.59 still leaves actual foot overlap). It then continues right and walks off into the gap; frame4177 y680.425, frame4178 real ENV return/HP debit.

The producer resets `jump_rearm_until=frame+2` on landing. That lip provides only one supported tick while moving260wu/s. The previous hold ended4145, already15 released frames before the landing, so an unconditional two-tick rearm delay is not needed to establish a new input edge in this specific trace. A legitimate producer repair can permit immediate landing jump when input was already released, or keep a supported landing goal and stop before the lip. This is a candidate normal-input repair, not permission to teleport, refill, add support or suppress damage. It has not been executed in this review.
