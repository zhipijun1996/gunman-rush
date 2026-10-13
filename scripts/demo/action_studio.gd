class_name ActionStudio
extends Node2D
## Shared real actors, collision and resource services. Practice awards no run rewards.
signal home_requested
var player: PlayerMotor
var controller: PlayerController
var overlay: TouchOverlay
var camera: Camera2D
var policy: FrameDamagePolicy
var lifetime := DemoLifetime.new()
var actors: Array[EnemyActor] = []
var bosses: Array[BossEncounter] = []
var input_values: Dictionary = {}
var section := 0
var _hud: Label
var _solids: Array[Rect2] = []
var _events: Array[Dictionary] = []
var elapsed := 0.0
var paused := false

func configure(values: Dictionary) -> void:
	input_values = values.duplicate(true)

func _ready() -> void:
	add_child(PlainsBackground.new())
	_ground(Rect2(-100,620,8900,180))
	# Explicit safe surfaces for same-wall and alternating-wall practice.
	_ground(Rect2(880,120,50,500),true)
	_ground(Rect2(1160,-100,45,720),true)
	_ground(Rect2(1300,-100,45,720),true)
	_ground(Rect2(700,420,180,24))
	_ground(Rect2(1450,430,140,24))
	_ground(Rect2(1680,320,160,24))
	_ground(Rect2(1940,420,140,24))
	for point: Vector2 in [Vector2(1770,406),Vector2(2110,335),Vector2(2390,360)]:
		var anchor := GrappleAnchor.new()
		anchor.position = point
		add_child(anchor)
	var art := PlainsTileComposer.build_rectangles(_solids)
	if art != null: add_child(art)
	player = preload("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(150,602)
	add_child(player)
	controller = player.get_node("Controller")
	controller.enable_shot_energy()
	controller.traversal.grant(&"wall_climb")
	controller.traversal.grant(&"double_jump")
	controller.traversal.grant(&"grapple")
	controller.router.grapple_available = true
	if not input_values.is_empty(): controller.router.reconfigure(input_values)
	overlay = InputSetup.attach(player,controller.router)
	overlay.hide_reset_button = true
	overlay.pause_requested.connect(_toggle_pause)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.6,1.6)
	camera.position = player.position+Vector2(150,-100)
	add_child(camera)
	camera.make_current()
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	policy.player_fatal.connect(controller.die)
	_spawn_actors()
	_spawn_candidates()
	_spawn_bosses()
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var pause_input := ActionStudioPauseInput.new()
	pause_input.studio = self
	add_child(pause_input)
	var panel := PanelContainer.new()
	panel.position = Vector2(16,12)
	panel.size = Vector2(minf(980,get_viewport_rect().size.x-32),130)
	get_viewport().size_changed.connect(func() -> void: panel.size.x = minf(980,get_viewport_rect().size.x-32))
	panel.theme = DemoMenu.create_theme()
	panel.theme.default_font = preload("res://assets/fonts/foundry_notes.otf")
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_hud = Label.new()
	_hud.add_theme_color_override("font_color",DemoMenu.TEXT)
	_hud.add_theme_font_size_override("font_size",17)
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_hud)
	var row := HFlowContainer.new()
	box.add_child(row)
	_button(row,"普通枪",func() -> void: controller.shoot_ability.equip(preload("res://resources/weapons/pulse_gun.tres")))
	_button(row,"三连机关枪",func() -> void: controller.shoot_ability.equip(preload("res://resources/weapons/triple_machine_gun.tres")))
	for i: int in 4:
		var index := i
		_button(row,["跑跳射击","爬墙跳","钩索接力","人物遭遇"][i],func() -> void: restart(index))
	_button(row,"重试",func() -> void: restart(section))
	_button(row,"返回",leave)
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2,serial: int) -> void: _record(&"shot",{"direction":[direction.x,direction.y],"serial":serial}))
	controller.traversal.action_changed.connect(func(action: StringName) -> void: _record(action,{}))
	controller.jump_ability.jumped.connect(func() -> void: _record(&"jump",{"used":controller.jump_ability.used_jumps}))
	controller.died.connect(func() -> void: _record(&"death",{}))
	queue_redraw()

func _ground(rect: Rect2, climbable: bool = false) -> void:
	_solids.append(rect)
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	if climbable: body.add_to_group(&"wall_climbable")
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	body.add_child(shape)
	add_child(body)

func _spawn_actors() -> void:
	var definitions := ["patrol_drone","plains_charger","plains_sentry","plains_hopper","plains_diver","plains_fan_sentry"]
	for i: int in definitions.size():
		var motor: EnemyMotor = preload("res://scenes/enemies/patrol_drone.tscn").instantiate()
		var actor: EnemyActor = motor.get_node("Actor")
		actor.definition = load("res://resources/enemies/%s.tres" % definitions[i]).duplicate(true)
		motor.position = Vector2(2750+i*330,604 if not actor.definition.aerial else 485)
		add_child(motor)
		var id := StringName("studio_enemy_%s" % i)
		policy.bind_damageable(id,actor.damageable,actor.health)
		actor.bind_encounter(controller,policy,lifetime,id,[])
		var contact := DemoContactEmitter.new()
		contact.policy = policy
		contact.controller = controller
		contact.source_id = id
		contact.half_size = actor.definition.collision_size/2
		motor.add_child(contact)
		actor.defeated.connect(func(_actor: EnemyActor) -> void: contact.enabled=false)
		actors.append(actor)

