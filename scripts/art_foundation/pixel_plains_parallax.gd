class_name PixelPlainsParallax
extends CanvasLayer
## Three independent original source images. No shared flattened backdrop.
const TEXTURES: Array[Texture2D] = [preload("res://assets/pixel_plains/parallax_far.png"),preload("res://assets/pixel_plains/parallax_middle.png"),preload("res://assets/pixel_plains/parallax_near.png")]
const RATES: Array[Vector2] = [Vector2(.035,.015),Vector2(.12,.04),Vector2(.28,.075)]
var surface: Node2D
var panels: Array[Sprite2D] = []
var origin := Vector2.ZERO
var camera_offset := Vector2.ZERO

func _ready() -> void:
	layer = -100
	surface = Node2D.new()
	add_child(surface)
	for i: int in 3:
		for copy: int in 3:
			var panel := Sprite2D.new()
			panel.name = ["FarSky","MiddleBellRuins","NearMeadow"][i]+str(copy)
			panel.centered = false
			panel.texture = TEXTURES[i]
			panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if i>0:
				var material := ShaderMaterial.new()
				material.shader = preload("res://shaders/pixel_parallax_edge.gdshader")
				material.set_shader_parameter("mist",.30 if i==1 else .16)
				panel.material = material
			surface.add_child(panel)
			panels.append(panel)
	_update()

func _process(_delta: float) -> void:
	_update()

func _update() -> void:
	var size := get_viewport().get_visible_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := camera.get_screen_center_position() if camera != null else origin
	camera_offset = center-origin
	for i: int in 3:
		var width: float = size.x*[1.5,1.8,1.5][i]
		# Preserve desktop width-driven scale; tall viewports need real source
		# height too. Even-pixel copy widths prevent fractional repeat gaps.
		var minimum_height: float = size.y*[1.20,.85,.62][i]
		var factor: float = maxf(width/TEXTURES[i].get_width(),minimum_height/TEXTURES[i].get_height())
		width = ceilf(TEXTURES[i].get_width()*factor/2.0)*2.0
		factor = width/TEXTURES[i].get_width()
		var height: float = TEXTURES[i].get_height()*factor
		var drift := camera_offset*RATES[i]
		var x: float = fposmod(-drift.x,width)-width
		var y: float = size.y-height if i==0 else size.y*.81-height*.90 if i==1 else size.y*1.20-height
		y -= clampf(drift.y,-size.y*.10,size.y*.10)
		for copy: int in 3:
			var panel := panels[i*3+copy]
			panel.position = Vector2(x+copy*width,y).snapped(Vector2(2,2))
			# Far sky stops at its coverage limits. Its vertical speed is therefore
			# constant only inside that interval, never across arbitrary Y travel.
			if i==0: panel.position.y=clampf(panel.position.y,size.y-height,0)
			panel.scale = Vector2.ONE*factor

func measured_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in 3:
		result.append({"layer":["far","middle","near"][i],"texture_path":TEXTURES[i].resource_path,"texture_sha256":FileAccess.get_sha256(TEXTURES[i].resource_path),"camera_coefficient":[RATES[i].x,RATES[i].y],"unwrapped_offset":[-camera_offset.x*RATES[i].x,-camera_offset.y*RATES[i].y],"screen_position":[panels[i*3].position.x,panels[i*3].position.y],"visible":visible})
	return result
