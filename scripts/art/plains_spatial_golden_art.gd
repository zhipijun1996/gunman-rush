class_name PlainsSpatialGoldenArt
extends Node2D
## A finite kit assembled from the exact collision polygons and authoring anchors.
## This renderer never invents platforms, edits collision, or advances gameplay RNG.
const PAINT := preload("res://assets/plains_v8/painted_limestone_material.png")
const STONE := preload("res://assets/plains_v3/terrain/organic_cliff_fill.png")
const RIDGE := preload("res://assets/region_production_v3/spaces/distant_limestone_ridge_v1/source.png")
const ATMOSPHERE := preload("res://scripts/art/distant_plains.gdshader")
const SKY := preload("res://assets/plains_v3/background_layers/sky.png")
const STONE_SHADER := preload("res://scripts/art/spatial_golden_terrain.gdshader")
const KIT_PATH := "res://assets/spatial_golden/bell_rib_kit_v1.png"
const KIT_CATALOG_PATH := "res://assets/spatial_golden/kit.json"
var _catalog: Dictionary
var _kit: Texture2D
var _stage: PlainsRegionStage
var _design: Dictionary
var _clock := 0.0
var _distant: Array[Dictionary] = []
var _grass: Array[Dictionary] = []
var _entries: Array[Dictionary] = []
var _pieces: Array[Sprite2D] = []
var _old_background: CanvasLayer
var _far_bell: Sprite2D
var _response := 0.0

func configure(source: PlainsRegionStage, design: Dictionary) -> void:
	_stage = source
	_design = design

func _ready() -> void:
	_catalog = JSON.parse_string(FileAccess.get_file_as_string(KIT_CATALOG_PATH))
	_kit = load(KIT_PATH) as Texture2D
	if _kit == null:
		push_error("Spatial golden finite kit is missing")
		return
	z_as_relative = false
	var app := _stage.get_parent() as DemoApp
	_old_background = app.get_node_or_null("PlainsBackground") as CanvasLayer
	if _old_background != null: _old_background.hide()
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -95
	add_child(sky_layer)
	var sky := Sprite2D.new()
	sky.texture = SKY
	sky.position = Vector2(640,360)
	sky.scale = Vector2(1280,720)/SKY.get_size()
	sky.material = _atmosphere(0.30,0.39,0.0)
	sky_layer.add_child(sky)
	# One finite painted distant ridge; never translucent polygon stacks with
	# visible rectangular baselines. Its lower edge stays beyond the camera.
	var ridge := Sprite2D.new()
	ridge.texture=RIDGE;ridge.centered=false;ridge.offset=Vector2(-768,-1024)
	ridge.z_as_relative=false;ridge.z_index=-60;ridge.material=_atmosphere(0.28,0.56,0.0)
	add_child(ridge)
	_distant.append({"node":ridge,"anchor":Vector2(1400,4300),"parallax":0.16})
	# The actual solids and painterly faces share their contour one-for-one.
	for row: Dictionary in _design.solid_polygons:
		var polygon := _points(row.points)
		var tint := Color(0.89,0.94,0.88) if row.material == "chalk" else Color(0.70,0.80,0.75)
		var node := _stone(polygon,tint,-2 if row.material == "chalk" else -7)
		node.name = "Painted_"+str(row.id)
		_entries.append({"kind":"collision_contour","id":row.id,"points":row.points,"node":str(node.get_path()),"source":STONE.resource_path})
	for row: Dictionary in _design.top_polylines:
		_grass_lip(_points(row.points))
	# These assemblies use only the six atlas pieces, with joints placed in world space.
	_architecture()
	for row: Dictionary in _design.top_polylines:
		var points := _points(row.points)
		# Sparse clumps grow from real named top edges; landing/RootBell space stays clear.
		for i: int in range(1,points.size()-1):
			var anchor: Vector2 = points[i]
			if absf(anchor.x-float(_design.route_waypoints.recovery[0]))<145.0 or absf(anchor.x-float(_design.enemy.position[0]))<190.0: continue
			var grass := _piece("grass",anchor,0.14,0.0,2,Color(0.76,0.84,0.59))
			_grass.append({"node":grass,"rest":grass.rotation,"phase":anchor.x*0.01})
	# A complete assembly is one parallax object. Child joints retain their
	# authored distances; parallax must never compress component offsets.
	var anchors: Dictionary = _design.landmark_anchors
	var far := Vector2(anchors.far_bell[0],anchors.far_bell[1])
	var assembly := Node2D.new()
	assembly.name="DistantResonatorAssembly"
	add_child(assembly)
	_distant.append({"node":assembly,"anchor":far,"parallax":0.38})
	# The landmark belongs to one continuous distant outcrop. Its support and
	# masonry move together; a foreground landing must never impersonate a base.
	var foundation := _stone(PackedVector2Array([
		Vector2(-190,290),Vector2(-155,230),Vector2(-95,220),
		Vector2(95,220),Vector2(155,230),Vector2(215,340),
		Vector2(330,1400),Vector2(-360,1400),Vector2(-285,520)
	]),Color(0.80,0.85,0.80),-36)
	foundation.name="DistantResonatorFoundation"
	foundation.reparent(assembly,false)
	_entries.append({"kind":"landmark_foundation","source":STONE.resource_path,
		"parent":"DistantResonatorAssembly","parallax":0.38,
		"support_y":220,"bottom_y":1400})
	_far_bell = _piece("bell",Vector2(0,0),0.28,-0.08,-32,Color(0.67,0.79,0.73,0.80))
	_far_bell.reparent(assembly,false)
	_far_bell.material=_atmosphere(0.32,0.52,0.0)
	for dx: float in [-90.0,90.0]:
		var foot := _piece("foot",Vector2(dx,220),0.24,0,-34,Color(0.57,0.72,0.66,0.80))
		foot.reparent(assembly,false)
		foot.material=_atmosphere(0.32,0.52,0.0)
		var shaft := _piece("shaft",Vector2(dx,210),0.49,0.0,-34,Color(0.57,0.72,0.66,0.80))
		shaft.reparent(assembly,false)
		shaft.material=_atmosphere(0.32,0.52,0.0)
	var cable := Line2D.new()
	cable.points = PackedVector2Array([Vector2(-90,-18),Vector2(0,-3),Vector2(90,-18)])
	cable.width=2.0;cable.default_color=Color(0.34,0.47,0.40,0.80);cable.z_as_relative=false;cable.z_index=-33
	assembly.add_child(cable)
	for body: Node2D in _stage.enemies:
		var actor := body.get_node_or_null("Actor") as EnemyActor
		if actor != null and actor.attack_behavior is RootBellBehavior:
			(actor.attack_behavior as RootBellBehavior).pulse_committed.connect(_pulse)
			break
	_process(0.0)

