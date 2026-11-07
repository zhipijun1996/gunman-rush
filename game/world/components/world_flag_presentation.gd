class_name WorldFlagPresentation
extends Node2D
## Local presentation queries a committed fact. It cannot award or change that fact.
@export var flag: String
var query: Callable
var active:=false
func bind(value: Callable) -> void:
	query=value
func _process(_delta: float) -> void:
	var next:=bool(query.call(flag)) if query.is_valid() else false
	if next!=active: active=next;queue_redraw()
func _draw() -> void:
	draw_line(Vector2(-24,-32),Vector2(-24,18),Color("77654c"),5)
	draw_line(Vector2(24,-32),Vector2(24,18),Color("77654c"),5)
	draw_line(Vector2(-26,-32),Vector2(26,-32),Color("b19a65"),5)
	if active: draw_circle(Vector2.ZERO,28,Color(.9,.75,.4,.3))
	draw_texture_rect(UnderworldActors.icon_texture(&"bell"),Rect2(-12,-24,24,36),false,Color.WHITE if active else Color(.4,.4,.4))
