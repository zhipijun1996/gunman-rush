## v8: restored strict persistent-corpse assertions from 0d5b72c following the
## latest user rejection of exploded disappearance and custom death sound.
extends "res://tests/enemy_feedback_01_tests.gd"
## ENEMY-FEEDBACK-01 v3 bounded support counterexamples. Explicit local geometry,
## original Actor/AI/HP and actual Router/Shoot/projectile damage. Not a general
## physics-system suite or natural campaign traversal. Root owns engine execution.
const CHARGER_PATH := "res://resources/enemies/plains_charger.tres"
var fixture_mode: StringName = &"supported"
var support_carrier: Node2D
var support_floor: StaticBody2D
var support_rows: Array[Dictionary] = []

func arena() -> void:
	support_carrier = Node2D.new()
	support_carrier.name = "ExplicitSupportCarrier"
	world.add_child(support_carrier)
	support_floor = StaticBody2D.new()
	support_floor.name = "ExplicitSupportFloor"
	var box := RectangleShape2D.new()
	if fixture_mode == &"void":
		# Player and its recoil corridor are grounded. The actual charger starts
		# beyond this platform's right edge; no geometry exists below its death x.
		support_floor.position = Vector2(-900, 400)
		box.size = Vector2(2320, 40) # Rightmost real solid x = 260.
	else:
		support_floor.position = Vector2(0, 400)
		box.size = Vector2(4000, 40)
	var collision := CollisionShape2D.new()
	collision.shape = box
	support_floor.add_child(collision)
	support_carrier.add_child(support_floor)

func actual_charger_death(underworld: bool) -> bool:
	await setup(CHARGER_PATH, underworld)
	for _hit: int in 3:
		check(await shoot_until_health_changes("support_actual_router_projectile"), "support counterexample receives genuine accepted Router projectile")
	var remains: EnemyFeedback01Remains = art.get("feedback_remains") as EnemyFeedback01Remains
	check(actor.health.terminal and accepted.size() == 3 and shots.size() >= 3, "three original one-damage projectile commits cause actual charger terminal HP")
	check(remains.active and remains.accepted_starts == 1 and not remains.restored, "actual terminal result starts exactly one cosmetic remains")
	return actor.health.terminal

func wait_for_void(remains: EnemyFeedback01Remains, phase: String) -> int:
	var frames := 0
	# Bounded observation only. No calls to advance/_physics_process or changes
	# to gravity, FLOOR_REACH, collision masks, movement or test-runner budgets.
	while remains.active and frames < 300:
		await ticks(1, phase)
		frames += 1
	return frames

func void_death_case(underworld: bool) -> void:
	fixture_mode = &"void"
	var killed := await actual_charger_death(underworld)
	var remains := art.get("feedback_remains") as EnemyFeedback01Remains
	var reference: WeakRef = weakref(remains)
	check(player.is_on_floor(), "void fixture keeps actual player supported while charger dies over no floor")
	check(enemy.global_position.x > 260, "actual terminal charger position remains beyond the real platform edge")
	var frames := await wait_for_void(remains, "unsupported_actual_corpse_fall")
	check(killed and frames < 300 and not remains.active and not remains.visible and remains.phase == &"void", "unsupported genuine corpse exits within bounded observation without an invented floating floor")
	check(remains.accepted_starts == 1 and not remains.settled, "void exit retains one accepted death and never claims ground settlement")
	check(actor.restore_instance_health(0), "official saved dead health initialization accepts unsupported corpse")
	await ticks(3, "unsupported_static_restore_reconcile")
	var frozen := remains_snapshot(remains)
	check(remains.restored and remains.settled and not remains.visible and remains.phase == &"resting", "saved unsupported corpse reconstructs hidden static state instead of a new fall")
	var count := remains.accepted_starts
	await ticks(30, "unsupported_static_restore_stays_silent")
	check(remains_snapshot(remains) == frozen and remains.accepted_starts == count and remains.age == 0, "unsupported saved corpse neither animates nor restarts accepted death after reconcile")
	check((art.get("feedback_particles") as EnemyFeedback01Particles).active_bursts() == 0 and (art.get("feedback_sample") as EnemyFeedback01).flash_strength() == 0, "unsupported static restoration emits no debris or flash")
	support_rows.append({"case": "actual_void_death_and_static_restore", "chain": "underworld" if underworld else "original", "actual_accepted_hits": accepted.size(), "bounded_fall_frames": frames, "terminal_position": enemy.global_position, "static_snapshot": remains_snapshot(remains)})
	remains = null
	await cleanup()
	check(reference.get_ref() == null, "void case unload releases the inactive remains and its listeners")

