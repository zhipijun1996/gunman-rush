class_name DemoStage
extends Node2D

# Fixed development layout, deliberately independent from the random generator.
const BOSS := preload("res://scenes/bosses/clockwork_guardian.tscn")
const ROOM_MARKERS := {
	&"shop": {"text": "SHOP / 5 RUN COINS", "color": Color(0.65, 0.85, 1.0)},
	&"item_reward": {"text": "ITEMS / CHOOSE ONE", "color": Color(0.77, 0.6, 1.0)},
	&"coin_reward": {"text": "COINS / CLAIM REWARD", "color": Color(1.0, 0.8, 0.3)},
	&"health_reward": {"text": "HEALTH / RESTORE 2 HP", "color": Color(0.4, 0.95, 0.6)},
}
const PATROL := preload("res://scenes/enemies/patrol_drone.tscn")
var stage_type: StringName
var stage_index := 1
var enemy: EnemyMotor
var boss: Node2D
var exits: Array = []
var completed := false
var supply_claimed := false
var reward_available := false
var clock := 0.0
var spawn := Vector2(100, 580)
var supply_position := Vector2(240, 560)
var anchor_position := Vector2(660, 580)
var reward_position := Vector2(550, 560)
var hazard_position := Vector2(820, 580)
var exit_positions: Array[Vector2] = [Vector2(1130, 465), Vector2(1130, 565)]
var _exit_labels: Array[Label] = []
var _supply_label: Label

func configure(index: int, type_id: StringName, offers: Array) -> void:
	stage_index = index
	stage_type = type_id
	exits = offers

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if stage_type not in [&"combat", &"boss"] and not ROOM_MARKERS.has(stage_type):
		push_error("Unsupported fixed demo stage type: %s" % stage_type)
		get_tree().quit(1)
		return
	add_platform(Rect2(-80, 600, 840, 150))
	add_platform(Rect2(870, 600, 500, 150))
	add_platform(Rect2(300, 490, 140, 18))
	add_platform(Rect2(580, 425, 145, 18))
	add_platform(Rect2(1000, 500, 220, 18))
	add_platform(Rect2(-40, -400, 40, 1000))
	add_platform(Rect2(1280, -400, 40, 1000))
	_sign(Vector2(75, 540), "ENTRY / SAFE START")
	_sign(Vector2(615, 545), "SEGMENT ANCHOR", Color(0.45, 0.9, 0.85))
	_supply_label = _sign(supply_position + Vector2(-55, -45), "SUPPLY +2 HP", Color(0.35, 0.95, 0.65))
	_sign(Vector2(735, 510), "GAP / HAZARD\nJUMP + RECOIL", Color(0.95, 0.48, 0.34))
	if stage_type == &"combat":
		enemy = PATROL.instantiate()
		enemy.position = Vector2(510, 580)
		add_child(enemy)
		_sign(Vector2(410, 535), "DEFEAT THE DRONE")
	elif stage_type == &"boss":
		boss = BOSS.instantiate() as Node2D
		boss.position = Vector2(1030, 560)
		add_child(boss)
		_sign(Vector2(400, 340), "CLOCKWORK GUARDIAN\nDODGE, AIM, RELEASE", Color(0.95, 0.75, 0.35))
	if ROOM_MARKERS.has(stage_type):
		var marker: Dictionary = ROOM_MARKERS[stage_type]
		_sign(reward_position + Vector2(-90, -70), marker.text, marker.color)
	for i: int in exits.size():
		var label := _sign(exit_positions[i] + Vector2(-100, -28), "LOCKED", Color(0.55, 0.6, 0.7))
		_exit_labels.append(label)
	queue_redraw()

func set_completed(value: bool) -> void:
	completed = value
	for i: int in _exit_labels.size():
		_exit_labels[i].text = "%s / INTERACT" % exits[i].label if value else "LOCKED / COMPLETE ROOM"
		_exit_labels[i].modulate = Color(0.45, 0.95, 0.75) if value else Color(0.55, 0.6, 0.7)
	queue_redraw()

func mark_supply_used() -> void:
	supply_claimed = true
	_supply_label.text = "SUPPLY / USED"
	_supply_label.modulate = Color(0.4, 0.5, 0.5)
	queue_redraw()

func _physics_process(delta: float) -> void:
	clock += delta
	hazard_position.y = 580 + sin(clock * 2.0) * 12
	queue_redraw()

func nearby_exit(location: Vector2) -> int:
	for i: int in exits.size():
		if location.distance_to(exit_positions[i]) < 95:
			return i
	return -1

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.055, 0.075, 0.105), false, 2)
	for x: int in range(80, 1280, 150):
		draw_line(Vector2(x, 250), Vector2(x, 590), Color(0.1, 0.14, 0.18), 3)
	draw_circle(anchor_position, 13, Color(0.3, 0.75, 0.7))
	draw_circle(supply_position, 13, Color(0.25, 0.7, 0.45) if not supply_claimed else Color(0.2, 0.25, 0.25))
	for i: int in range(12):
		var a := float(i) / 12.0 * TAU + clock
		var inner := hazard_position + Vector2.from_angle(a) * 19
		var tip := hazard_position + Vector2.from_angle(a + 0.12) * 30
		var end := hazard_position + Vector2.from_angle(a + 0.38) * 19
		draw_colored_polygon(PackedVector2Array([inner, tip, end]), Color(0.9, 0.35, 0.25))
	for i: int in exits.size():
		_draw_exit_icon(exit_positions[i] + Vector2(-125, -25), exits[i].icon_id)
		draw_rect(Rect2(exit_positions[i] - Vector2(18, 35), Vector2(36, 55)), Color(0.3, 0.7, 0.6) if completed else Color(0.25, 0.29, 0.35), false, 3)
	if reward_available or ROOM_MARKERS.has(stage_type):
		var tint: Color = ROOM_MARKERS[stage_type].color if ROOM_MARKERS.has(stage_type) else Color(1.0, 0.8, 0.3)
		draw_circle(reward_position, 18, tint)

func add_platform(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	var visual := Polygon2D.new()
	var h := rect.size / 2
	visual.polygon = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
	visual.color = Color(0.19, 0.25, 0.31)
	body.add_child(visual)
	add_child(body)

func _sign(location: Vector2, text: String, tint := Color(0.68, 0.75, 0.82)) -> Label:
	var label := Label.new()
	label.position = location
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = tint
	add_child(label)
	return label

func _draw_exit_icon(center: Vector2, id: StringName) -> void:
	var tint := Color(0.4, 0.9, 0.75) if completed else Color(0.5, 0.55, 0.65)
	if id == &"shop":
		draw_rect(Rect2(center - Vector2(10, 8), Vector2(20, 16)), tint, false, 2)
		draw_line(center + Vector2(-12, -10), center + Vector2(12, -10), tint, 3)
	elif id == &"coin_reward":
		draw_circle(center, 10, tint, false, 2)
		draw_line(center + Vector2(0, -6), center + Vector2(0, 6), tint, 2)
	elif id == &"health_reward":
		draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), tint, 4)
		draw_line(center + Vector2(0, -10), center + Vector2(0, 10), tint, 4)
	elif id == &"boss":
		draw_circle(center, 9, tint, false, 2)
		draw_line(center + Vector2(-5, -5), center + Vector2(5, 5), tint, 2)
		draw_line(center + Vector2(-5, 5), center + Vector2(5, -5), tint, 2)
	else:
		draw_polyline(PackedVector2Array([center + Vector2(0, -11), center + Vector2(9, 0), center + Vector2(0, 11), center + Vector2(-9, 0), center + Vector2(0, -11)]), tint, 2)
