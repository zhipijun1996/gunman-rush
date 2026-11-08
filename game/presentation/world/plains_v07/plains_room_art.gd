class_name PlainsRoomArt
extends Node2D
## Region material/depth composition consumes authored geometry; owns no collision.
var room: FixedWorldRoom
var player: Node2D
var clock:=0.0
var swaying: Array[ShaderMaterial]=[]
var depth_reference := Vector2.ZERO
var depths: Array[Dictionary]=[]
static var assets: Dictionary={}
static var props: Dictionary={}
var occluders: Array[Sprite2D]=[]
var story_props: Array[Dictionary]=[]
var sky: Sprite2D
var daylight: DirectionalLight2D
var ambient: CanvasModulate
var indoor := false
func sprite(id: String,at: Vector2,layer: int=-2) -> Sprite2D:
	var node:=Sprite2D.new();node.centered=false
	if props.has(id):
		node.texture=load("res://"+str(props[id].image));node.offset=Vector2(-node.texture.get_width()*.5,-node.texture.get_height())
	else:
		var spec: Dictionary=assets.sprites[id]
		node.texture=load("res://art/world-art-v2/"+str(spec.file));node.offset=-Vector2(float(spec.pivotX),float(spec.pivotY))
	node.position=at.round();node.z_index=layer
	node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(node)
	return node
func _ready() -> void:
	if assets.is_empty():assets=JSON.parse_string(FileAccess.get_file_as_string("res://art/world-art-v2/assets/pixel/manifest.json"))
	if props.is_empty():props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/plains_v07/manifest.json")).props
	name="RegionalArt"
	depth_reference=Vector2(FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units).size.x*.5,room.start_point.y-100)
	for hazard: Rect2 in room.hazards:
		for x: float in range(int(hazard.position.x),int(hazard.end.x),96):sprite("windchime_plains_hazard",Vector2(x+48,hazard.end.y),1)
	var interior: String={"mill":"mill","barn":"barn","cellar":"cellar","secret":"cellar","well":"well"}.get(room.art_profile,"")
	if not interior.is_empty():
		var wall:=Sprite2D.new();wall.texture=load("res://assets/plains_v07/native/interior_"+interior+".png");wall.centered=false;wall.region_enabled=true;wall.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		wall.region_rect=Rect2(Vector2.ZERO,FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units).size+Vector2(1024,512));wall.position=Vector2(-512,-256);wall.z_index=-40;wall.modulate=Color(.8,.86,.95);add_child(wall)
		depths.append({"node":wall,"origin":wall.position,"ratio":.92})
	indoor=not interior.is_empty()
	ambient=CanvasModulate.new()
	ambient.color=Color(.66,.71,.80) if indoor else Color(.62,.68,.78)
	add_child(ambient)
	if not indoor:
		sky=Sprite2D.new();sky.name="PlainsFarLandscape"
		sky.texture=load("res://art/world-art-v2/"+str(assets.backgrounds.windchime_plains_v2.file))
		sky.z_index=-100;sky.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var unlit:=CanvasItemMaterial.new();unlit.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;sky.material=unlit
		add_child(sky)
		daylight=DirectionalLight2D.new();daylight.color=Color("ffdfac");daylight.energy=.42
		daylight.rotation=-.55;daylight.shadow_enabled=true;daylight.max_distance=1200
		add_child(daylight)
	for i: int in room.platforms.size():
		if i in room.one_way_indices:continue
		var platform: Rect2=room.platforms[i]
		if not indoor and (platform.position.y==0 or platform.size.x<=32):continue
		var blocker:=LightOccluder2D.new();var polygon:=OccluderPolygon2D.new()
		polygon.polygon=PackedVector2Array([platform.position,Vector2(platform.end.x,platform.position.y),platform.end,Vector2(platform.position.x,platform.end.y)])
		blocker.occluder=polygon;add_child(blocker)
	if room.rest_point!=Vector2.ZERO:add_lamp(room.rest_point-Vector2(0,42))
	for placement: Dictionary in room.art_placements:
		var node:=sprite(str(placement.asset),FixedWorldProvider.point(placement.point),int(placement.get("layer",-2)))
		if placement.get("sway",false):
			var material:=ShaderMaterial.new();material.shader=preload("res://game/presentation/world/plains_v07/rooted_wind.gdshader")
			material.set_shader_parameter("height",float(node.texture.get_height()));node.material=material;swaying.append(material)
		if placement.has("receipt"):
			node.hide();story_props.append({"node":node,"receipt":placement.receipt,"host":placement.get("story_host","")})
		if placement.get("fade_near",false):occluders.append(node)
		if placement.get("depth",1.0)!=1.0:
			node.modulate=Color(.66,.77,.78,.8)
			depths.append({"node":node,"origin":node.position,"ratio":float(placement.depth)})
		if placement.get("light",false):
			var glow:=add_lamp(Vector2(0,-node.texture.get_height()*.65))
			glow.reparent(node,false)
	set_process(true)
