extends Node2D

const PLAYER := preload("res://scenes/player/player.tscn")
var player: PlayerMotor

func _ready() -> void:
	for rect: Rect2 in [Rect2(0, 630, 520, 50), Rect2(650, 630, 630, 50), Rect2(200, 525, 140, 20), Rect2(380, 425, 140, 20), Rect2(800, 545, 200, 20), Rect2(1080, 460, 30, 170), Rect2(800, 470, 200, 20)]:
		add_platform(rect)
	player = PLAYER.instantiate()
	player.position = Vector2(90, 600)
	add_child(player)
	var label := Label.new()
	label.position = Vector2(28, 25)
	label.text = "GUNMAN RUSH / CORE-01 GRAYBOX\nA/D or arrows: move    Space: jump    R: reset\nMovement / gap / stepped platforms / low ceiling / wall\nShooting, touch controls and final art follow later tasks."
	add_child(label)

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
	visual.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	visual.color = Color(0.22, 0.28, 0.32)
	body.add_child(visual)
	add_child(body)

func _physics_process(_delta: float) -> void:
	if player.position.y > 900:
		(player.get_node("Controller") as PlayerController).reset_at(Vector2(90, 600))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		(player.get_node("Controller") as PlayerController).reset_at(Vector2(90, 600))