func translated_support_case(underworld: bool) -> void:
	fixture_mode = &"supported"
	await actual_charger_death(underworld)
	var remains := art.get("feedback_remains") as EnemyFeedback01Remains
	var reference: WeakRef = weakref(remains)
	await ticks(90, "actual_corpse_settles_on_existing_support")
	check(remains.active and remains.settled and remains.visible, "real accepted corpse settles on actual existing support before translation")
	var before := remains.global_position
	var starts := remains.accepted_starts
	var translation := Vector2(43, -17)
	support_carrier.position += translation
	await ticks(3, "existing_support_translation")
	check(remains.global_position.is_equal_approx(before + translation), "settled remains follows the actual support parent's predetermined translation")
	check(remains.accepted_starts == starts and remains.settled, "support translation does not replay death or unsettle supported remains")
	var support_reference: WeakRef = weakref(support_floor)
	support_carrier.queue_free()
	await ticks(3, "existing_support_released")
	check(support_reference.get_ref() == null, "actual geometric support is released rather than held alive by corpse tracking")
	check(not remains.settled and remains.phase == &"falling", "released weak support resumes bounded visual fall rather than retaining a floating resting corpse")
	var frames := await wait_for_void(remains, "released_support_bounded_fall")
	check(frames < 300 and not remains.active and not remains.visible and remains.phase == &"void", "released support leaves no active orphan or infinite floating corpse")
	check(remains.accepted_starts == starts, "support disappearance cannot create another accepted death")
	support_rows.append({"case": "weak_support_translation_and_release", "chain": "underworld" if underworld else "original", "translation": translation, "settled_position": before, "bounded_release_frames": frames, "final": remains_snapshot(remains)})
	remains = null
	await cleanup()
	check(reference.get_ref() == null, "support-release case unload releases inactive remains sibling")

func late_saved_transform_case(underworld: bool) -> void:
	fixture_mode = &"supported"
	await setup(CHARGER_PATH, underworld)
	var remains := art.get("feedback_remains") as EnemyFeedback01Remains
	var reference: WeakRef = weakref(remains)
	check(actor.restore_instance_health(0), "official restore initializes dead health before saved transform fixture")
	# This is the production restore ordering: health initializes first; stage
	# applies the recorded body position and brain facing immediately afterward.
	var saved_position := Vector2(540, 364)
	enemy.position = saved_position
	actor.brain.direction = -1
	await ticks(3, "saved_transform_after_health_initialization")
	check(enemy.position == saved_position and actor.brain.direction == -1, "cosmetic reconciliation never rewrites saved Motor position or brain direction")
	check(remains.active and remains.visible and remains.restored and remains.settled and remains.phase == &"resting", "late saved transform yields directly visible static remains on actual support")
	check(is_equal_approx(remains.global_position.x, saved_position.x) and remains.frame_index == 7 and float(remains.get("_face")) < 0, "next-physics reconciliation uses actual saved x and reversed facing on authored rest frame 7")
	check(remains.accepted_starts == 0 and remains.age == 0 and accepted.is_empty() and shots.is_empty(), "static saved reconciliation is never mislabeled as an accepted hit or new death animation")
	var frozen := remains_snapshot(remains)
	await ticks(20, "saved_static_reconcile_no_replay")
	check(remains_snapshot(remains) == frozen, "saved transform is reconciled once and does not restart falling on later ticks")
	check((art.get("feedback_particles") as EnemyFeedback01Particles).emitted_bursts == 0 and (art.get("feedback_sample") as EnemyFeedback01).flash_strength() == 0, "late saved transform produces no accepted impact flash or debris")
	support_rows.append({"case": "saved_transform_applied_after_health", "chain": "underworld" if underworld else "original", "saved_motor": saved_position, "saved_direction": -1, "static_snapshot": frozen})
	remains = null
	await cleanup()
	check(reference.get_ref() == null, "saved-transform fixture unload releases static remains sibling")

func run() -> void:
	for underworld: bool in [false, true]:
		await void_death_case(underworld)
		await translated_support_case(underworld)
		await late_saved_transform_case(underworld)
	DirAccess.make_dir_recursive_absolute("res://build/enemy_feedback_01/v8")
	var file := FileAccess.open("res://build/enemy_feedback_01/v8/support_runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"task": "ENEMY-FEEDBACK-01", "feedback_revision": "dedicated_species_frames_and_persistent_corpse_v8", "checks": checks, "failures": failures, "cases": support_rows, "scope": "six explicit charger support/void/restore-order fixtures across both actual rendering chains; genuine Router projectile deaths for void and support cases; no natural-route/GPU/device or general physics certification"}, "\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_SUPPORT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
