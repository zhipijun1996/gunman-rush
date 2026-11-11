class_name PlainsWindowLight
extends Node2D
## One fixed architectural opening owns its light shaft and suspended dust.
var art: PlainsRoomArt
var outline: PackedVector2Array
var tone: Color
var amount := 0
var clock := 0.0

static func attach(window: Sprite2D, host: PlainsRoomArt, settings: Dictionary) -> void:
	var effect:=PlainsWindowLight.new()
	effect.name="WindowDaylight";effect.art=host
	for point:Array in settings.polygon:effect.outline.append(FixedWorldProvider.point(point))
	var rgb:Array=settings.color;effect.tone=Color(rgb[0],rgb[1],rgb[2]);effect.amount=int(settings.motes)
	effect.z_index=1
	window.add_child(effect)
	var shaft:=Polygon2D.new();shaft.name="DaylightVolume";shaft.polygon=effect.outline
	var white:=GradientTexture2D.new();var gradient:=Gradient.new()
	gradient.colors=PackedColorArray([Color.WHITE,Color.WHITE]);white.gradient=gradient;white.width=2;white.height=2
	shaft.texture=white;shaft.uv=PackedVector2Array([Vector2(0,0),Vector2(2,0),Vector2(2,2),Vector2(0,2)])
	var shader:=ShaderMaterial.new();shader.shader=preload("res://game/presentation/world/plains_v07/window_shaft.gdshader")
	shader.set_shader_parameter("light_color",Vector3(rgb[0],rgb[1],rgb[2]));shader.set_shader_parameter("opacity",float(settings.opacity))
	shaft.material=shader;effect.add_child(shaft)
	var unlit:=CanvasItemMaterial.new();unlit.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;effect.material=unlit

func _process(delta:float)->void:
	clock+=delta;queue_redraw()

func _draw()->void:
	if outline.size()!=4:return
	for i:int in amount:
		var travel:=fposmod(float(i)*.6180339+clock*(.007+float(i%4)*.002),1)
		var across:=.15+fposmod(float(i)*.381966+sin(clock*.3+i)*.035,.7)
		var left:=outline[0].lerp(outline[3],travel)
		var right:=outline[1].lerp(outline[2],travel)
		var point:=left.lerp(right,across).round()
		if not art._air_open(art.to_local(to_global(point))):continue
		var alpha:=sin(travel*PI)*(.3+float(i%3)*.12)
		draw_rect(Rect2(point,Vector2.ONE),Color(tone,alpha))
		if i%5==0:draw_rect(Rect2(point+Vector2(-1,-1),Vector2.ONE),Color(tone,alpha*.35))
