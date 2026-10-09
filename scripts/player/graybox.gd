extends Node2D

const PLAYER := preload("res://scenes/player/player.tscn")
const RECHARGE := preload("res://scenes/world/recharge_point.tscn")
const SAW := preload("res://scenes/world/saw_hazard.tscn")
const CHECKPOINT := preload("res://scenes/world/checkpoint.tscn")
const SWITCH := preload("res://scenes/world/world_switch.tscn")
const ONE_WAY := preload("res://scenes/world/one_way_platform.tscn")
const PRACTICE_SPAWN := Vector2(90, 600)
const CHALLENGE_SPAWN := Vector2(1640, 600)
var player: PlayerMotor
var controller: PlayerController
var context: WorldContext
var hud: Label
var status_label: Label
var resource_hud: ActorResourcesHud
var pause_button: Button
var status := "Practice: move / jump / release to fire."
var challenge_start := 0.0
var challenge_active := false
var checkpoints: Array[SafeCheckpoint] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	context = WorldContext.new()
	context.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(context)
	# Original dark mechanical graybox. No final art assets are claimed.
	for rect: Rect2 in [Rect2(-100,630,620,90), Rect2(650,630,630,90), Rect2(200,525,140,20), Rect2(380,425,140,20), Rect2(800,545,200,20), Rect2(1120,460,30,170), Rect2(800,470,200,20), Rect2(1550,630,240,90), Rect2(1970,520,130,20), Rect2(2250,410,140,20), Rect2(2510,555,310,20), Rect2(2990,505,160,20), Rect2(3320,430,160,20), Rect2(3650,555,480,20)]:
		add_platform(rect)
	var one_way: OneWayPlatform = ONE_WAY.instantiate()
	one_way.position = Vector2(710, 430)
	add_child(one_way)
	_add_recharge(Vector2(590, 430), &"practice_recharge")
	_add_recharge(Vector2(2185, 270), &"challenge_recharge_a")
	_add_recharge(Vector2(3200, 300), &"challenge_recharge_b")
	_add_saw(Vector2(565, 610), Vector2.ZERO, &"practice_fixed_saw")
	var moving := _add_saw(Vector2(2920, 445), Vector2(0, 100), &"challenge_periodic_saw")
	var practice_moving := _add_saw(Vector2(1000, 410), Vector2(80, 0), &"practice_periodic_saw")
	var switch: WorldSwitch = SWITCH.instantiate()
	switch.position = Vector2(900, 532)
	switch.mechanism = practice_moving
	add_child(switch)
	switch.setup(context)
	_add_checkpoint(Vector2(2680, 537), &"challenge_midpoint")
	var target := CombatTarget.new()
	target.position = Vector2(1060, 598)
	add_child(target)
	context.register_object(target)
	var challenge_target := CombatTarget.new()
	challenge_target.position = Vector2(4010, 523)
	add_child(challenge_target)
	context.register_object(challenge_target)
	var goal := ChallengeGoal.new()
	goal.position = Vector2(3860, 500)
	add_child(goal)
	context.register_object(goal)
	goal.reached.connect(func(_actor: PlayerController) -> void:
		if challenge_active:
			status = "Goal reached in %.1fs. Retry or choose a practice area." % (context.clock - challenge_start)
			challenge_active = false
	)
	player = PLAYER.instantiate()
	player.position = PRACTICE_SPAWN
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	context.register_actor(controller, PRACTICE_SPAWN)
	context.respawned.connect(func() -> void:
		challenge_start = 0.0
		status = "Respawned at safe checkpoint."
	)
	var camera := Camera2D.new()
	camera.position = Vector2(190, -210)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = -320
	camera.limit_right = 4250
	camera.limit_top = 0
	camera.limit_bottom = 720
	player.add_child(camera)
	var overlay := InputSetup.attach(player, controller.router)
	overlay.pause_requested.connect(_toggle_pause)
	overlay.reset_requested.connect(_retry)
	var vignette := FocusVignette.new()
	vignette.ability = controller.air_focus_ability
	add_child(vignette)
	_make_hud()
	_add_sign(Vector2(25, 560), "SAFE START")
	_add_sign(Vector2(370, 350), "JUMP / RECOIL")
	_add_sign(Vector2(650, 370), "ONE-WAY / DROP")
	_add_sign(Vector2(820, 560), "PLATE DISABLES SAW / SHOOT TARGET")
	_add_sign(Vector2(1560, 530), "FIXED CHALLENGE")
	_add_sign(Vector2(2530, 610), "SAFE CHECKPOINT")
	_add_sign(Vector2(3660, 610), "GOAL / ATTACK TARGET")
	# Keep a consumer reference to demonstrate local mechanism composition.
	moving.set_meta(&"challenge_mechanism", true)

