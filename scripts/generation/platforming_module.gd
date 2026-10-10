class_name PlatformingModule
extends Node2D

@export var definition: PlatformingModuleDefinition

func _ready() -> void:
	if definition == null or not definition.is_valid():
		push_error("Platforming module requires a valid authored definition")
		get_tree().quit(1)
		return
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
	queue_redraw()

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
	for anchor: Vector2 in definition.anchors:
		draw_circle(anchor, 6.0, Color("62999c"))
	_draw_port(definition.entry_port, Color("69d0c6"))
	_draw_port(definition.exit_port, Color("f1ca78"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(40, 66), str(definition.module_id).to_upper().replace("_", " "), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("cadbdd"))
	if definition.requires_burst:
		draw_string(font, Vector2(300, 330), "AIM DOWN / RECOIL UP", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f1ca78"))
		draw_line(Vector2(440, 480), Vector2(440, 390), Color("f1ca78"), 3)
		draw_line(Vector2(440, 390), Vector2(430, 405), Color("f1ca78"), 3)
		draw_line(Vector2(440, 390), Vector2(450, 405), Color("f1ca78"), 3)

func _draw_port(port: PlatformingModulePort, color: Color) -> void:
	draw_arc(port.position, 24, 0, TAU, 24, color, 2)
	draw_line(port.position, port.position + port.direction * 32, color, 3)
	draw_string(ThemeDB.fallback_font, port.position + Vector2(-28, -38), str(port.port_id).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
