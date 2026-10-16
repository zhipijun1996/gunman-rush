extends SceneTree
const PLAYER := preload("res://scenes/player/player.tscn")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var occurrences := {"plains_recoil_span": 0, "plains_ferry_gears": 0, "plains_recoil_double": 0}
	for seed_index: int in 48:
		for stage_index: int in [3, 4, 5, 6]:
			var generated := PlainsStageGenerator.new().generate("feedback-variety-%d" % seed_index, stage_index, &"combat", PlayerTuning.load_default())
			check(generated.ok, "new combo corpus retains bounded capability-valid generation")
			if generated.ok:
				for node: Dictionary in generated.manifest.nodes:
					if occurrences.has(node.module_id): occurrences[node.module_id] += 1
	for id: String in occurrences:
		check(occurrences[id] > 0, "new combination appears in real formal manifests: %s" % id)
	print("FORMAL COMBO OCCURRENCES: ", occurrences)
	var ui_font := preload("res://assets/fonts/windkeeper_ui.ttf")
	for glyph: String in "护甲挡弹核心命中空弹药尽落地补充铃芯音量会话":
		check(ui_font.has_char(glyph.unicode_at(0)), "Chinese feedback has a real included glyph: %s" % glyph)
	var world := Node2D.new()
	root.add_child(world)
	var audio := GameAudio.new()
	world.add_child(audio)
	check(audio._voices.size() == 12, "sound voices are bounded")
	for id: StringName in GameAudio.CUES:
		check(audio._streams[id] is AudioStreamOggVorbis and audio._streams[id].get_length() > 0, "licensed OGG imports: %s" % id)
	var button := Button.new()
	world.add_child(button)
	button.pressed.emit()
	check(audio.played.get(&"click", 0) == 1, "actual newly added GUI button emits one click")
	check(not audio.play(&"click"), "repeated same-frame click does not overlap")
	audio.volume = 0
	check(not audio.play(&"jump"), "zero volume cannot create a voice")
	audio.volume = 0.7
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 100)
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	var motor: PlayerMotor = PLAYER.instantiate()
	motor.position = Vector2(0, 62)
	world.add_child(motor)
	var controller: PlayerController = motor.get_node("Controller")
	var camera := StageCameraRig.new()
	world.add_child(camera)
	camera.configure(motor, Rect2(-3000, -3000, 6000, 6000))
	for unused: int in 180: await physics_frame
	check(motor.is_on_floor(), "look fixture lands through actual Motor")
	var screen_y := 360 + (motor.global_position.y - camera.global_position.y) * camera.zoom.y
	check(screen_y > 380 and screen_y < 470, "ordinary grounded player composition stays near middle")
	var position_before := motor.global_position
	var center := camera.global_position.y
	controller.router.set_look_axis(&"keyboard_mouse", -1)
	var max_step := 0.0
	for unused: int in 120:
		var before := camera.global_position.y
		await physics_frame
		max_step = maxf(max_step, absf(camera.global_position.y - before))
	check(camera.global_position.y < center - 75 and max_step < 4, "grounded up look pans smoothly to see upper platforms")
	check(motor.global_position.distance_to(position_before) < 0.01, "camera inspection cannot move the player")
	controller.router.activate_device(&"gamepad")
	check(controller.router.look_axis == 0, "device switch clears old observation input")
	controller.router.set_look_axis(&"gamepad", 1)
	for unused: int in 180: await physics_frame
	check(camera.global_position.y > center + 50, "gamepad down observation shares smooth camera path")
	controller.router.clear("pause")
	check(controller.router.look_axis == 0, "pause clears held viewing axis")
	for unused: int in 180: await physics_frame
	check(absf(camera.global_position.y - center) < 1, "release returns to ordinary composition")
	var rejections: Array[StringName] = []
	controller.shoot_ability.shot_rejected.connect(func(reason: StringName) -> void: rejections.append(reason))
	controller.action_resources.shot_charges = 0
	check(not controller.shoot_ability.try_fire(Vector2.RIGHT, false) and rejections == [&"empty"], "empty shot explains failure without emitting a projectile")
	controller.action_resources.reset()
	check(controller.shoot_ability.try_fire(Vector2.RIGHT, true), "available shot still emits real projectile")
	check(not controller.shoot_ability.try_fire(Vector2.RIGHT, true) and rejections[-1] == &"cooldown", "cooldown distinguishes rejection from empty ammo")
	# Reproduce simultaneous target/wall overlap through the real swept projectile.
	var target := StaticBody2D.new()
	target.position = Vector2(300, -200)
	var target_shape := CollisionShape2D.new()
	var target_rect := RectangleShape2D.new()
	target_rect.size = Vector2(24, 36)
	target_shape.shape = target_rect
	target.add_child(target_shape)
	world.add_child(target)
	var wall := StaticBody2D.new()
	wall.position = target.position + Vector2(10, 0)
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(20, 60)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	world.add_child(wall)
	var shot := BossProjectile.new()
	var boss_definition := BossDefinition.new()
	shot.configure(boss_definition, &"occlusion_fixture", Vector2.RIGHT, target, null)
	shot.radius = 5
	shot._shape.radius = 5
	shot.speed = 100
	shot.lifetime = 1
	world.add_child(shot)
	shot.set_physics_process(false)
	shot.global_position = target.global_position
	var hits: Array[StringName] = []
	shot.hit.connect(func(_target: Node2D, id: StringName, _amount: float) -> void: hits.append(id))
	await physics_frame
	await physics_frame
	await process_frame
	shot.advance(1.0 / 60)
	check(shot.spent and hits.is_empty(), "simultaneous Boss wall contact blocks target damage")
	# Keep prior modal options, while checking actual keyboard/gamepad focus.
	var offer := RewardOffer.new()
	offer.candidates.append(load("res://resources/items/shot_purple.tres"))
	var modal := StageRewardModal.new()
	world.add_child(modal)
	modal.show_offer(offer, "next room")
	await process_frame
	check(root.gui_get_focus_owner() is Button, "reward choice has real GUI focus for Enter/gamepad")
	modal.close()
	controller.router.clear("keyboard_observation_fixture")
	var keyboard := motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
	var down := InputEventKey.new()
	down.physical_keycode = KEY_DOWN
	down.pressed = true
	keyboard._unhandled_input(down)
	check(controller.router.look_axis == 1 and controller.router._queue.is_empty(), "down arrow inspects without dropping through a platform")
	down.pressed = false
	keyboard._unhandled_input(down)
	var up := InputEventKey.new()
	up.physical_keycode = KEY_UP
	up.pressed = true
	keyboard._unhandled_input(up)
	check(controller.router.look_axis == -1 and controller.router._queue.is_empty(), "up arrow inspects without opening nearby interaction UI")
	var old_boss: BossMotor = preload("res://scenes/bosses/windkeeper.tscn").instantiate()
	var new_boss: BossMotor = preload("res://scenes/bosses/windkeeper.tscn").instantiate()
	world.add_child(old_boss)
	world.add_child(new_boss)
	await physics_frame
	await physics_frame
	await process_frame
	var boss_hud := WindkeeperHud.new()
	world.add_child(boss_hud)
	var old_encounter := old_boss.get_node("Encounter") as WindkeeperEncounter
	var new_encounter := new_boss.get_node("Encounter") as WindkeeperEncounter
	boss_hud.bind(old_encounter)
	old_encounter.armour_hit.emit(Vector2.ZERO)
	check(boss_hud._hint_age > 0, "bound actual Boss signal reports armour")
	boss_hud.bind(new_encounter)
	old_encounter.armour_hit.emit(Vector2.ZERO)
	check(boss_hud._hint_age == 0 and boss_hud._hit_hint.is_empty(), "new Boss clears old hint and disconnects old encounter")
	new_encounter.armour_hit.emit(Vector2.ZERO)
	check(boss_hud._hint_age > 0, "new encounter owns its hint subscription")
	if not await load("res://tests/audio_teardown.gd").drain_world(world):
		push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms")
		quit(1)
		return
	world.free()
	await process_frame
	print("PLAINS FEEDBACK: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
