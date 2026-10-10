class_name PlatformingModule
extends Node2D

@export var definition: PlatformingModuleDefinition
var clock := 0.0
var hazards: Array[ModuleSawHazard] = []
var moving_platforms: Array[ModuleMovingPlatform] = []

func _ready() -> void:
	if definition == null or not definition.is_valid():
		push_error("Platforming module requires a valid authored definition")
		get_tree().quit(1)
		return
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = -200
	# Each scene owns its authored data; runtime experiments never mutate siblings.
	definition = definition.duplicate(true) as PlatformingModuleDefinition
	for index: int in definition.platforms.size():
		var rect := definition.platforms[index]
		var body := StaticBody2D.new()
		body.name = "Platform%d" % index
		body.position = rect.get_center()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		body.add_child(shape)
		add_child(body)
	for saw_definition: ModuleSawDefinition in definition.saws:
		var hazard := ModuleSawHazard.new()
		hazard.name = str(saw_definition.source_id)
		hazard.definition = saw_definition
		hazard.module = self
		hazards.append(hazard)
		add_child(hazard)
	for ferry_definition: ModuleMovingPlatformDefinition in definition.ferries:
		var ferry := ModuleMovingPlatform.new()
		ferry.name = str(ferry_definition.platform_id)
		ferry.definition = ferry_definition
		ferry.module = self
		moving_platforms.append(ferry)
		add_child(ferry)
	queue_redraw()

func _physics_process(delta: float) -> void:
	clock += delta

func setup_damage(controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime) -> void:
	for hazard: ModuleSawHazard in hazards:
		hazard.setup_damage(controller, policy, lifetime)

func world_entry() -> Vector2:
	return to_global(definition.entry_port.position)

func world_exit() -> Vector2:
	return to_global(definition.exit_port.position)

func world_anchors() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point: Vector2 in definition.anchors:
		result.append(to_global(point))
	return result

func world_dangers() -> Array[Rect2]:
	var result := world_static_dangers()
	for saw: ModuleSawDefinition in definition.saws:
		var envelope := saw.envelope()
		result.append(Rect2(to_global(envelope.position), envelope.size))
	return result

func world_static_dangers() -> Array[Rect2]:
	var result: Array[Rect2] = []
	# Authored modules are translated only; rotating gravity geometry is forbidden.
	for rect: Rect2 in definition.danger_bounds:
		result.append(Rect2(to_global(rect.position), rect.size))
	return result

func port_accepts(port: PlatformingModulePort, motor: PlayerMotor) -> bool:
	if port == null or motor == null or motor.tuning == null or not port.is_valid() or not motor.is_on_floor() or not motor.global_position.is_finite():
		return false
	if motor.global_position.distance_to(to_global(port.position)) > 48.0 or not motor.normal_velocity.is_finite() or not motor.recoil_velocity.is_finite():
		return false
	if not is_finite(motor.recoil_burst_remaining) or motor.recoil_burst_remaining > 0.0:
		return false
	if motor.normal_velocity.length() > port.max_normal_speed + 0.01 or motor.recoil_velocity.length() > port.max_recoil_speed + 0.01:
		return false
	var controller := motor.get_node_or_null("Controller") as PlayerController
	if controller == null or not controller.active or controller.shoot_ability == null:
		return false
	if not is_finite(controller.shoot_ability.cooldown_remaining) or controller.shoot_ability.cooldown_remaining > port.max_shot_cooldown + 1.0e-9:
		return false
	var available_jumps := maxi(0, motor.tuning.max_jumps - controller.jump_ability.used_jumps) if controller.jump_ability.enabled else 0
	var available_shots := controller.action_resources.shot_charges if controller.shoot_ability.enabled else 0
	return available_jumps >= port.min_jumps and available_shots >= port.min_air_shots

func _draw() -> void:
	if definition == null:
		return
	draw_rect(definition.world_bounds, Color("101c29"))
	for rect: Rect2 in definition.platforms:
		draw_rect(rect, Color("35485b"))
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("a8c8c8"), 3.0)
	for danger: Rect2 in definition.danger_bounds:
		draw_rect(danger, Color("bd574b"))
		for x: float in range(int(danger.position.x), int(danger.end.x), 24):
			draw_line(Vector2(x, danger.end.y), Vector2(x + 12, danger.position.y), Color("ffc18b"), 2)
	for saw: ModuleSawDefinition in definition.saws:
		draw_line(saw.origin - saw.travel, saw.origin + saw.travel, Color("b67862"), 2)
	for ferry: ModuleMovingPlatformDefinition in definition.ferries:
		draw_line(ferry.start, ferry.finish, Color("548281"), 2)
	for anchor: Vector2 in definition.anchors:
		draw_circle(anchor, 6.0, Color("62999c"))
	_draw_port(definition.entry_port, Color("69d0c6"))
	_draw_port(definition.exit_port, Color("f1ca78"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(40, 66), str(definition.module_id).to_upper().replace("_", " "), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("cadbdd"))
	if not definition.saws.is_empty():
		draw_string(font, Vector2(360, 280), "WAIT / WATCH / CROSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f1ca78"))
	if not definition.ferries.is_empty():
		draw_string(font, Vector2(360, 310), "JUMP ON / RIDE / STEP OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("9ef2d5"))
	if definition.requires_burst:
		draw_string(font, Vector2(300, 330), "AIM DOWN / RECOIL UP", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f1ca78"))
		draw_line(Vector2(440, 480), Vector2(440, 390), Color("f1ca78"), 3)
		draw_line(Vector2(440, 390), Vector2(430, 405), Color("f1ca78"), 3)
		draw_line(Vector2(440, 390), Vector2(450, 405), Color("f1ca78"), 3)
	if definition.module_id == &"square_loop":
		draw_string(font, Vector2(180, 310), "UPPER / OPTIONAL PLATFORM ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("9ef2d5"))
		draw_string(font, Vector2(390, 565), "LOWER / WALK TO REJOIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f1ca78"))
		draw_line(Vector2(350, 575), Vector2(970, 575), Color("548281"), 2)
		draw_line(Vector2(970, 575), Vector2(950, 565), Color("548281"), 2)
	if definition.module_id == &"boss_approach":
		draw_string(font, Vector2(220, 430), "SAFE APPROACH / NO AUTOMATIC REFILL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("9ef2d5"))
		draw_line(Vector2(890, 350), Vector2(890, 600), Color("f1ca78"), 3)
		draw_string(font, Vector2(900, 390), "BOSS BOUNDARY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f1ca78"))

func _draw_port(port: PlatformingModulePort, color: Color) -> void:
	draw_arc(port.position, 24, 0, TAU, 24, color, 2)
	draw_line(port.position, port.position + port.direction * 32, color, 3)
	draw_string(ThemeDB.fallback_font, port.position + Vector2(-28, -38), str(port.port_id).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
