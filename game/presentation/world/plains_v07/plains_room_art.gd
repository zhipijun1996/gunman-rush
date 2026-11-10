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
var terrain_polygons: Array[PackedVector2Array] = []
var story_props: Array[Dictionary]=[]
var sky: Sprite2D
var daylight: DirectionalLight2D
var ambient: CanvasModulate
var indoor := false
var repair_blend := 0.0
var repair_initialized := false
var wind_phase := 0.0
var motes: Array[Dictionary]=[]
var room_span:=Vector2.ZERO
static var profiles: Dictionary={}
func sprite(id: String,at: Vector2,layer: int=-2) -> Sprite2D:
	var node:=Sprite2D.new();node.centered=false
	if props.has(id):
		node.texture=load("res://"+str(props[id].image));node.offset=Vector2(-node.texture.get_width()*.5,-node.texture.get_height())
	else:
		var spec: Dictionary=assets.sprites[id]
		node.texture=load("res://art/world-art-v2/"+str(spec.file));node.offset=-Vector2(float(spec.pivotX),float(spec.pivotY))
	node.position=at.round();node.z_index=layer
	if props.has(id): node.position.y += float(props[id].get("ground_embed_world_units",0))
	node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(node)
	return node
func _ready() -> void:
	if assets.is_empty():assets=JSON.parse_string(FileAccess.get_file_as_string("res://art/world-art-v2/assets/pixel/manifest.json"))
	if props.is_empty():props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/plains_v07/manifest.json")).props
	name="RegionalArt"
	depth_reference=Vector2(FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units).size.x*.5,room.start_point.y-100)
	var interior:=room.interior_material()
	for hazard: Rect2 in room.hazards:
		for x: float in range(int(hazard.position.x),int(hazard.end.x),96):sprite("windchime_plains_hazard" if interior.is_empty() else "gear_city_hazard",Vector2(x+48,hazard.end.y),1)
	if not interior.is_empty():
		var wall:=Sprite2D.new();wall.texture=load("res://assets/plains_v07/native/interior_"+interior+".png");wall.centered=false;wall.region_enabled=true;wall.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		wall.region_rect=Rect2(Vector2.ZERO,FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units).size+Vector2(1024,512));wall.position=Vector2(-512,-256);wall.z_index=-40;wall.modulate=Color(.8,.86,.95);add_child(wall)
		depths.append({"node":wall,"origin":wall.position,"ratio":.92})
	indoor=not interior.is_empty()
	room_span=FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units).size
	_seed_motes()
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
	for row: Dictionary in room.terrain_polygons:
		var points := PackedVector2Array()
		for pair: Array in row.points: points.append(FixedWorldProvider.point(pair))
		terrain_polygons.append(points)
		var blocker := LightOccluder2D.new()
		var polygon := OccluderPolygon2D.new()
		polygon.polygon = points
		blocker.occluder = polygon
		add_child(blocker)
	if room.rest_point!=Vector2.ZERO:add_lamp(room.rest_point-Vector2(0,42))
	for placement: Dictionary in room.art_placements:
		if placement.has("support_height"):
			_support(FixedWorldProvider.point(placement.point),float(placement.support_height));continue
		var node:=sprite(str(placement.asset),FixedWorldProvider.point(placement.point),int(placement.get("layer",-2)))
		if placement.has("tile_rect"):
			var area:=FixedWorldProvider.rect(placement.tile_rect)
			node.position=area.position;node.offset=Vector2.ZERO
			node.region_enabled=true;node.region_rect=Rect2(Vector2.ZERO,area.size)
			node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
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
			var light_position:=FixedWorldProvider.point(placement.light_offset) if placement.has("light_offset") else Vector2(0,-node.texture.get_height()*.65)
			var glow:=add_lamp(light_position)
			glow.reparent(node,false)
	_thresholds()
	var spikes:=WorldSpikeArt.new()
	spikes.name="ContinuousSpikes"
	add_child(spikes)
	spikes.setup(room.spike_strips,room.platforms)
	set_process(true)
