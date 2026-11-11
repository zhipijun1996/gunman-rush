class_name PlainsSkyLayers
extends Node2D
## Sky and moving cloud veils sit behind the fixed landscape's transparent horizon.
var clouds: Array[Sprite2D] = []
var sky_gradient: Gradient

func configure(landscape: Sprite2D, cloud_texture: Texture2D) -> void:
	# A tall land plate must not stretch its clouds or shift the sky gradient.
	var size:=Vector2(landscape.texture.get_width(),landscape.texture.get_width()*9.0/16.0)
	var gradient:=Gradient.new()
	sky_gradient=gradient
	gradient.colors=PackedColorArray([Color("dec9aa"),Color("fae7c3")])
	var wash:=GradientTexture2D.new()
	wash.gradient=gradient;wash.width=int(size.x);wash.height=int(size.y)
	wash.fill_from=Vector2.ZERO;wash.fill_to=Vector2(0,.8)
	var sky:=Sprite2D.new();sky.name="SkyWash";sky.texture=wash;sky.z_index=-3
	var unlit:=CanvasItemMaterial.new();unlit.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;sky.material=unlit
	add_child(sky)
	for i:int in 2:
		var cloud:=Sprite2D.new();cloud.name="CloudVeil"+str(i)
		cloud.texture=cloud_texture;cloud.scale=size/cloud_texture.get_size()
		cloud.position.y=float(i)*size.y*.055;cloud.z_index=-2+i
		cloud.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var shader:=ShaderMaterial.new()
		shader.shader=preload("res://game/presentation/world/plains_v07/cloud_drift.gdshader")
		shader.set_shader_parameter("speed",.006 if i==0 else .0035)
		shader.set_shader_parameter("phase",0.0 if i==0 else .47)
		shader.set_shader_parameter("density",.72 if i==0 else .32)
		cloud.material=shader;add_child(cloud);clouds.append(cloud)

func set_wrap_fade(amount: float) -> void:
	for cloud:Sprite2D in clouds:
		(cloud.material as ShaderMaterial).set_shader_parameter("wrap_fade",amount)

func set_colors(values: Array) -> void:
	if values.size()==2:
		sky_gradient.colors=PackedColorArray([Color(str(values[0])),Color(str(values[1]))])

func set_density(values: Array) -> void:
	for i: int in mini(values.size(), clouds.size()):
		(clouds[i].material as ShaderMaterial).set_shader_parameter("density",clampf(float(values[i]),0.0,1.0))
		clouds[i].visible=float(values[i])>0

func update_clock(seconds: float) -> void:
	for cloud:Sprite2D in clouds:
		(cloud.material as ShaderMaterial).set_shader_parameter("cloud_time",seconds)
