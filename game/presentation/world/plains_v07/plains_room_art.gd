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
static var backgrounds: Dictionary={}
var occluders: Array[Dictionary]=[]
var terrain_polygons: Array[PackedVector2Array] = []
var story_props: Array[Dictionary]=[]
var rotating_props: Array[Dictionary]=[]
var hoist_cables: Array[Dictionary]=[]
var sky: Sprite2D
var sky_layers: PlainsSkyLayers
var landscape_scroll := Vector2(.12,.12)
var landscape_tracks_height := false
var landscape_offset := Vector2.ZERO
var authored_sky_palette := false
var daylight: DirectionalLight2D
var ambient: CanvasModulate
var indoor := false
var repair_blend := 0.0
var repair_initialized := false
var wind_phase := 0.0
static var profiles: Dictionary={}
var light_settings: Dictionary = {}
var environment_light: Dictionary = {}
var atmosphere: Dictionary = {}
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
	if props.is_empty():
		var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/plains_v07/manifest.json"))
		props=manifest.props
		backgrounds=manifest.get("backgrounds",{})
	name="RegionalArt"
	var air_material:=CanvasItemMaterial.new();air_material.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=air_material
	depth_reference=Vector2(FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units).size.x*.5,room.start_point.y-100)
	var interior:=room.interior_material()
	for hazard: Rect2 in room.hazards:
		for x: float in range(int(hazard.position.x),int(hazard.end.x),96):sprite("windchime_plains_hazard" if interior.is_empty() else "gear_city_hazard",Vector2(x+48,hazard.end.y),1)
	if not interior.is_empty() and not room.art_placements.any(func(p: Dictionary) -> bool: return p.get("backdrop",false)):
		var wall:=Sprite2D.new();wall.texture=load("res://assets/plains_v07/native/interior_"+interior+".png");wall.centered=false;wall.region_enabled=true;wall.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		wall.region_rect=Rect2(Vector2.ZERO,FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units).size+Vector2(1024,512));wall.position=Vector2(-512,-256);wall.z_index=-40;wall.modulate=Color(.8,.86,.95);add_child(wall)
		depths.append({"node":wall,"origin":wall.position,"ratio":1.0})
	indoor=not interior.is_empty()
	light_settings=JSON.parse_string(FileAccess.get_file_as_string("res://game/presentation/world/plains_v07/lighting.json"))
	environment_light=light_settings.environments.get(interior,light_settings.environments.outdoor).duplicate(true)
	for placement:Dictionary in room.art_placements:
		if placement.has("environment"):environment_light.merge(placement.environment,true)
	atmosphere=light_settings.atmospheres["indoor" if indoor else light_settings.profile_atmospheres.get(room.art_profile,"outdoor")].duplicate(true)
	for placement:Dictionary in room.art_placements:
		if placement.has("atmosphere"):atmosphere.merge(placement.atmosphere,true)
	ambient=CanvasModulate.new()
	ambient.color=Color(environment_light.ambient)
	add_child(ambient)
	if not indoor:
		sky=Sprite2D.new();sky.name="PlainsFarLandscape"
		var landscape:=room.art_profile
		for placement:Dictionary in room.art_placements:
			if placement.has("landscape"):landscape=str(placement.landscape)
		sky.texture=load("res://"+str(backgrounds[landscape if backgrounds.has(landscape) else "plains"].image))
		sky.z_index=-100;sky.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var sky_material:=CanvasItemMaterial.new();sky_material.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
		sky.material=sky_material
		add_child(sky)
		sky_layers=PlainsSkyLayers.new();sky.add_child(sky_layers)
		var cloud_asset: String="wind_clouds"
		for placement:Dictionary in room.art_placements:
			if placement.has("clouds"):cloud_asset=str(placement.clouds)
		sky_layers.configure(sky,load("res://"+str(backgrounds[cloud_asset].image)))
		for placement:Dictionary in room.art_placements:
			if placement.has("sky_cloud_density"):sky_layers.set_density(placement.sky_cloud_density)
			if placement.has("landscape_scroll"):
				landscape_scroll=FixedWorldProvider.point(placement.landscape_scroll)
				landscape_tracks_height=true
			if placement.has("landscape_reference"):depth_reference=FixedWorldProvider.point(placement.landscape_reference)
			if placement.has("landscape_offset"):landscape_offset=FixedWorldProvider.point(placement.landscape_offset)
			if placement.has("sky_colors"):
				sky_layers.set_colors(placement.sky_colors)
				authored_sky_palette=true
			if placement.has("cloud_wrap_fade"):sky_layers.set_wrap_fade(float(placement.cloud_wrap_fade))
		daylight=DirectionalLight2D.new();daylight.color=Color(light_settings.sun.color);daylight.energy=float(environment_light.sun_energy)
		# Open sky is a broad fill, not an infinitely projected shadow from every ledge.
		# Terrain still occludes the finite lamps and the player's carry light.
		daylight.rotation=float(light_settings.sun.rotation);daylight.shadow_enabled=false
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
	if room.rest_point!=Vector2.ZERO:
		for offset:Array in light_settings.station.offsets:
			var coil:=add_lamp(room.rest_point+FixedWorldProvider.point(offset))
			coil.color=Color(light_settings.station.color);coil.energy=float(light_settings.station.energy);coil.texture_scale=float(light_settings.station.radius)/64
	for placement: Dictionary in room.art_placements:
		if placement.has("masonry_region"): continue
		if placement.has("surface_platform"):
			var bounds:Array[Rect2]=[room.platforms[int(placement.surface_platform)]]
			for part:Rect2 in WorldRoomSpace.exposed_parts(bounds,room.boundary_art_rock):
				var surface:=PlainsTimberSurface.new();surface.bounds=part
				surface.z_index=0;add_child(surface)
			continue
		if placement.has("support_height"):
			_support(FixedWorldProvider.point(placement.point),float(placement.support_height));continue
		var node:=sprite(str(placement.asset),FixedWorldProvider.point(placement.point),int(placement.get("layer",-2)))
		if placement.has("facing_polygons"):
			PlainsArchitecturalFacing.attach(self,node,placement)
		if placement.has("tint"):
			var tone:Array=placement.tint;node.modulate=Color(tone[0],tone[1],tone[2],tone[3])
		if placement.has("haze"):
			var haze:Array=placement.haze
			var distant:=ShaderMaterial.new();distant.shader=preload("res://game/presentation/world/plains_v07/backdrop_haze.gdshader")
			distant.set_shader_parameter("haze",Color(haze[0],haze[1],haze[2],haze[3]));node.material=distant
		if placement.get("flip_h",false):node.flip_h=true
		if placement.has("rotation_speed"):
			# Rotate rigid machinery about its painted hub, preserving its authored footprint.
			node.position+=node.offset+node.texture.get_size()*.5
			node.offset=-node.texture.get_size()*.5
			rotating_props.append({"node":node,"speed":placement.rotation_speed,"source":placement.get("motion_source","")})
		if placement.has("tile_rect"):
			var area:=FixedWorldProvider.rect(placement.tile_rect)
			node.position=area.position;node.offset=Vector2.ZERO
			node.region_enabled=true;node.region_rect=Rect2(Vector2.ZERO,area.size)
			node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		if placement.has("curved_wall"):
			var shaft:Rect2=FixedWorldProvider.rect(placement.curved_wall)
			var curved:=ShaderMaterial.new();curved.shader=preload("res://game/presentation/world/plains_v07/well_wall_light.gdshader")
			curved.set_shader_parameter("shaft",Vector4(shaft.position.x,shaft.position.y,shaft.size.x,shaft.size.y));node.material=curved
		if placement.has("hoist_cable"):
			var carrier:=room.get_node_or_null(NodePath(str(placement.hoist_cable))) as WorldMovingPlatform
			if carrier!=null:
				var cable:=Line2D.new();cable.width=2;cable.default_color=Color("71674e");cable.z_index=-14;add_child(cable)
				hoist_cables.append({"line":cable,"carrier":carrier,"anchor":node.position+FixedWorldProvider.point(placement.get("cable_offset",[0,0]))})
		if placement.get("sway",false):
			var material:=ShaderMaterial.new();material.shader=preload("res://game/presentation/world/plains_v07/rooted_wind.gdshader")
			material.set_shader_parameter("height",float(node.texture.get_height()))
			material.set_shader_parameter("hanging",bool(placement.get("sway_hanging",false)))
			node.material=material;swaying.append(material)
		if placement.has("receipt"):
			node.hide();story_props.append({"node":node,"receipt":placement.receipt,"host":placement.get("story_host","")})
		if placement.get("fade_near",false):occluders.append({"node":node,"alpha":node.modulate.a})
		if placement.get("depth",1.0)!=1.0:
			node.modulate=Color(.66,.77,.78,.8)
			if placement.has("tint"):
				var tone:Array=placement.tint;node.modulate=Color(tone[0],tone[1],tone[2],tone[3])
			var depth_material:=CanvasItemMaterial.new();depth_material.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;node.material=depth_material
			depths.append({"node":node,"origin":node.position,"ratio":float(placement.depth)})
		if placement.get("light",false) and light_settings.emitters.has(str(placement.asset)):
			var source_settings:Dictionary=light_settings.emitters[str(placement.asset)]
			for emitter:Dictionary in source_settings.get("sources",[source_settings]):
				var glow:=add_lamp(FixedWorldProvider.point(emitter.offset))
				glow.color=Color(emitter.color);glow.energy=float(emitter.energy);glow.texture_scale=float(emitter.radius)/64
				glow.reparent(node,false)
				if placement.get("window_beam",false) and emitter.has("shaft"):
					PlainsWindowLight.attach(node,self,emitter.shaft)
	_thresholds()
	var spikes:=WorldSpikeArt.new()
	spikes.name="ContinuousSpikes"
	add_child(spikes)
	spikes.setup(room.spike_strips,room.platforms)
	set_process(true)