func add_lamp(at: Vector2) -> PointLight2D:
	var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)])
	var tex:=GradientTexture2D.new();tex.gradient=gradient;tex.width=128;tex.height=128;tex.fill=GradientTexture2D.FILL_RADIAL;tex.fill_from=Vector2(.5,.5);tex.fill_to=Vector2(1,.5)
	var light:=PointLight2D.new();light.texture=tex;light.position=at.round();light.color=Color("f1c27a");light.energy=.65;light.texture_scale=2.0;light.shadow_enabled=true;add_child(light)
	return light
func _process(delta: float) -> void:
	clock+=delta
	if room.services!=null:
		var restored:=1.0 if room.services.state.has("clock_P") else 0.0
		if not repair_initialized:repair_blend=restored;repair_initialized=true
		repair_blend=move_toward(repair_blend,restored,delta*.25)
		ambient.color=(Color(.66,.71,.80) if indoor else Color(.62,.68,.78)).lerp(Color(.76,.79,.83),repair_blend)
		if daylight!=null:daylight.energy=lerpf(.42,.55,repair_blend)
		if sky!=null:sky.modulate=Color(.84,.89,.92).lerp(Color(1,.98,.92),repair_blend)
		for trace: Dictionary in story_props:
			trace.node.visible=room.services.state.value.receipts.has(trace.receipt) and (str(trace.host).is_empty() or room.services.state.value.story_hosts.get(trace.host,"")==room.room_id)
			if trace.receipt=="repair_P":trace.node.modulate.a=repair_blend
		if player!=null:
			for prop: Sprite2D in occluders:prop.modulate.a=move_toward(prop.modulate.a,.25 if player.global_position.distance_to(prop.global_position)<112 else 1.0,delta*3)

	wind_phase+=delta*lerpf(1.1,1.7,repair_blend)
	for i: int in swaying.size():swaying[i].set_shader_parameter("phase",wind_phase+i*.73)
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
func _seed_motes() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=hash(room.room_id+":air")
	var count:=clampi(int(room_span.x*room_span.y/(42000 if indoor else 25000)),12,180)
	var clusters: Array[Vector2]=[]
	for _i: int in 6:clusters.append(Vector2(rng.randf_range(0,room_span.x),rng.randf_range(0,room_span.y)))
	for i: int in count:
		var at:=Vector2(rng.randf_range(0,room_span.x),rng.randf_range(0,room_span.y))
		if rng.randf()<.55:at=clusters[rng.randi_range(0,5)]+Vector2(rng.randfn(0,170),rng.randfn(0,110))
		motes.append({"origin":at,"speed":rng.randf_range(5,13) if indoor else rng.randf_range(22,48),"life":rng.randf_range(6,15),"phase":rng.randf_range(0,30),"sway":rng.randf_range(2,11),"alpha":rng.randf_range(.25,.72),"size":1 if rng.randf()<.72 else 2})

func _draw() -> void:
	if room==null:return
	var camera:=get_viewport().get_camera_2d()
	if camera==null:return
	var span:=get_viewport_rect().size/camera.zoom
	var view:=Rect2(camera.get_screen_center_position()-span/2,span).grow(8)
	for mote: Dictionary in motes:
		var age:=fposmod(clock+mote.phase,mote.life)/float(mote.life)
		var fade:=minf(age*7,(1-age)*7)
		var at: Vector2=mote.origin+Vector2(clock*mote.speed+sin(clock*.4+mote.phase)*mote.sway,sin(clock*.7+mote.phase)*mote.sway)
		at=Vector2(fposmod(at.x,room_span.x),fposmod(at.y,room_span.y)).round()
		if not view.has_point(at):continue
		var blocked:=false
		for solid: Rect2 in room.platforms:
			if solid.has_point(at):blocked=true;break
		if not blocked:
			for polygon: PackedVector2Array in terrain_polygons:
				if Geometry2D.is_point_in_polygon(at, polygon): blocked=true;break
		if not blocked:
			draw_rect(Rect2(at,Vector2(mote.size,1)),Color(1,.92,.68,mote.alpha*clampf(fade,0,1)))

