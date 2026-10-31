class_name PlainsWorldRebuildComposer
extends Node2D
## Finite source-painted landforms define the world construction and contacts.
## Direct fixed-scale sources retain their painted contours, no inverse UV warp.
const ENVIRONMENT := "res://assets/visual_development/plains_world_rebuild/environment_source.png"
var plan: Dictionary = {}
var measurements: Array = []
var layer_measurements: Array = []

func configure(data: Dictionary) -> void:
	plan = data.duplicate(true)
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
	var air_shader := Shader.new()
	air_shader.code = "shader_type canvas_item; void fragment(){ vec4 tint=COLOR; vec4 paint=texture(TEXTURE,UV); float fade=smoothstep(0.0,0.07,UV.y)*(1.0-smoothstep(0.265,0.355,UV.y)); COLOR=vec4(paint.rgb,paint.a*fade)*tint; }"
	var air_material := ShaderMaterial.new()
	air_material.shader = air_shader
	far.material = air_material
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
	var frame: Dictionary=body.get("paint_frame",{})
	if frame.is_empty():
		push_error("Source-authoritative body has no painted frame: "+str(body.id))
		return
	var source_path := str(frame.source_path)
	var texture := load(source_path) as Texture2D
	if texture==null:
		push_error("Source-authoritative body paint missing: "+source_path)
		return
	var source_size := Vector2(float(frame.source_size[0]),float(frame.source_size[1]))
	if texture.get_size()!=source_size:
		push_error("Source frame dimension drift: "+source_path)
		return
	var factor := float(frame.uniform_scale)
	var sprite := Sprite2D.new()
	sprite.name = str(body.id).validate_node_name()+"CompletePainting"
	sprite.set_meta("world_body_id",str(body.id))
	sprite.texture=texture
	sprite.centered=false
	sprite.position=Vector2(float(frame.origin[0]),float(frame.origin[1]))
	sprite.scale=Vector2.ONE*factor
	sprite.z_index=int(body.get("paint_z",0))
	sprite.flip_h=bool(frame.mirror_x)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	# Source alpha supplies its genuine painted silhouette, grass and shoulder.
	# Never clip it into arbitrary collision polygons or add a separate top band.
	add_child(sprite)
	measurements.append({"id":body.id,"world_polygon":body.polygon.duplicate(true),"source_polygon":body.source_polygon.duplicate(true),"source_top_poly":body.source_top_poly.duplicate(true),"source":source_path,"source_sha256":FileAccess.get_sha256(source_path),"paint_frame":frame.duplicate(true),"render_kind":"direct_source_sprite","actual_position":[sprite.position.x,sprite.position.y],"actual_scale":[sprite.scale.x,sprite.scale.y],"actual_flip_h":sprite.flip_h,"actual_z_index":sprite.z_index,"actual_source_size":[texture.get_width(),texture.get_height()],"complete_body":true,"legacy_rectangles":false,"inverse_uv_mapping":false,"separate_flora_strip":false,"source_painting_present":true,"art_admitted":false})

func measured_nodes() -> Dictionary:
	return {"status":"actual_source_authoritative_world_candidate_not_art_admitted","bodies":measurements.duplicate(true),"layers":layer_measurements.duplicate(true),"actual_body_count":measurements.size(),"source_kind":"finite_whole_landform_paintings_not_screen_backgrounds","formal_pool":false,"limitations":["source_contact_approximation_and_root_joins_require_actual_review","single_structure_no_random_region_claim","no_user_or_art_admission"]}
