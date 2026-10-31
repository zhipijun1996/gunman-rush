# BELLSTRIDER-REWORK-01 · articulated body / animation card

Implemented candidate, pending root's current-source Godot/GPU capture and independent motion review. This card does not sign user aesthetics, device performance, or complete enemy acceptance.

## Inputs and ownership

- Selected region: `windchime_plains_v2`, version 2.0, full Bible SHA `02c9dd3299d12c91a426cf40b2a5885e526b51f467b955539b4b5ff99e1aca35`.
- Current shared style: registry's style 22, SHA `4749a82126bbd84a1a826b2d1fb6406a1267050bd2624f5ed05911b238889188`: existing Underworld family, nearest filtering, fine world raster, restrained brass/moss, warm focal bell.
- Actual production consumer: `BellstriderPresentation._draw()`, for every former Underworld/pixel/painted style branch. No old complete-body mesh, central core label/halo, or separate weakpoint clock remains in drawing.
- `BellstriderRigPose.sample(data)` is pure. Encounter supplies accepted combat/impact/death clocks and actual signed displacement. Encounter and Presentation both consume its exact `bell_transform`; Presentation writes no gameplay geometry, clock, health, direction, or movement.
- Optional `transition_from` stores only previous accepted geometry/scalars, captured and serialized by Encounter. It never recursively stores another pose input dictionary. Live entry blend lasts 0.16 seconds. Accepted ring-strike clapper contact bypasses that scalar blend.

## Source preservation / actual regions

No image generation or PNG editing occurred. Both source images were opened before implementation. Existing source and license history remain in their original project records; this work makes no new license claim.

| Existing image | Dimensions | SHA256 | Actual reuse |
| --- | --- | --- | --- |
| `assets/underworld_plains/actors/bellstrider.png` | 128×114 | `8202472e8b2d829d1be88b6019e0a72475421bae4eae0d6e82b54289696d8af5` | canopy `(24,3,80,28)`; left moss `(25,34,13,34)`; right moss `(84,39,12,28)`; left plate `(42,70,11,24)`; right plate `(77,70,11,24)`; circular wheel UVs centered `(22,91)` / `(105,91)`, radius21 |
| `assets/underworld_plains/actors/bell.png` | 28×48 | `94162f8e2f0e112659885356908e114bec6bd11f6d5a31b7691fd53883e85ad2` | upper bell patina `(1,13,26,32)`; launcher ammunition `(0,12,28,32)` |

The old image's painted central bell/crest are excluded from the reused body regions. New shaded plates, braces, hinges, suspension, gears and bell shell are actual draw geometry, with the source patina/wheels/canopy retained. No new image is masquerading as generated art. Whole-source PNGs are never rigidly bobbed/scaled as the final body.

## Identity and geometry

Motor-local support is approximately y65. Neutral wheels are x±49, y44, radius21; hull width140, roof around y−5, belly around y43. Chassis uses muted old brass, dark brown/gray tyres and sparse moss. The upper bell is the warmest focal material; other highlights and phase seams remain small.

Neutral bell center is approximately `(−7,−84)`, with a 30×36 shared weak rectangle. Shell, lip, clapper, local hit twist/flash, incoming attachment, and detached death geometry use the same bell transform. The cage is open beneath and beside the bell. Ordinary low armour occupies the hull; the mast drawing does not add shot-blocking physics.

Facing is applied once inside RigPose's motor-local transforms. Wheel rotation is actual signed `travel / 21`; reflected wheel-local angles compensate for facing, so changing style or facing does not create another clock or artificial wheel spin. Fine detail is drawn with nearest textures and non-antialiased geometry; no 2wu proxy character body is selected by a style branch.

## Actions and bridges

