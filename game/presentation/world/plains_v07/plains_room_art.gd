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
	var indoor: String={"mill":"mill","barn":"barn","cellar":"cellar","secret":"cellar","well":"well"}.get(room.art_profile,"")
	if not indoor.is_empty():
		var wall:=Sprite2D.new();wall.texture=load("res://assets/plains_v07/native/interior_"+indoor+".png");wall.centered=false;wall.region_enabled=true;wall.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		wall.region_rect=Rect2(Vector2.ZERO,FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units).size+Vector2(1024,512));wall.position=Vector2(-512,-256);wall.z_index=-40;wall.modulate=Color(.8,.86,.95);add_child(wall)
		depths.append({"node":wall,"origin":wall.position,"ratio":.92})
	var ambient:=CanvasModulate.new();ambient.color=Color(.83,.89,.92) if not indoor.is_empty() else Color(.94,.97,1);add_child(ambient)
	for i: int in room.platforms.size():
		if i in room.one_way_indices:continue
		var platform: Rect2=room.platforms[i]
		var blocker:=LightOccluder2D.new();var polygon:=OccluderPolygon2D.new()
		polygon.polygon=PackedVector2Array([platform.position,Vector2(platform.end.x,platform.position.y),platform.end,Vector2(platform.position.x,platform.end.y)])
		blocker.occluder=polygon;add_child(blocker)
	if room.rest_point!=Vector2.ZERO:add_lamp(room.rest_point-Vector2(0,42))
	var count:=0
	# Only exposed surfaces receive attached vegetation. No plants inside solids.
	for platform: Rect2 in room.platforms:
		if not indoor.is_empty():continue
		if platform.size.x<96 or platform.size.y<24 or platform.position.y<96:continue
		for x: float in [platform.position.x+48,platform.end.x-48]:
			var at:=Vector2(x,platform.position.y)
			var buried:=false
			for other: Rect2 in room.platforms:
				if other!=platform and other.has_point(at-Vector2(0,8)):buried=true;break
			for danger: Rect2 in room.hazards:
				if danger.grow(40).has_point(at):buried=true
			if buried:continue
			if room.rest_point.distance_to(at)<100 or room.reward_point.distance_to(at)<80:continue
			var grass:=sprite("plains_grass",at+Vector2(0,1),2)
			var material:=ShaderMaterial.new();material.shader=preload("res://game/presentation/world/plains_v07/rooted_wind.gdshader");material.set_shader_parameter("height",float(grass.texture.get_height()));grass.material=material
			swaying.append(material);count+=1
	for placement: Dictionary in room.art_placements:
		var node:=sprite(str(placement.asset),FixedWorldProvider.point(placement.point),int(placement.get("layer",-2)))
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
		for d: Dictionary in depths:d.node.position=(d.origin+(camera.global_position-depth_reference)*(1.0-float(d.ratio))).round()
	queue_redraw()
func _draw() -> void:
	if room==null:return
	var camera:=get_viewport().get_camera_2d()
	if camera==null:return
	var center:=camera.get_screen_center_position();var span:=get_viewport_rect().size/camera.zoom
	for i: int in 18:
		var point:=Vector2(fposmod(i*137.0+clock*(19+i%3*6),span.x),fposmod(i*61.0+sin(clock+i)*4,span.y))+center-span/2
		var blocked:=false
		for solid: Rect2 in room.platforms:
			if solid.has_point(point):blocked=true;break
		if not blocked:
			draw_rect(Rect2(point.round(),Vector2(2,1)),Color(1,.91,.64,.65))
			draw_line(point.round()-Vector2(4,0),point.round(),Color(1,.88,.6,.2),1)
