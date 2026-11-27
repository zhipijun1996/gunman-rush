class_name EmberSpentShell
extends StaticBody2D
## The discarded plate stays on the marked terrace until this fight is unloaded.
const OUTLINE := [Vector2(-38,0),Vector2(-32,-13),Vector2(-17,-25),Vector2(2,-31),Vector2(22,-23),Vector2(38,0)]
var player: PlayerController
var shape := CollisionPolygon2D.new()

func _ready() -> void:
	collision_layer=0
	collision_mask=0
	shape.polygon=OUTLINE
	add_child(shape)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or not player.active: return
	var body := player.motor.get_node("CollisionShape2D") as CollisionShape2D
	if (body.global_transform*body.shape.get_rect()).intersects(Rect2(global_position-Vector2(39,32),Vector2(78,32))): return
	collision_layer=1
	set_physics_process(false)

func _draw() -> void:
	draw_colored_polygon(OUTLINE,Color("#322b36"))
	draw_polyline(OUTLINE,Color("#785659"),3)
	draw_line(Vector2(-25,-9),Vector2(-6,-19),Color("#cd7047"),3)
	draw_line(Vector2(-6,-19),Vector2(17,-15),Color("#8f574c"),2)