func add_lamp(at: Vector2) -> PointLight2D:
	var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)])
	var tex:=GradientTexture2D.new();tex.gradient=gradient;tex.width=128;tex.height=128;tex.fill=GradientTexture2D.FILL_RADIAL;tex.fill_from=Vector2(.5,.5);tex.fill_to=Vector2(1,.5)
	var light:=PointLight2D.new();light.texture=tex;light.position=at.round();light.color=Color("f1c27a");light.energy=1.25;light.texture_scale=2.8;light.shadow_enabled=true;light.shadow_filter=Light2D.SHADOW_FILTER_PCF5;light.shadow_filter_smooth=1.5;add_child(light)
	return light
func _process(delta: float) -> void:
	for cable:Dictionary in hoist_cables:
		cable.line.points=PackedVector2Array([cable.anchor,cable.carrier.position])
	clock+=delta
	for trace:Dictionary in rotating_props:
		var source:=room.get_node_or_null(str(trace.source)) as WorldMovingPlatform
		if source==null or source.motion_running:
			trace.node.rotation+=delta*float(trace.speed)
	if sky_layers!=null:sky_layers.update_clock(clock)
	if room.services!=null:
		var restored:=1.0 if room.services.state.has("clock_P") else 0.0
		if not repair_initialized:repair_blend=restored;repair_initialized=true
		repair_blend=move_toward(repair_blend,restored,delta*.25)
		ambient.color=Color(environment_light.ambient).lerp(Color(environment_light.restored),repair_blend)
		if daylight!=null:daylight.energy=lerpf(float(environment_light.sun_energy),float(environment_light.restored_sun_energy),repair_blend)
		if sky!=null:
			var land_tint:=Color(.84,.89,.92).lerp(Color(1,.98,.92),repair_blend)
			if authored_sky_palette:sky.self_modulate=land_tint
			else:sky.modulate=land_tint
		for trace: Dictionary in story_props:
			trace.node.visible=room.services.state.value.receipts.has(trace.receipt) and (str(trace.host).is_empty() or room.services.state.value.story_hosts.get(trace.host,"")==room.room_id)
			if trace.receipt=="repair_P":trace.node.modulate.a=repair_blend
		if player!=null:
			for entry: Dictionary in occluders:
				var prop:Sprite2D=entry.node
				prop.modulate.a=move_toward(prop.modulate.a,float(entry.alpha)*(.25 if player.global_position.distance_to(prop.global_position)<112 else 1.0),delta*3)

	wind_phase+=delta*float(atmosphere.sway_speed)*lerpf(1,1.35,repair_blend)
	for i: int in swaying.size():swaying[i].set_shader_parameter("phase",wind_phase+i*.73)
	var camera:=get_viewport().get_camera_2d()
	if camera!=null:
		if sky!=null:
			var span:=get_viewport_rect().size/camera.zoom
			var image_size:=sky.texture.get_size()
			var sky_height:=image_size.x*9.0/16.0
			var magnification:=ceilf(maxf(span.x/image_size.x,span.y/minf(image_size.y,sky_height)))
			sky.scale=Vector2.ONE*magnification
			var slack: Vector2=(image_size*magnification-span)*.5
			var offset: Vector2=(camera.get_screen_center_position()-depth_reference)*landscape_scroll+landscape_offset
			if landscape_tracks_height:
				# A high outlook reveals sky above the SAME distant horizon. Clouds
				# and sky fill stay viewport-wide even after the land leaves the frame.
				offset.x=clampf(offset.x,-slack.x,slack.x)
				offset.y=minf(offset.y,slack.y)
				sky_layers.position=offset/magnification
			else:
				offset=offset.clamp(-slack,slack)
				sky_layers.position=Vector2.ZERO
			sky.position=(camera.get_screen_center_position()-offset).round()
		for d: Dictionary in depths:d.node.position=(d.origin+(camera.global_position-depth_reference)*(1.0-float(d.ratio))).round()
	queue_redraw()
