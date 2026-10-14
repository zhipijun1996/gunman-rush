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
var training_actors: Array[EnemyActor] = []
var _last_entity_signature := ""
var _weapon_picker: OptionButton
var input_values: Dictionary = {}
var section := 0
var _hud: Label
var _solids: Array[Rect2] = []
var _events: Array[Dictionary] = []
var training_static := false
var _training_toggle: Button
var _training_sample_time := 0.0
var elapsed := 0.0
var paused := false
var menu_pointer_block := 0

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
	for point: Vector2 in [Vector2(1770,406),Vector2(2110,335),Vector2(2390,360),Vector2(1490,190),Vector2(1570,240)]:
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
	_spawn_training()
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
	var weapon_row := HBoxContainer.new();box.add_child(weapon_row)
	_weapon_picker=OptionButton.new();_weapon_picker.custom_minimum_size=Vector2(250,34)
	for i: int in WeaponCatalog.IDS.size():
		var definition := WeaponCatalog.get_loadout(i)
		_weapon_picker.add_item("Lv.%s %s" % [definition.tier,definition.display_name],i)
	weapon_row.add_child(_weapon_picker)
	var popup_touch := PopupTouchAdapter.new()
	popup_touch.popup = _weapon_picker.get_popup()
	popup_touch.forwarded.connect(func(value: StringName) -> void: _record(&"popup_touch",{"phase":String(value)}))
	_weapon_picker.get_popup().add_child(popup_touch)
	_weapon_picker.get_popup().about_to_popup.connect(func() -> void: controller.router.clear("weapon_menu_open"))
	_weapon_picker.get_popup().popup_hide.connect(func() -> void:
		controller.router.clear("weapon_menu_close")
		menu_pointer_block = int(Input.get_mouse_button_mask())
		_record(&"weapon_menu_closed",{"mouse_mask":menu_pointer_block})
		# Closing by clicking outside must consume that click, not arm a shot.
		get_viewport().set_input_as_handled())
	_weapon_picker.item_selected.connect(func(index: int)->void:
		var definition := WeaponCatalog.get_loadout(index)
		# Choosing the current loadout must not cancel the current attack.
		if definition.id == controller.shoot_ability.weapon.id: return
		if controller.shoot_ability.equip(definition):_record(&"weapon_equipped",{"tier":controller.shoot_ability.weapon.tier}))
	_button(weapon_row,"武器靶场",func()->void:restart(4))
	var hint := Label.new();hint.text="F / X 召回·遥爆  |  Q / Y 技能";hint.add_theme_color_override("font_color",DemoMenu.TEXT);weapon_row.add_child(hint)
	_training_toggle = Button.new()
	_training_toggle.text = "敌人：巡逻"
	_training_toggle.custom_minimum_size = Vector2(140,36)
	_training_toggle.pressed.connect(func() -> void: set_training_static(not training_static))
	weapon_row.add_child(_training_toggle)
	controller.shoot_ability.shot_rejected.connect(func(reason: StringName)->void:_record(&"attack_rejected",{"reason":String(reason)}))
	controller.shoot_ability.behavior().entity_transition.connect(func(entity: WeaponEntity,value: StringName)->void:_record(&"weapon_entity_transition",{"kind":String(entity.kind),"state":String(value),"packet":entity.packet}))
	controller.shoot_ability.behavior().phase_changed.connect(func(value: StringName)->void:_record(&"weapon_phase",{"phase":String(value)}))
	controller.shoot_ability.packet_changed.connect(func(value: StringName,packet: int)->void:_record(&"weapon_packet",{"state":String(value),"packet":packet}))
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
	lifetime.active=true
	policy.protect_player()
	controller.reset_at([Vector2(150,602),Vector2(810,602),Vector2(1490,400),Vector2(2580,602),Vector2(150,602)][index])
	if index==4:
		for target: EnemyActor in training_actors:
			target.reset(&"practice_only")
			var contact := target.motor.get_node("Contact") as DemoContactEmitter
			contact.enabled=true
	controller.router.grapple_available = true
	camera.position = player.position+Vector2(130,-100)
	_record(&"practice_reset",{"section":index})

func _process(delta: float) -> void:
	if get_tree().paused: return
	elapsed += delta
	camera.position = camera.position.lerp(player.position+Vector2(130,-100),1-exp(-delta*5))
	_hud.text = "动作练习 · %s · 二跳 %d / 钩索 %d / 爬墙