func _support(base: Vector2,height: float) -> void:
	# Painted stone caps and grass have irregular alpha edges. Embed the footing
	# and overlap the beam underside without changing the physical surfaces.
	base.y += 3
	height += 5
	var texture: Texture2D=load("res://assets/plains_v07/native/plain_pier.png")
	var width:=texture.get_width()
	var top:=base.y-height
	var pieces: Array[Rect2]=[Rect2(0,0,width,20)]
	var remaining:=height-40
	while remaining>0:
		var step:=minf(remaining,texture.get_height()-40)
		pieces.append(Rect2(0,20,width,step));remaining-=step
	pieces.append(Rect2(0,texture.get_height()-20,width,20))
	for rect: Rect2 in pieces:
		var part:=Sprite2D.new();var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=rect
		part.texture=atlas;part.centered=false;part.position=Vector2(base.x-width*.5,top).round();part.z_index=-4
		part.modulate=Color(.72,.78,.82);part.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(part);top+=rect.size.y

static func _scene_profile(path: String) -> String:
	if not profiles.has(path):
		var scene:=load(path) as PackedScene
		var state:=scene.get_state();var profile:=""
		for i: int in state.get_node_property_count(0):
			if state.get_node_property_name(0,i)==&"art_profile":profile=str(state.get_node_property_value(0,i))
		profiles[path]=profile
	return profiles[path]

func _thresholds() -> void:
	for door: Dictionary in room.doors:
		var other_indoor:=not FixedWorldRoom.material_for_profile(_scene_profile(str(door.target_scene))).is_empty()
		if indoor==other_indoor:continue
		var at:=FixedWorldProvider.point(door.position_candidate.local_world_units)
		var direction: String=door.direction
		var marker:=Node2D.new();marker.name="Threshold_"+str(door.id).replace(":","_");add_child(marker)
		if not indoor and direction in ["left","right"]:
			var side:=1 if direction=="right" else -1
			var facade:=sprite("building_threshold",at-Vector2(side*24,0),-3)
			facade.scale.x=side;facade.set_meta("connection",door.id)
			var lamp:=add_lamp(at-Vector2(side*48,55));lamp.energy=.32
		elif not indoor and direction=="down":
			var ground:=at.y
			for solid: Rect2 in room.platforms:
				if solid.position.y>=at.y-240 and solid.position.y<ground and (absf(solid.end.x-at.x)<96 or absf(solid.position.x-at.x)<96):ground=solid.position.y
			var lip:=sprite("well_threshold",Vector2(at.x,ground+72),-2);lip.set_meta("connection",door.id)
		else:
			# Outside light enters only through the real aperture, never as an indoor landscape.
			var into:=Vector2.RIGHT if direction=="left" else Vector2.LEFT if direction=="right" else Vector2.DOWN if direction=="up" else Vector2.UP
			var glow:=add_lamp(at+into*12-Vector2(0,44) if direction in ["left","right"] else at+into*24)
			glow.color=Color("c9dfcf");glow.energy=.75;glow.texture_scale=2.6
			var beam:=Polygon2D.new();beam.z_index=-20
			if direction in ["left","right"]:
				beam.polygon=PackedVector2Array([at-Vector2(0,96),at,at+into*160,at+into*112-Vector2(0,96)])
			else:beam.polygon=PackedVector2Array([at-Vector2(64,0),at+Vector2(64,0),at+Vector2(90,0)+into*160,at-Vector2(90,0)+into*160])
			beam.vertex_colors=PackedColorArray([Color(.74,.85,.75,.3),Color(.74,.85,.75,.3),Color(.74,.85,.75,0),Color(.74,.85,.75,0)])
			add_child(beam)