func _atmosphere(saturation: float, mist: float, softness: float) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader=ATMOSPHERE
	result.set_shader_parameter("saturation",saturation)
	result.set_shader_parameter("mist",mist)
	result.set_shader_parameter("softness",softness)
	result.set_shader_parameter("mist_color",Color("a7beb6"))
	result.set_shader_parameter("contrast",0.76)
	return result

func _stone(points: PackedVector2Array, tint: Color, order: int) -> Polygon2D:
	var node := Polygon2D.new()
	node.polygon=points; node.z_as_relative=false; node.z_index=order
	var shader_material := ShaderMaterial.new()
	shader_material.shader=STONE_SHADER
	shader_material.set_shader_parameter("painted_stone",STONE)
	shader_material.set_shader_parameter("stone_tint",tint)
	shader_material.set_shader_parameter("local_phase",order < -10)
	shader_material.set_shader_parameter("distance_mist",0.72 if order < -10 else 0.0)
	var edges := PackedVector4Array()
	for i: int in points.size():
		var a := points[i]; var b := points[(i+1)%points.size()]
		edges.append(Vector4(a.x,a.y,b.x,b.y))
	shader_material.set_shader_parameter("edge_count",edges.size())
	edges.resize(24);shader_material.set_shader_parameter("edges",edges)
	node.material=shader_material
	add_child(node)
	return node

func _grass_lip(points: PackedVector2Array) -> void:
	for i: int in points.size()-1:
		var a := points[i];var b := points[i+1]
		var inward := Vector2(-(b-a).y,(b-a).x).normalized()
		var lip := Polygon2D.new()
		lip.polygon=PackedVector2Array([a-inward*7,b-inward*7,b+inward*14,a+inward*14])
		lip.texture=PAINT;lip.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		lip.uv=PackedVector2Array([Vector2(a.x*3.8,0),Vector2(b.x*3.8,0),Vector2(b.x*3.8,155),Vector2(a.x*3.8,155)])
		lip.z_as_relative=false;lip.z_index=0;lip.modulate=Color(0.88,0.93,0.76)
		add_child(lip)