func add_lamp(at: Vector2) -> PointLight2D:
	var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)])
	var tex:=GradientTexture2D.new();tex.gradient=gradient;tex.width=128;tex.height=128;tex.fill=GradientTexture2D.FILL_RADIAL;tex.fill_from=Vector2(.5,.5);tex.fill_to=Vector2(1,.5)
	var light:=PointLight2D.new();light.texture=tex;light.position=at.round();light.color=Color("f1c27a");light.energy=.65;light.texture_scale=2.0;light.shadow_enabled=true;add_child(light)
	return light
func _process(delta: float) -> void:
	clock+=delta
	if room.services!=null:
		for trace: Dictionary in story_props:
			trace.node.visible=room.services.state.value.receipts.has(trace.receipt) and (str(trace.host).is_empty() or room.services.state.value.story_hosts.get(trace.host,"")==room.room_id)
		if player!=null:
			for prop: Sprite2D in occluders:prop.modulate.a=move_toward(prop.modulate.a,.25 if player.global_position.distance_to(prop.global_position)<112 else 1.0,delta*3)

	for i: int in swaying.size():swaying[i].set_shader_parameter("phase",clock*1.7+i*.73)
	var camera:=get_viewport().get_camera_2d()
	if camera!=null:
		if sky!=null:
			var span:=get_viewport_rect().size/camera.zoom
			var image_size:=sky.texture.get_size()
			var magnification:=ceilf(maxf(span.x/image_size.x,span.y/image_size.y))
			sky.scale=Vector2.ONE*magnification
			var slack: Vector2=(image_size*magnification-span)*.5
			var offset: Vector2=(camera.get_screen_center_position()-depth_reference)*.12
			sky.position=(camera.get_screen_center_position()-offset.clamp(-slack,slack)).round()
		for d: Dictionary in depths:d.node.position=(d.origin+(camera.global_position-depth_reference)*(1.0-float(d.ratio))).round()
	queue_redraw()
func _draw() -> void:
	if room==null:return
	var camera:=get_viewport().get_camera_2d()
	if camera==null:return
	var center:=camera.get_screen_center_position();var span:=get_viewport_rect().size/camera.zoom
	var particle_count:=clampi(int(span.x*span.y/13500),18,42)
	for i: int in particle_count:
		var speed:=8.0+i%3*3 if indoor else 32.0+i%3*11
		var point:=Vector2(fposmod(i*137.0+clock*speed,span.x),fposmod(i*61.0+sin(clock+i)*4,span.y))+center-span/2
		var blocked:=false
		for solid: Rect2 in room.platforms:
			if solid.has_point(point):blocked=true;break
		if not blocked:
			var at:=point.round()
			if not indoor and i%3==0:
				# Seed husks retain a dark edge against the bright sky at phone scale.
				draw_line(at-Vector2(12,1),at,Color(.49,.44,.28,.42),1)
				draw_rect(Rect2(at-Vector2(1,1),Vector2(5,3)),Color(.43,.38,.22,.78))
				draw_rect(Rect2(at,Vector2(3,1)),Color(1,.94,.72,.95))
			else:
				draw_rect(Rect2(at,Vector2(2,1)),Color(1,.94,.72,.8))
				if not indoor:draw_line(at-Vector2(7,1),at,Color(1,.91,.7,.3),1)
