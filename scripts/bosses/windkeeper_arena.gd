class_name WindkeeperArena
extends Node
## Stage III physically breaks the middle ground, with selective segment return.
var module: PlatformingModule
var encounter: WindkeeperEncounter
var controller: PlayerController
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var segment: SegmentRespawn
var supports: PlainsGroundSupports
var broken := false
var _fall: DemoContactEmitter

func setup(owner_module: PlatformingModule, boss_encounter: WindkeeperEncounter, player_controller: PlayerController, damage_policy: FrameDamagePolicy, life: DemoLifetime, respawn: SegmentRespawn, ground: PlainsGroundSupports = null) -> void:
	module = owner_module
	encounter = boss_encounter
	controller = player_controller
	policy = damage_policy
	lifetime = life
	segment = respawn
	supports = ground
	encounter.phase_changed.connect(_phase_changed)
	controller.shoot_ability.shot_fired.connect(func(_aim:Vector2,shot_id:int)->void:encounter.register_rune_shot(controller.session_id,shot_id))
	_fall = DemoContactEmitter.new()
	_fall.top_level = true
	_fall.policy = policy
	_fall.controller = controller
	_fall.source_id = &"windkeeper_broken_bridge_fall"
	_fall.kind = DamageRequest.Kind.ENVIRONMENT
	_fall.position = module.to_global(Vector2(645,685))
	_fall.half_size = Vector2(355,95)
	_fall.enabled = false
	add_child(_fall)
	for index: int in 3:
		segment.add_anchor(StringName("windkeeper_bridge_%s" % index),module.to_global([Vector2(350,452),Vector2(640,452),Vector2(870,452)][index]))

func _phase_changed(phase: int) -> void:
	if phase == 3 and not broken: _break_ground.call_deferred()

func _break_ground() -> void:
	if not is_instance_valid(module) or not lifetime.active: return
	broken = true
	# Scene definitions are unique per PlatformingModule; this is explicit Boss
	# lifecycle geometry, not a fresh random map or a whole-stage reset.
	var old := module.get_node("Platform0") as StaticBody2D
	old.collision_layer = 0
	module.definition.platforms[0] = Rect2(0,600,290,80)
	module.definition.platforms.append(Rect2(1000,600,120,80))
	for rect: Rect2 in [Rect2(0,600,290,80),Rect2(1000,600,120,80)]:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		body.add_child(shape)
		module.add_child(body)
	if is_instance_valid(supports):
		var left := module.global_position.x + 290
		var right := module.global_position.x + 1000
		var pieces: Array[Rect2] = []
		for column: Rect2 in supports.columns:
			if column.end.x <= left or column.position.x >= right or column.position.y < module.global_position.y + 600:
				pieces.append(column)
			else:
				if column.position.x < left: pieces.append(Rect2(column.position,Vector2(left-column.position.x,column.size.y)))
				if column.end.x > right: pieces.append(Rect2(Vector2(right,column.position.y),Vector2(column.end.x-right,column.size.y)))
		for child: Node in supports.get_children():
			if child is StaticBody2D: child.collision_layer = 0
			child.queue_free()
		supports.install(pieces)
	if module.get_parent() is PlainsRegionAssembler:
		var assembler:PlainsRegionAssembler=module.get_parent()
		PlainsTerrainSkin.configure_ground_edges(assembler.modules,supports.columns if is_instance_valid(supports) else [])
		if is_instance_valid(supports):supports.configure_edges(assembler.modules)
	else:
		module.ground_surface_regions.erase(0)
		module.exposed_surface_edges.clear()
	module.queue_redraw()
	_fall.enabled = true
	# Pick a genuinely safe bridge start near the player's current segment.
	var local_x := module.to_local(controller.motor.global_position).x
	var index := 0 if local_x < 550 else (1 if local_x < 810 else 2)
	segment.activate_anchor(StringName("windkeeper_bridge_%s" % index))

func _physics_process(_delta: float) -> void:
	if not lifetime.active or not controller.active or not controller.motor.is_on_floor(): return
	if (encounter.definition as WindkeeperDefinition).platform_trials and encounter.stage_phase==3:
		encounter.rune_platform=-1
		var feet:Vector2=module.to_local(controller.motor.global_position)+Vector2(0,18)
		for index:int in 3:
			var slab:Rect2=module.definition.platforms[index+1]
			if absf(feet.y-slab.position.y)<2 and feet.x-12>=slab.position.x and feet.x+12<=slab.end.x:encounter.rune_platform=index
	if not broken:return
	for index: int in 3:
		var anchor := module.to_global([Vector2(350,452),Vector2(640,452),Vector2(870,452)][index])
		if controller.motor.global_position.distance_to(anchor) < 45: segment.activate_anchor(StringName("windkeeper_bridge_%s" % index))
