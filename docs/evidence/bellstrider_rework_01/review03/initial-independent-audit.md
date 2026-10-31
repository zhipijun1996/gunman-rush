# Review 03: mounted-bell contact omission (read-only audit)

Source inspected: feature/bellstrider-rework-01, starting head 100221afcf4ccc73e2103b30227ea882962cfb71. No Godot run, no production/test edits. Actual review02 trace and MP4 inspected; one actual frame extracted with ffmpeg.

## Confirmed failure

`BellstriderEncounter.body_contact_sweep()` admits only the real convex hull and two wheels. It never tests the installed upper `_core` shape. `_core` is the authoritative 30×36 rotated/mirrored upper-bell Area used for drawing/shot damage, but its receiver routes incoming player damage to Boss HP; that does not produce outgoing contact damage. `DemoContactEmitter` delegates exclusively to this hull/wheel provider, so no other contact path compensates for the upper-bell omission.

The review02 movie is a concrete counterexample, not merely an untested hazard. At movie frame295 / 4.916667s, normal roll:

- player centre [6344.58056640625, 549.612915039062], player rectangle24×36;
- installed-bell centre `bell_world` [6344.306640625, 565.54345703125];
- |dx|=.273926, |dy|=15.930542, so the actual bell centre lies INSIDE the player rectangle. This guarantees overlap regardless of bell rotation, stronger than comparing two axis-aligned bounds;
- player HP=5; every movie frame remains5;
- player is active, no hook action/attack fixture, state=roll;
- actual extracted fullframe `/tmp/bell_review03_overlap.png` visibly shows player covering the upper bell and unchanged5/5HUD.

There are19 live nonintro/nondead movie samples with bell centre strictly inside the player rectangle. Examples:4.900–4.933s(group1),14.200–14.217(group4),25.000–25.017(group7),30.750(group9),39.167(group11),42.650–42.667(group12),48.967–48.983(group14),61.217–61.233(group17),67.583–67.600(group19),73.500–73.517(group20). A looser AABB overlap finder reports51samples, but only19 centre-containment samples are claimed here as exact geometric counterexamples. Renderer sampling is actual frame_post_draw; not synthetic movement.

## A test encoded the omission

`tests/bellstrider_rework_01/contact_edges.gd::roof()` relocates actor to `boss.global_position + (0,-85)` and asserts first8ticks no hit as 'clear bell and mast space'. Mounted bell nominal centre is approximately(-7,-82) relative to Boss, so this is not a valid clear-air fixture: it overlaps the installed bell. The test must change its negative fixture to genuinely empty air and add explicit installed-bell touch positives. Changing this expectation is justified by user’s original '主角碰到boss应该有碰撞伤害' and new observed omission; do not simply remove the negative.

## Thrown-bell chain: not the demonstrated failure

Inspected `BellstriderBellProjectile._sweep()`: collision mask1 includes actual player default layer1, initial overlaps and swept contact call `hit.emit(_target,event_id,amount)`, real terrain wins simultaneous terrain/player contacts. Amount inherits actualDefinition projectile_damage1. Actual `_configure_projectile()` emits projectile_created, and formal DemoApp connects `hit` to `_submit_damage('boss_projectile',MONSTER,...)`. Local landed shock similarly intersects the real target and checks terrain occlusion.

In THIS movie, the closest small thrown copper bell comes134.5068worldunits from player rectangle (53.266667s), far outside radius10. Thus this clip cannot show thrown-bell collision failing or passing. No thrown-bell defect is established by source inspection alone. A real formalApp direct-hit/landed-shock fixture remains useful to rule it out, but it must not obscure the confirmed installed-bell omission.

## Recommended scoped repair and evidence

Include the real mounted-bell CollisionShape2D in outgoing contact query using its current shared rig transform, without making it a physical shot-blocking body. Preserve current player/weapon incoming weakpoint rules, cleared gaps, intro/death suppression, live phase-transition danger, original FrameDamagePolicy cooldown/epochs and genuine canonical Boss hook-contact protection.

Add positives for upper-bell touch both facings / swing poses / roll sweep, valid nearby empty air negative, corpse no-contact and own-hook protection. Record an actual default-speed segment where overlap is followed by original HP decrement, hurt movement/flash and original sound. Current no-injury cautious recording must not continue to stand as proof of collision damage.