| Action | Actual body / mechanical response | Clock and transition |
| --- | --- | --- |
| idle / observe | low-amplitude sprung chassis load, slight mast/bell lag, slow visible gears; wheels stay still | `fight_age`; wheels exclusively `travel` |
| approach | suspension response and small ground motes follow accepted movement | signed `travel`, actual speed |
| single charge warning | compressed suspension, loaded forward chassis, mast counterlean, upper bell backswing | actual normalized warning progress |
| chosen return-charge warning | larger backswing, separate two-stage suspension ratchet and panel opening before the first charge | immutable `combo` selection; same warning clock |
| charge | released suspension, forward load, lagging upper bell, movement-driven wheels and sparse ground wake | actual state age / displacement; 0.23s force release |
| return brake / turn / rearm | chassis brakes, mast and bell overshoot; distinct remaining-combo posture; entry captured before facing changes | actual combo state ages; bounded geometry bridge |
| ring warning | wheel load braces, side panels support, bell winds open | actual warning progress |
| each actual ring | visible clapper contact on accepted ring-strike age reset; shell follow-through and small frame vibration occur after contact | `ring_strike_age`; each actual wave resets this clock |
| lob aim / lock / release | independent cradle raises and recoils; its small ammunition bell leaves; primary upper bell stays suspended and vulnerable | actual lob state age; no Presentation targeting decisions |
| true recovery | chassis settles down, mast leans forward, bell oscillation decays; final part of recovery unloads suspension | actual recovery age / progress, exact previous entry geometry |
| phase two | limited hinged plate opening and restrained warm vent seams | actual phase/state age; upper bell remains exposed |
| accepted bell hit | local warm flash, twist and three small chips; actual current attack phase continues | `bell_hit_age`; no action clock reset |
| armour hit | contacted side plate vibrates, precise motor-local impact sparks, very small chassis transmission | `armour_hit_age` plus accepted armour contact point; no HP writes |

The shared `EnemyHitTemplate` and `BossMotionPresentation` accepted-event/lifecycle bindings remain. Their former whole-body deformation is not used by rendering, collision, or bell anchors. Presentation's former GameAudio callbacks were removed. Its actual `BellstriderAudio` child binds `encounter` with the service itself as the default audio origin; accepted encounter events own battle cues and service disposal owns cancellation. Existing BossArrival remains a read-only intro consumer.

The shared HUD has Bell-only branches: accepted armour feedback directs aim to the upper bell, accepted weak hits say `BELL HIT`, and all live combat phases display upper-bell vulnerability rather than closed-armour/central-core timing. Bell has no central aim helper and its protection shield reads actual `accepts_combat_damage()`. Other boss HUD branches retain their original behavior. Read-only formal-consumer audit found no remaining call to either legacy `draw_bellstrider` helper; those shared helper definitions were not edited.

## Death and persistence boundary

Actual `death_age / death_duration` drives the full 1.8s candidate sequence. Exact incoming body/mast/bell/launcher geometry is preserved at entry. A final local bell flash/crack leads to wheel lock and gear deceleration over0.28s, chassis side settling (normalized0.12–0.58), mast release and bell drop (0.38–0.88), cold bell and extinguished seam light. Three bounded cosmetic pieces fall to the same approximate ground plane. There are no physical debris nodes, colliders, alpha fade, damage, or blocking bodies created by Presentation.

At normalized death1, body/parts/bell pose and light are static. Encounter owns death progression, reward impact, snapshot restoration, support, encounter cancellation and corpse lifetime. Presentation adds no timer, unbounded particle allocation, saved-health override, or delayed damage callback.

## Executed checks and remaining review

- Read-only PNG dimensions, SHA and source-region bounds inspected. Corrected wheel centers for the real128×114 image; all actual region rectangles/circular UV extents are within source images.
- Both actual GDScript files parsed successfully with gdtoolkit4.5.0 using `PYTHONPATH=/tmp/bellstrider-gdparse /tmp/bellstrider-gdparse/bin/gdparse ...`; formatter applied; `git diff --check` clean at this stage.
- This worker did not run Godot, following root's sole-engine lease. Root must compile actual consumers and inspect current-source normal-speed motion, both facings, all state bridges, ring contact/actual wave ticks, hit interruption, death entry from different poses and settled corpse.
- Current-source formal arena/HUD/player overlap, GPU sampling/crop appearance, final ground contact, actual retained corpse/snapshot lifecycle, voices and audio synchronization, performance, independent review and user/device acceptance remain unverified by this card.
