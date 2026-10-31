class_name PixelPlainsBackdrop
extends WindchimeBackdrop
const DISTANCE:=preload("res://assets/pixel_plains/dawn_distance.png")
var effects_enabled:=true
var light_enabled:=true
var _phase:=0.0
func _ready() -> void:texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	_phase+=delta
	queue_redraw()
func _draw() -> void:
	draw_texture_rect(DISTANCE,Rect2(0,0,640,360),false)
	# A second, quiet near-mist plane. All offsets are logical pixels.
	if middle_enabled:
		for i: int in 5:
			var x:=fposmod(i*173+(_phase*1.2 if effects_enabled else 0),800)-100
			draw_rect(Rect2(floorf(x),224+i%3*23,160+i%2*50,2),Color(.42,.62,.59,.09))
	if light_enabled:
		draw_colored_polygon(PackedVector2Array([Vector2(548,122),Vector2(568,122),Vector2(350,360),Vector2(288,360)]),Color(.93,.76,.53,.045))
		draw_colored_polygon(PackedVector2Array([Vector2(570,130),Vector2(576,130),Vector2(400,360),Vector2(376,360)]),Color(.93,.76,.53,.035))
