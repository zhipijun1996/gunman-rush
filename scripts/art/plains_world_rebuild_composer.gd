class_name PlainsWorldRebuildComposer
extends Node2D
## Complete solid bodies are the visual domain. Source painting is parameterized
## by continuous surface-to-root sections, never old collision rectangles.
const TERRAIN := "res://assets/visual_development/plains_world_rebuild/terrain_source.png"
const MAPPING := "res://assets/visual_development/plains_world_rebuild/terrain_mapping.json"
const ENVIRONMENT := "res://assets/visual_development/plains_world_rebuild/environment_source.png"
var plan: Dictionary = {}
var measurements: Array = []
var layer_measurements: Array = []
var terrain_texture: Texture2D
var source_mapping: Dictionary = {}
var source_image: Image

func configure(data: Dictionary) -> void:
	plan = data.duplicate(true)
	terrain_texture = load(TERRAIN) as Texture2D
	source_mapping = JSON.parse_string(FileAccess.get_file_as_string(MAPPING))
	if terrain_texture == null or source_mapping.is_empty():
		push_error("World rebuild painting source missing")
		return
	_install_air()
	_install_environment()
	# Foundation first, then continuous banks, so roots meet inside one material.
	var bodies: Array = plan.bodies.duplicate()
	bodies.reverse()
	for body: Dictionary in bodies:
		_install_body(body)

func _install_air() -> void:
	var backdrop := Polygon2D.new()
	backdrop.name = "OpenAirNotRearWall"
	backdrop.z_index = -100
	backdrop.polygon = PackedVector2Array([Vector2(-1200,-1400),Vector2(5200,-1400),Vector2(5200,1800),Vector2(-1200,1800)])
	backdrop.vertex_colors = PackedColorArray([Color("c9dadd"),Color("dce6df"),Color("f1ecdc"),Color("e5e6d8")])
	add_child(backdrop)

func _install_environment() -> void:
	if not ResourceLoader.exists(ENVIRONMENT):
		layer_measurements.append({"status":"environment_painting_pending"})
		return
	var texture := load(ENVIRONMENT) as Texture2D
	if texture == null:return
	var domain: Array = plan.layers.far_image_domain
	var far := _sprite(texture,Rect2(0,0,1536,365),Vector2(float(domain[0]),float(domain[1])),Vector2(float(domain[2])/1536.0,float(domain[3])/365.0),-60,"DistantMeadowAndBrokenViaduct")
	far.modulate = Color(1,1,1,0.72)
	for item: Dictionary in plan.layers.composition_assets:
		var region := Rect2(0,365,820,659) if str(item.kind)=="meadow_tree" else Rect2(820,395,716,629)
		# Measured feet on the original sheet, independent from world geometry.
		var foot := Vector2(220,595) if str(item.kind)=="meadow_tree" else Vector2(330,565)
		var factor := float(item.world_size[0])/region.size.x
		var anchor := Vector2(float(item.anchor[0]),float(item.anchor[1]))
		var sprite := _sprite(texture,region,anchor-foot*factor,Vector2.ONE*factor,int(item.z_index),str(item.id))
		sprite.set_meta("world_anchor",anchor)
		sprite.set_meta("anchor_body_id",str(item.body_id))