精力 %.0f · 空中攻击 %d · %s" % [controller.shoot_ability.weapon.display_name,mini(1,maxi(0,controller.jump_ability.maximum_jumps()-controller.jump_ability.used_jumps)),0 if controller.traversal.hook_used else 1,controller.actor_resources.stamina.current,controller.action_resources.shot_charges,"已倒下，点击重试" if not controller.active else "A/D移动 · Space跳跃 · 松开左键射击 · 右键/E钩索"]
	if _events.size() > 4096: _events.pop_front()
	var signature := ""
	var entity_states: Array[Dictionary]=[]
	for entity: WeaponEntity in controller.shoot_ability.behavior().current_entities():
		signature+="%s/%s/%s;" % [entity.kind,entity.phase,entity.serial]
		entity_states.append({"kind":String(entity.kind),"phase":String(entity.phase),"position":[entity.global_position.x,entity.global_position.y]})
	if signature!=_last_entity_signature:
		_last_entity_signature=signature;_record(&"weapon_entities",{"entities":entity_states})
	var def := controller.shoot_ability.weapon
	_hud.text+=" · 共鸣 %.0f / %.0f%s%s" % [controller.combat_energy.current,controller.combat_energy.definition.capacity," · 战技 %s（%.0f共鸣）" % [def.skill_name,def.skill_cost] if def.tier==3 else ""," · 控刃/F召回" if controller.router.aim_mode==&"steer_blade" else " · 选择弹射方向" if controller.router.aim_mode==&"singularity_launch" else ""]
	for i: int in WeaponCatalog.IDS.size():
		if String(def.id)==WeaponCatalog.IDS[i]:
			# Popup focus belongs to pointer/touch/key navigation until it closes.
			# Re-selecting even the same item resets PopupMenu focus every frame.
			if not _weapon_picker.get_popup().visible and _weapon_picker.selected != i:
				_weapon_picker.select(i)
			break
	if OS.has_feature("web") and elapsed >= _training_sample_time:
		_training_sample_time = elapsed+1.0
		var positions: Array = []
		for target: EnemyActor in training_actors:
			positions.append([target.motor.position.x,target.motor.position.y])
		_record(&"training_motion",{"static":training_static,"positions":positions})
	queue_redraw()

func _button(row: Container, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(90,36)
	button.pressed.connect(action)
	row.add_child(button)

func _record(action: StringName, extra: Dictionary) -> void:
	var event := {"action":str(action),"physics_tick":Engine.get_physics_frames(),"game_seconds":elapsed,"real_usec":Time.get_ticks_usec(),"position":[player.position.x,player.position.y],"weapon":str(controller.shoot_ability.weapon.id),"packet":controller.shoot_ability.packet_id,"energy":controller.actor_resources.stamina.current,"combat":controller.combat_energy.current,"recoil_speed":controller.motor.recoil_velocity.length(),"shots":controller.action_resources.shot_charges,"detail":extra}
	_events.append(event)
	if OS.has_feature("web"):print("STUDIO_EVENT "+JSON.stringify(event))

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

func _spawn_training() -> void:
	for i: int in 4:
		var motor: EnemyMotor=preload("res://scenes/enemies/patrol_drone.tscn").instantiate()
		var actor: EnemyActor=motor.get_node("Actor")
		actor.definition=preload("res://resources/enemies/patrol_drone.tres").duplicate(true)
		actor.definition.health_definition.max_health=120;actor.definition.health_definition.initial_current=120
		motor.position=Vector2(340+i*120,596)
		add_child(motor)
		var id := StringName("studio_training_%s" % i)
		policy.bind_damageable(id,actor.damageable,actor.health)
		actor.bind_encounter(controller,policy,lifetime,id,[])
		if actor.attack_behavior!=null:actor.attack_behavior.queue_free();actor.attack_behavior=null
		var contact := DemoContactEmitter.new();contact.name="Contact";contact.policy=policy;contact.controller=controller;contact.source_id=id;contact.half_size=actor.definition.collision_size/2;motor.add_child(contact)
		actor.defeated.connect(func(_actor: EnemyActor)->void:contact.enabled=false)
		training_actors.append(actor)

func set_training_static(value: bool) -> void:
	training_static = value
	var base: EnemyDefinition = preload("res://resources/enemies/patrol_drone.tres")
	for target: EnemyActor in training_actors:
		target.definition.patrol_speed = 0.0 if value else base.patrol_speed
		target.definition.patrol_half_width = 0.0 if value else base.patrol_half_width
	if _training_toggle != null:
		_training_toggle.text = "敌人：静止靶" if value else "敌人：巡逻"
	restart(4)
	_record(&"training_mode",{"static":value})

