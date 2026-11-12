extends "res://tests/world/approved_draft_actions.gd"
## Accepted real policy hits in a declared authored-room fixture, not a full run.
var assertions := 0
func verify(ok: bool, label: String) -> void:
	assertions += 1
	check(ok, label)
func settle_damage() -> void:
	for i: int in 240:
		await ticks(1)
		if not app.busy: return
	verify(false, "damage presentation has a bounded end")
func run() -> void:
	root.size = Vector2i(1280,720)
	app = preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path = "user://damage_sequence_test.json"
	root.add_child(app)
	await load_room("P-R22")
	await fixture(Vector2(880,334))
	var body := PlayerPresentationRuntime.current_body(app.player)
	var audio := GameAudio.for_origin(app.player)
	await ticks(35)
	var hp := app.controller.actor_resources.health.current
	var hurt_audio := int(audio.played.get(&"hurt",0))
	var origin := app.player.position
	print("DAMAGE MEDIA hit frame=", Engine.get_process_frames())
	app.submit_damage(&"sequence_enemy", DamageRequest.Kind.MONSTER, 1, &"sequence_hit")
	await ticks(1)
	verify(app.busy and paused and app.damage_sequence.kind == "hit", "ordinary hit begins one bounded impact hold")
	verify(app.player.position == origin and body.animation_state == "hurt", "accepted hit displays real hurt frame before motion")
	verify(int(audio.played.get(&"hurt",0)) == hurt_audio+1, "ordinary hit emits one selected hurt sound")
	await settle_damage()
	await ticks(16)
	verify(app.controller.active and not paused and app.player.position.distance_to(origin)>5, "real Motor knockback follows impact hold and restores control")
	verify(app.controller.actor_resources.health.current == hp-1, "ordinary presentation does not change accepted damage")
	verify(not app.policy.submit(_duplicate_request()), "rejected duplicate produces no new presentation")
	await ticks(45)
	await fixture(Vector2(880,334))
	app.entry_anchor = Vector2(672,142)
	hp = app.controller.actor_resources.health.current
	var cycle := int(app.state.value.cycle)
	var epoch := app.lifetime.actor_epoch
	app.controller.shoot_ability.cooldown_remaining = .6
	print("DAMAGE MEDIA terrain frame=", Engine.get_process_frames())
	app.submit_damage(&"sequence_thorn", DamageRequest.Kind.ENVIRONMENT, 1, &"sequence_terrain")
	await ticks(2)
	verify(app.damage_sequence.kind == "terrain" and app.busy and paused, "terrain uses its own retreat sequence")
	verify(app.lifetime.actor_epoch == epoch and not app.ui.curtain.visible, "hazard first shows impact at original position")
	var held_age := app.damage_sequence.age
	app.damage_sequence.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await ticks(4)
	verify(app.damage_sequence.age == held_age and app.lifetime.actor_epoch == epoch, "loss of focus suspends the accepted return without stale relocation")
	app.damage_sequence.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	var covered_relocation := false
	for i: int in 65:
		await ticks(1)
		if app.lifetime.actor_epoch>epoch:
			covered_relocation = app.ui.curtain.visible and app.ui.curtain.color.a>.99
			break
	verify(covered_relocation, "safe relocation only occurs under complete cover")
	await settle_damage()
	verify(app.controller.actor_resources.health.current == hp-1 and app.state.value.cycle == cycle, "terrain loses exactly one HP and keeps rest cycle")
	verify(app.controller.shoot_ability.cooldown_remaining>.5, "terrain return preserves weapon cooldown through suspended world")
	verify(app.player.position.distance_to(app.entry_anchor)<3 and not app.ui.curtain.visible and app.controller.active, "terrain reveals the correct anchor and restores normal control")
	verify(app.policy.player_clock()<app.policy._protected_until, "returned actor has real spawn protection")
	# A new accepted hit during slow air aim must restore the existing time owner.
	await ticks(50)
	app.controller.router.set_aim(&"keyboard_mouse", Vector2.LEFT, true)
	print("DAMAGE MEDIA death frame=", Engine.get_process_frames())
	app.submit_damage(&"sequence_death", DamageRequest.Kind.MONSTER, 99, &"sequence_fatal")
	hurt_audio = int(audio.played.get(&"hurt",0))
	var death_audio := int(audio.played.get(&"death",0))
	await ticks(2)
	verify(app.controller.actor_resources.health.terminal and not app.controller.active and not app.lifetime.active, "death invalidates gameplay before animation finishes")
	verify(body.animation_state == "death" and body.frame_index == 0 and app.busy, "death holds true collapse animation rather than immediately resetting")
	verify(int(audio.played.get(&"death",0)) == death_audio+1 and int(audio.played.get(&"hurt",0)) == hurt_audio, "fatal event plays one death cue without stacked hurt")
	verify(is_equal_approx(Engine.time_scale,1.0), "death exits air-focus without introducing another time-scale owner")
	await ticks(18)
	verify(body.animation_state == "death" and body.frame_index == 1 and app.controller.actor_resources.health.terminal, "second actual fallen-body keyframe stays visible")
	await settle_damage()
	verify(not paused and app.controller.active and not app.controller.actor_resources.health.terminal, "death completes through the real rest-point loader")
	verify(app.state.value.cycle == cycle+1 and app.controller.actor_resources.health.current == app.controller.actor_resources.health.capacity, "death restores HP and starts exactly one new cycle")
	verify(not app.ui.curtain.visible and (app.camera as WorldCamera)._takeover.is_empty(), "death leaves no cover or transient camera takeover")
	print("DAMAGE MEDIA restored frame=", Engine.get_process_frames())
	app.review.set_invincible(true)
	hp = app.controller.actor_resources.health.current
	hurt_audio = int(audio.played.get(&"hurt",0))
	app.submit_damage(&"immune_thorn", DamageRequest.Kind.ENVIRONMENT, 1, &"immune_terrain")
	await ticks(2)
	verify(app.damage_sequence.active and not app.damage_sequence.show_impact, "invincible review returns from hazards without injury presentation")
	await settle_damage()
	verify(app.controller.actor_resources.health.current == hp and int(audio.played.get(&"hurt",0)) == hurt_audio, "invincible review return neither loses HP nor plays hurt sound")
	app.review.set_invincible(false)
	await ticks(40)
	app.player.reset_at(Vector2(880,220))
	await ticks(2)
	app.submit_damage(&"air_death", DamageRequest.Kind.MONSTER, 99, &"air_fatal")
	await ticks(2)
	var air_start := app.player.position
	await ticks(16)
	verify(app.player.position.y>air_start.y+20 and not app.controller.active, "terminal airborne body settles through the sole real Motor instead of hanging in space")
	await settle_damage()
	# Forced handoff while impact is pending cannot later return the new actor.
	await load_room("P-R22")
	app.submit_damage(&"cancel_thorn", DamageRequest.Kind.ENVIRONMENT, 1, &"cancel_terrain")
	await ticks(2)
	var old_sequence := app.damage_sequence
	app.load_room("P-R21", "")
	await settle_damage()
	await ticks(45)
	verify(app.room.room_id == "P-R21" and not paused and not is_instance_valid(old_sequence), "forced room handoff cancels old hazard presentation and pause")
	await WorldAudioLifecycle.drain_world(app)
	print("PLAYER DAMAGE SEQUENCE: ",assertions," checks; ",failures," failures")
	quit(failures)

func _duplicate_request() -> DamageRequest:
	var value := DamageRequest.new()
	value.token=app.lifetime.token(); value.actor_epoch=app.lifetime.actor_epoch
	value.health_epoch=app.controller.actor_resources.health.epoch
	value.source_id=&"sequence_enemy"; value.event_id=&"sequence_hit"; value.target_id=&"player"
	return value
