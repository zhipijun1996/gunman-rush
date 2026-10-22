extends "res://tests/enemy_feedback_01_tests.gd"
## v5 replaces the rejected corpse/support contract with short explosions.
## Explicit void, aerial and moving-host fixtures retain real Router projectiles.
## These do not certify the superseded persistent-corpse support/save bug.
var fixture_mode: StringName = &"supported"
var support_carrier: Node2D
var support_rows: Array[Dictionary] = []

func arena() -> void:
	support_carrier = Node2D.new()
	world.add_child(support_carrier)
	var floor_body := StaticBody2D.new()
	var box := RectangleShape2D.new()
	if fixture_mode == &"void":
		floor_body.position = Vector2(-900,400)
		box.size = Vector2(2320,40) # Player has ground; charger death x has none.
	else:
		floor_body.position = Vector2(0,400)
		box.size = Vector2(4000,40)
	var collision := CollisionShape2D.new()
	collision.shape = box
	floor_body.add_child(collision)
	support_carrier.add_child(floor_body)

func boundary_case(mode: StringName, underworld: bool) -> void:
	fixture_mode = mode
	var path := "res://resources/enemies/plains_diver.tres" if mode == &"aerial" else "res://resources/enemies/plains_charger.tres"
	await setup(path,underworld)
	for _hit: int in 3:
		check(await shoot_until_health_changes("boundary_real_router_projectile"), "v5 boundary fixture receives genuine accepted Router projectile")
	var effect := art.get("feedback_remains") as EnemyFeedback01Remains
	var reference: WeakRef = weakref(effect)
	check(actor.health.terminal and accepted.size() == 3 and effect.active and effect.accepted_starts == 1, "real three-projectile terminal result starts exactly one boundary explosion")
	if mode == &"void":
		check(player.is_on_floor() and enemy.global_position.x > 260, "void fixture has real player support and no floor under the actual charger death")
	elif mode == &"aerial":
		check(actor.definition.aerial and actor.definition.behavior_id == &"diver", "aerial boundary consumes the unchanged actual flying species")
	elif mode == &"moving_host":
		# Explicit fixture translation after terminal HP. No live AI, HP, tuning,
		# collider or reward is edited; stage/host motion must not restart effects.
		var delta_position := Vector2(43,-17)
		world.position += delta_position
		var support_reference: WeakRef = weakref(support_carrier)
		support_carrier.queue_free()
		await ticks(2,"moving_stage_and_removed_geometry")
		check(support_reference.get_ref() == null and effect.accepted_starts == 1, "moving host and disappearing geometry introduce neither retained support nor another death")
	var frames := 0
	while effect.active and frames < 90:
		await ticks(1,"boundary_natural_explosion_expiry")
		frames += 1
	check(frames < 90 and not effect.active and not effect.visible and effect.settled and effect.phase == &"spent", "void/aerial/moving-host explosion ends within bounded time without an invented floor or phantom corpse")
	check(effect.accepted_starts == 1, "boundary expiry retains exactly one accepted death")
	check(actor.restore_instance_health(0), "official saved-dead initialization accepted in boundary fixture")
	var saved_position := enemy.position+Vector2(80,-30)
	enemy.position = saved_position
	actor.brain.direction = -1
	await ticks(3,"dead_snapshot_with_late_saved_transform")
	check(enemy.position == saved_position and actor.brain.direction == -1, "death presentation never rewrites saved Motor position or brain facing")
	check(effect.restored and effect.settled and not effect.active and not effect.visible and effect.age == 0, "saved dead actor stays absent regardless of floor, motion or saved transform ordering")
	var frozen := remains_snapshot(effect)
	var starts := effect.accepted_starts
	await ticks(30,"dead_snapshot_stays_absent")
	check(remains_snapshot(effect) == frozen and effect.accepted_starts == starts, "saved snapshot does not restart explosion or create a floating corpse")
	check((art.get("feedback_particles") as EnemyFeedback01Particles).active_bursts() == 0 and (art.get("feedback_sample") as EnemyFeedback01).flash_strength() == 0, "saved dead boundary emits no old impact particles or flash")
	support_rows.append({"case":String(mode),"chain":"underworld" if underworld else "original","definition":path,"actual_accepted_hits":accepted.size(),"expiry_observed_frames":frames,"saved_motor":saved_position,"final":remains_snapshot(effect),"scope":"v5 short explosion; superseded persistent-corpse support/save correctness is not claimed"})
	effect = null
	await cleanup()
	check(reference.get_ref() == null, "boundary unload releases short-effect node and listeners")

func run() -> void:
	for underworld: bool in [false,true]:
		for mode: StringName in [&"void",&"aerial",&"moving_host"]:
			await boundary_case(mode,underworld)
	DirAccess.make_dir_recursive_absolute("res://build/enemy_feedback_01/v5")
	var file := FileAccess.open("res://build/enemy_feedback_01/v5/support_runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"task":"ENEMY-FEEDBACK-01","feedback_revision":"accepted_explosion_v5","checks":checks,"failures":failures,"cases":support_rows,"scope":"six explicit actual-projectile void/aerial/moving-host explosion boundaries; no general physics or superseded corpse-support/save certification"},"\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_SUPPORT checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