func _sprite(texture: Texture2D,region: Rect2,at: Vector2,scale_value: Vector2,depth: int,label: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = label
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = false
	sprite.position = at
	sprite.scale = scale_value
	sprite.z_index = depth
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	layer_measurements.append({"id":label,"source":ENVIRONMENT,"source_sha256":FileAccess.get_sha256(ENVIRONMENT),"region":[region.position.x,region.position.y,region.size.x,region.size.y],"position":[at.x,at.y],"scale":[scale_value.x,scale_value.y],"z_index":depth,"interactive":false})
	return sprite

func _install_body(body: Dictionary) -> void:
	var polygon := PackedVector2Array()
	var minimum_x := INF
	var maximum_x := -INF
	var root_y := -INF
	for value: Array in body.polygon:
		var p := Vector2(float(value[0]),float(value[1]))
		polygon.append(p)
		minimum_x = minf(minimum_x,p.x)
		maximum_x = maxf(maximum_x,p.x)
		root_y = maxf(root_y,p.y)
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var triangle_count := 0
	# Clip columns against the complete body, retaining every concave cliff and
	# shoulder. Internal strips share world positions and source UV, not endcaps.
	var x := floorf(minimum_x/64.0)*64.0
	while x < maximum_x:
		var clip := PackedVector2Array([Vector2(x,-2000),Vector2(x+64,-2000),Vector2(x+64,3000),Vector2(x,3000)])
		for fragment: PackedVector2Array in Geometry2D.intersect_polygons(polygon,clip):
			var indices := Geometry2D.triangulate_polygon(fragment)
			for index: int in indices:
				var point := fragment[index]
				vertices.append(point)
				uvs.append(_source_uv(body,point,minimum_x,maximum_x,root_y))
			triangle_count += indices.size()/3
		x += 64.0
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance := MeshInstance2D.new()
	instance.name = str(body.id).validate_node_name()+"CompletePainting"
	instance.set_meta("world_body_id",str(body.id))
	instance.mesh = mesh
	instance.texture = terrain_texture
	instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 paint=texture(TEXTURE,UV); COLOR=vec4(paint.rgb,1.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	instance.material = material
	add_child(instance)
	_install_living_lip(body,minimum_x,maximum_x)
	measurements.append({"id":body.id,"world_polygon":body.polygon.duplicate(true),"source":TERRAIN,"source_sha256":FileAccess.get_sha256(TERRAIN),"mapping_source":MAPPING,"mapping_sha256":FileAccess.get_sha256(MAPPING),"mesh_vertices":vertices.size(),"triangles":triangle_count,"legacy_rectangles":false,"complete_body":true,"method":"shared_body_polygon_clipped_world_sections_surface_to_root_painted_coordinates","source_painting_present":true,"art_admitted":false})

func _source_uv(body: Dictionary,point: Vector2,minimum_x: float,maximum_x: float,root_y: float) -> Vector2:
	var source_x := lerpf(100.0,1430.0,clampf((point.x-minimum_x)/(maximum_x-minimum_x),0,1))
	var top := _surface_y(body,point.x)
	var source_bottom := _opaque_bottom(source_x)
	var source_y := lerpf(145.0,source_bottom,clampf((point.y-top)/maxf(1.0,root_y-top),0,1))
	return Vector2(source_x/1536.0,source_y/1024.0)

func _opaque_bottom(x: float) -> float:
	var rows: Array = source_mapping.opaque_lower_profile
	for index: int in range(rows.size()-1):
		var a: Array = rows[index]
		var b: Array = rows[index+1]
		if x >= float(a[0]) and x <= float(b[0]):
			return lerpf(float(a[1]),float(b[1]),(x-float(a[0]))/(float(b[0])-float(a[0])))
	return float(rows[-1][1])

func _surface_y(body: Dictionary,x: float) -> float:
	var surfaces: Array = body.top_surfaces
	for surface: Dictionary in surfaces:
		var a: Array = surface.from
		var b: Array = surface.to
		if x >= float(a[0]) and x <= float(b[0]):
			return lerpf(float(a[1]),float(b[1]),(x-float(a[0]))/maxf(1,float(b[0])-float(a[0])))
	if x < float(surfaces[0].from[0]):return float(surfaces[0].from[1])
	return float(surfaces[-1].to[1])

func _install_living_lip(body: Dictionary,minimum_x: float,maximum_x: float) -> void:
	if str(body.kind)=="creek_bedrock":return
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for surface: Dictionary in body.top_surfaces:
		var a := Vector2(float(surface.from[0]),float(surface.from[1]))
		var b := Vector2(float(surface.to[0]),float(surface.to[1]))
		var count := maxi(1,ceili((b.x-a.x)/48.0))
		for step: int in count:
			var left := a.lerp(b,float(step)/count)
			var right := a.lerp(b,float(step+1)/count)
			for p: Vector2 in [left+Vector2(0,-46),right+Vector2(0,-46),right,left+Vector2(0,-46),right,left]:
				vertices.append(p)
				var ground := lerpf(a.y,b.y,(p.x-a.x)/(b.x-a.x))
				uv.append(Vector2(lerpf(100,1430,(p.x-minimum_x)/(maximum_x-minimum_x))/1536.0,(145+(p.y-ground)*2.0)/1024.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var lip := MeshInstance2D.new()
	lip.name=str(body.id).validate_node_name()+"NonInteractiveFlora"
	lip.mesh=mesh
	lip.texture=terrain_texture
	lip.z_index=1
	lip.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(lip)

func measured_nodes() -> Dictionary:
	return {"status":"actual_painted_world_candidate_not_art_admitted","bodies":measurements.duplicate(true),"layers":layer_measurements.duplicate(true),"actual_body_count":measurements.size(),"source_kind":"new_hand_painted_material_image_not_screen_background","formal_pool":false,"limitations":["surface_to_root_mapping_may_deform_strata_requires_actual_pixel_review","root_bodies_overlap_material_connections_require_actual_review","no_user_or_art_admission"]}