func _architecture() -> void:
	# Anchors are authored together with actual ribs in the same layout contract.
	# Missing anchors mean missing assembly, never a fallback to an older room.
	for rib: Dictionary in _design.get("architecture_ribs",[]):
		var factor := float(rib.get("scale",0.65))
		var tint := Color(0.73,0.82,0.73)
		for joint: Array in rib.shaft_joints:
			_piece("shaft",Vector2(joint[0],joint[1]),factor,float(rib.shaft_rotation),-5,tint)
		var crown: Array = rib.crown
		_piece("crown",Vector2(crown[0],crown[1]),factor,float(rib.crown_rotation),-5,tint)
		var foot: Array = rib.foot
		_piece("foot",Vector2(foot[0],foot[1]),factor*0.48,0,-4,tint)

func _piece(id: String, anchor: Vector2, factor: float, turn: float, order: int, tint: Color) -> Sprite2D:
	var component: Dictionary = _catalog.components[id]
	var raw: Array = component.region
	var region := Rect2(raw[0],raw[1],raw[2],raw[3])
	var pivot := Vector2(component.pivot[0],component.pivot[1])
	var atlas := AtlasTexture.new();atlas.atlas=_kit;atlas.region=region;atlas.filter_clip=true
	var sprite := Sprite2D.new();sprite.texture=atlas;sprite.centered=false
	sprite.offset=-pivot;sprite.position=anchor;sprite.scale=Vector2.ONE*factor
	sprite.rotation=turn;sprite.modulate=tint;sprite.z_as_relative=false;sprite.z_index=order
	add_child(sprite)
	sprite.set_meta("kit_piece",id)
	_pieces.append(sprite)
	_entries.append({"kind":"modular_kit","piece":id,"anchor":[anchor.x,anchor.y],"scale":factor,"rotation":turn,"source":KIT_PATH,"atlas_xywh":[atlas.region.position.x,atlas.region.position.y,atlas.region.size.x,atlas.region.size.y]})
	return sprite

func _pulse(_event: StringName, _at: Vector2) -> void:
	_response=1.0

func _process(delta: float) -> void:
	_clock+=delta;_response=maxf(0.0,_response-delta*1.5)
	var camera := get_viewport().get_camera_2d()
	if camera == null: return
	for layer: Dictionary in _distant:
		var node := layer.node as Node2D
		node.position=Vector2(layer.anchor)*float(layer.parallax)+camera.global_position*(1.0-float(layer.parallax))
	for row: Dictionary in _grass:
		(row.node as Sprite2D).rotation=float(row.rest)+sin(_clock*1.6+float(row.phase))*0.012
	if _far_bell != null: _far_bell.rotation=-0.08+sin(_clock*1.3)*0.008+sin(_response*PI*3)*_response*0.025

func _exit_tree() -> void:
	if is_instance_valid(_old_background): _old_background.show()

static func _points(raw: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Array in raw: points.append(Vector2(point[0],point[1]))
	return points

func measured_nodes() -> Dictionary:
	var actual_instances: Array[Dictionary] = []
	for sprite: Sprite2D in _pieces:
		if not is_instance_valid(sprite): continue
		var atlas := sprite.texture as AtlasTexture
		actual_instances.append({"piece":str(sprite.get_meta("kit_piece")),
			"node":str(sprite.get_path()),"parent":str(sprite.get_parent().get_path()),
			"world_position":[sprite.global_position.x,sprite.global_position.y],
			"world_scale":[sprite.global_scale.x,sprite.global_scale.y],
			"world_rotation":sprite.global_rotation,
			"atlas_source":atlas.atlas.resource_path,
			"region":[atlas.region.position.x,atlas.region.position.y,atlas.region.size.x,atlas.region.size.y]})
	return {"scope":"Explicit spatial experiment, finite kit; no whole-screen scene painting", "layout_sha256":_design.get("contract_sha256",""),"assets":[{"path":KIT_PATH,"sha256":FileAccess.get_sha256(KIT_PATH)},{"path":PAINT.resource_path,"sha256":FileAccess.get_sha256(PAINT.resource_path)},{"path":SKY.resource_path,"sha256":FileAccess.get_sha256(SKY.resource_path)},{"path":RIDGE.resource_path,"sha256":FileAccess.get_sha256(RIDGE.resource_path)},{"path":STONE.resource_path,"sha256":FileAccess.get_sha256(STONE.resource_path)}],"entries":_entries,"actual_instances":actual_instances,"parallax_components":_distant.size(),"user_acceptance":"unverified","device_acceptance":"unverified"}