func _air_open(at: Vector2) -> bool:
	var inside:=false
	for area:Array in room.contract.world_geometry.space_rects:
		if FixedWorldProvider.rect(area).has_point(at):inside=true;break
	if not inside:return false
	for solid:Rect2 in room.platforms:
		if solid.has_point(at):return false
	for polygon:PackedVector2Array in terrain_polygons:
		if Geometry2D.is_point_in_polygon(at,polygon):return false
	return true

func _draw() -> void:
	if room==null:return
	var camera:=get_viewport().get_camera_2d()
	if camera==null:return
	var span:=get_viewport_rect().size/camera.zoom
	var view:=Rect2(camera.get_screen_center_position()-span/2,span).grow(8)
	for cy:int in range(floori(view.position.y/192)-1,ceili(view.end.y/192)+1):
		for cx:int in range(floori(view.position.x/256)-1,ceili(view.end.x/256)+1):
			var rng:=RandomNumberGenerator.new();rng.seed=hash(room.room_id+str(cx)+":"+str(cy))
			for i:int in int(atmosphere.density):
				var speed:=rng.randf_range(float(atmosphere.speed[0]),float(atmosphere.speed[1]))
				var phase:=rng.randf_range(0,256)
				var travel:=fposmod(phase+clock*speed,256)
				var at:=Vector2(cx*256+travel,cy*192+rng.randf_range(0,192)+sin(clock*1.4+phase)*5).round()
				if not view.has_point(at) or not _air_open(at):continue
				var fade:=minf(1,minf(travel/28,(256-travel)/28))
				var alpha:=rng.randf_range(.5,.9)*fade
				var tail:=3 if indoor else rng.randi_range(4,8)
				for x:int in tail:
					var point:=at-Vector2(x,0)
					if _air_open(point):draw_rect(Rect2(point,Vector2.ONE),Color(1,.91,.64,alpha*(1-float(x)/tail)*.55))
				draw_rect(Rect2(at,Vector2(2,1)),Color(1,.98,.82,alpha))