func add_platform(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	var visual := Polygon2D.new()
	var half := rect.size / 2.0
	visual.polygon = PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)])
	visual.color = Color(0.2, 0.25, 0.31)
	body.add_child(visual)
	add_child(body)

func _definition(id: StringName) -> WorldDefinition:
	var definition := WorldDefinition.new()
	definition.stable_id = id
	return definition

func _add_recharge(location: Vector2, id: StringName) -> void:
	var object: RechargePoint = RECHARGE.instantiate()
	object.definition = _definition(id)
	object.position = location
	add_child(object)
	object.setup(context)

func _add_saw(location: Vector2, travel: Vector2, id: StringName) -> SawHazard:
	var object: SawHazard = SAW.instantiate()
	object.definition = _definition(id)
	object.definition.travel = travel
	object.definition.period = 2.8
	object.position = location
	add_child(object)
	object.setup(context)
	return object

func _add_checkpoint(location: Vector2, id: StringName) -> void:
	var object: SafeCheckpoint = CHECKPOINT.instantiate()
	object.definition = _definition(id)
	object.position = location
	add_child(object)
	object.setup(context)
	checkpoints.append(object)

func _add_sign(location: Vector2, text: String) -> void:
	var label := Label.new()
	label.position = location
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(0.65, 0.7, 0.78)
	add_child(label)

func _make_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(22, 12)
	hud.add_theme_font_size_override("font_size", 18)
	canvas.add_child(hud)
	status_label = Label.new()
	status_label.position = Vector2(22, 168)
	status_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(status_label)
	resource_hud = ActorResourcesHud.new()
	canvas.add_child(resource_hud)
	resource_hud.bind(controller.actor_resources, controller.air_focus_ability)
	var x := 22.0
	for entry: Array in [["Practice", _practice], ["Challenge", _challenge], ["Retry", _retry], ["Pause", _toggle_pause]]:
		var button := Button.new()
		button.position = Vector2(x, 110)
		button.custom_minimum_size = Vector2(130, 52)
		button.text = entry[0]
		button.pressed.connect(entry[1])
		canvas.add_child(button)
		x += 140
		if entry[0] == "Pause":
			pause_button = button

func _process(_delta: float) -> void:
	if hud == null:
		return
	queue_redraw()
	var device := str(controller.router.current_device)
	var hint := "A/D move | Space jump | mouse release fires | S drop"
	if controller.router.current_device == &"touch":
		hint = "Left stick move | right stick aim/release fires | JUMP / DROP"
	elif controller.router.current_device == &"gamepad":
		hint = "Left stick move | right stick center fires | jump / down drop"
	var actions := controller.action_resource_view.snapshot()
	hud.text = "GUNMAN RUSH  |  %s  |  %s\nShots %d/%d  Jumps used %d/%d  Cooldown %.2fs" % [device,hint,actions.shots_remaining,actions.shot_limit,actions.jumps_used,actions.jump_limit,controller.shoot_ability.cooldown_remaining]
	status_label.text = status
	pause_button.text = "Resume" if get_tree().paused else "Pause"

func _physics_process(_delta: float) -> void:
	if not get_tree().paused and is_instance_valid(controller) and controller.active and player.global_position.y > 850:
		controller.die()

func _toggle_pause() -> void:
	controller.router.clear("pause")
	get_tree().paused = not get_tree().paused

func _retry() -> void:
	get_tree().paused = false
	context.respawn()

func _practice() -> void:
	get_tree().paused = false
	challenge_active = false
	context.restart(PRACTICE_SPAWN)
	for checkpoint: SafeCheckpoint in checkpoints:
		checkpoint.selected = false
	status = "Practice: movement, jumps, recoil, recharge and targets."

func _challenge() -> void:
	get_tree().paused = false
	context.restart(CHALLENGE_SPAWN)
	for checkpoint: SafeCheckpoint in checkpoints:
		checkpoint.selected = false
	challenge_active = true
	challenge_start = context.clock
	status = "Challenge: jump > recoil > recharge > periodic saw > checkpoint > goal."

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			_retry()
		elif event.physical_keycode == KEY_ESCAPE:
			_toggle_pause()

func _draw() -> void:
	if not is_instance_valid(controller) or not controller.active:
		return
	var aim := controller.router.aim_direction
	if not aim.is_zero_approx():
		var center := player.position
		draw_line(center + aim * 20, center + aim * 68, Color(0.64, 0.92, 0.92, 0.75), 2)
		draw_arc(center + aim * 72, 5, 0, TAU, 16, Color(0.73, 0.95, 0.94), 1.5)