func restart(index: int) -> void:
	get_tree().paused = false
	paused = false
	section = index
	lifetime.invalidate_actor()
	controller.reset_at([Vector2(150,602),Vector2(810,602),Vector2(1490,400),Vector2(2580,602)][index])
	controller.router.grapple_available = true
	camera.position = player.position+Vector2(130,-100)
	_record(&"practice_reset",{"section":index})

func _process(delta: float) -> void:
	if get_tree().paused: return
	elapsed += delta
	camera.position = camera.position.lerp(player.position+Vector2(130,-100),1-exp(-delta*5))
	_hud.text = "动作练习 · %s · 二跳 %d / 钩索 %d / 爬墙
精力 %.0f · 空中攻击 %d · %s" % ["普通枪" if controller.shoot_ability.weapon.tier==1 else "三连机关枪",mini(1,maxi(0,controller.jump_ability.maximum_jumps()-controller.jump_ability.used_jumps)),0 if controller.traversal.hook_used else 1,controller.actor_resources.stamina.current,controller.action_resources.shot_charges,"已倒下，点击重试" if not controller.active else "A/D移动 · Space跳跃 · 松开左键射击 · 右键/E钩索"]
	if _events.size() > 4096: _events.pop_front()
	queue_redraw()

func _button(row: Container, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(90,36)
	button.pressed.connect(action)
	row.add_child(button)

func _record(action: StringName, extra: Dictionary) -> void:
	_events.append({"action":str(action),"physics_tick":Engine.get_physics_frames(),"game_seconds":elapsed,"real_usec":Time.get_ticks_usec(),"position":[player.position.x,player.position.y],"weapon":str(controller.shoot_ability.weapon.id),"packet":controller.shoot_ability.packet_id,"energy":controller.actor_resources.stamina.current,"shots":controller.action_resources.shot_charges,"detail":extra})

func _toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	if paused: controller.router.clear("studio_pause")

func leave() -> void:
	controller.router.clear("studio_leave")
	controller.shoot_ability.reset()
	get_tree().paused = false
	home_requested.emit()

func _exit_tree() -> void:
	if is_instance_valid(controller):
		controller.shoot_ability.reset()
		controller.traversal.cancel()
		controller.air_focus_ability.stop()
	get_tree().paused = false

func _spawn_candidates() -> void:
	for index: int in 2:
		var motor: EnemyMotor = preload("res://scenes/enemies/patrol_drone.tscn").instantiate()
		var actor: EnemyActor = motor.get_node("Actor")
		actor.definition = load("res://resources/enemies/plains_sentry.tres" if index else "res://resources/enemies/plains_charger.tres").duplicate(true)
		actor.definition.stable_id = &"candidate_crosswind_moth" if index else &"candidate_lure_guard"
		actor.definition.aerial = index==1
		actor.definition.collision_size = Vector2(32,36)
		actor.definition.patrol_half_width = 100
		actor.definition.telegraph_duration = .8
		actor.definition.attack_duration = 1.1 if index else .65
		actor.definition.recovery_duration = 1.1
		var receiver := PrototypeEnemyDamageable.new()
		receiver.guard = index==0
		motor.get_node("Damageable").free()
		receiver.name = "Damageable"
		motor.add_child(receiver)
		actor.damageable = receiver
		motor.get_node("Presentation").free()
		var art := PrototypeEnemyPresentation.new()
		art.actor = actor
		art.moth = index==1
		art.name = "Presentation"
		motor.add_child(art)
		motor.position = Vector2(4780+index*330,602-index*140)
		add_child(motor)
		var id := StringName("studio_candidate_%s" % index)
		policy.bind_damageable(id,receiver,actor.health)
		actor.attack_behavior = PrototypeMothBehavior.new() if index else EnemyAttackBehavior.new()
		actor.add_child(actor.attack_behavior)
		actor.attack_behavior.configure(actor,controller,policy,lifetime,id,[])
		actors.append(actor)

func _spawn_bosses() -> void:
	for index: int in 3:
		var scene: PackedScene = [preload("res://scenes/bosses/clockwork_guardian.tscn"),preload("res://scenes/bosses/bellstrider.tscn"),preload("res://scenes/bosses/windkeeper.tscn")][index]
		var motor: BossMotor = scene.instantiate()
		motor.position = Vector2(5800+index*1050,555)
		add_child(motor)
		var boss: BossEncounter = motor.get_node("Encounter")
		boss.configure_arena(motor.position.x-350,motor.position.x+350,player)
		policy.bind_damageable(StringName("studio_boss_%s" % index),boss.damageable,boss.health)
		boss.activate()
		bosses.append(boss)