func _support(base: Vector2,height: float) -> void:
	# Painted stone caps and grass have irregular alpha edges. Embed the footing
	# and overlap the beam underside without changing the physical surfaces.
	base.y += 3
	height += 5
	var texture: Texture2D=load("res://assets/plains_v07/native/plain_pier.png")
	var width:=texture.get_width()
	var top:=base.y-height
	# Decorative piers sit behind the route: opaque atmospheric color, no solid-wall contrast.
	var backdrop:=ShaderMaterial.new()
	backdrop.shader=preload("res://game/presentation/world/plains_v07/backdrop_haze.gdshader")
	backdrop.set_shader_parameter("haze",Color(.43,.53,.52,.68))
	var pieces: Array[Rect2]=[Rect2(0,0,width,20)]
	var remaining:=height-40
	while remaining>0:
		var step:=minf(remaining,texture.get_height()-40)
		pieces.append(Rect2(0,20,width,step));remaining-=step
	pieces.append(Rect2(0,texture.get_height()-20,width,20))
	for rect: Rect2 in pieces:
		var part:=Sprite2D.new();var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=rect
		part.texture=atlas;part.centered=false;part.position=Vector2(base.x-width*.5,top).round();part.z_index=-4
		part.material=backdrop;part.modulate=Color(.9,.95,.95);part.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(part);top+=rect.size.y

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
		if door.get("front_door",false):continue
		if room.art_placements.any(func(p:Dictionary)->bool: return p.get("threshold_for","")==str(door.id)):continue
		var other_indoor:=not FixedWorldRoom.material_for_profile(_scene_profile(str(door.target_scene))).is_empty()
		if indoor==other_indoor:continue
		var at:=FixedWorldProvider.point(door.position_candidate.local_world_units)
		var direction: String=door.direction
		var marker:=Node2D.new();marker.name="Threshold_"+str(door.id).replace(":","_");add_child(marker)
		if not indoor and direction in ["left","right"]:
			# An authored facade already includes this doorway and its supporting bank.
			var side:=1 if direction=="right" else -1
			PlainsThresholdComposition.outside(self,at,side,str(door.id))
		elif not indoor and direction=="down":
			var ground:=at.y
			for solid: Rect2 in room.platforms:
				if solid.position.y>=at.y-240 and solid.position.y<ground and (absf(solid.end.x-at.x)<96 or absf(solid.position.x-at.x)<96):ground=solid.position.y
			var lip:=sprite("well_threshold",Vector2(at.x,ground+72),-2);lip.set_meta("connection",door.id)
		else:
			# Outside light enters only through the real aperture, never as an indoor landscape.
			var into:=Vector2.RIGHT if direction=="left" else Vector2.LEFT if direction=="right" else Vector2.DOWN if direction=="up" else Vector2.UP
			var glow:=add_lamp(at+into*12-Vector2(0,44) if direction in ["left","right"] else at+into*24)
			glow.color=Color("c9dfcf");glow.energy=float(environment_light.get("threshold_energy",.75));glow.texture_scale=2.6
			var beam:=Polygon2D.new();beam.z_index=-20
			if direction in ["left","right"]:
				beam.polygon=PackedVector2Array([at-Vector2(0,96),at,at+into*160,at+into*112-Vector2(0,96)])
			else:beam.polygon=PackedVector2Array([at-Vector2(64,0),at+Vector2(64,0),at+Vector2(90,0)+into*160,at-Vector2(90,0)+into*160])
			var opacity:=float(environment_light.get("threshold_opacity",.3))
			beam.vertex_colors=PackedColorArray([Color(.74,.85,.75,opacity),Color(.74,.85,.75,opacity),Color(.74,.85,.75,0),Color(.74,.85,.75,0)])
			add_child(beam)
