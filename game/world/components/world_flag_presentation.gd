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
	if active:
		PixelVfx.arc(self,Vector2.ZERO,27,PI*.12,PI*.88,Color(.9,.75,.4,.5))
		PixelVfx.glint(self,Vector2(0,-28),2,Color("f0d9a0"),.6)
	draw_texture_rect(UnderworldActors.icon_texture(&"bell"),Rect2(-12,-24,24,36),false,Color.WHITE if active else Color(.4,.4,.4))
