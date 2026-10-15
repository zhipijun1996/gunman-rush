class_name PlainsVisualSpace
extends Node2D
## Cosmetic candidate retaining structure. Reads formal geometry; never changes it.
const FAMILY_PATH := "res://assets/visual_director/waterworks_v1/manifest.json"
const SOURCE_PATH := "res://assets/visual_director/waterworks_v1/well_abutment_left_v1.png"
var recess_source_path := "res://assets/visual_director/waterworks_v1/waterworks_recess_v1.png"
const OBSERVER_PATH := "scripts/art/plains_visual_space.gd"
var stage: PlainsRegionStage
var source_module: PlatformingModule
var attachment: StaticBody2D
var wall: Sprite2D
var recess: Sprite2D
var recess_base := Vector2.ZERO
var parallax_reference := Vector2.ZERO
var parallax_factor := 0.12
var _last_parallax_camera_center := Vector2.INF
var bank_regions: Array[Rect2] = []
var bank_quads: Array[ColorRect] = []
var _bank_art_id := 0
var family: Dictionary = {}
var dock := Rect2()
var opaque_source := Rect2(18, 17, 988, 1500)
var omission_reason := ""
var _output := ""
var _samples: Array[Dictionary] = []
var _last_physics_frame := -120

func configure(source: PlainsRegionStage) -> void:
	stage = source

func _ready() -> void:
	# Parent scenery(-10)+composition(-5)+this(12) => -3, behind terrain(-1).
	z_index = 12
	set_process(false)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-composition-output="):
			_output = validated_output_path(arg.trim_prefix("--visual-composition-output="))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FAMILY_PATH))
	if not parsed is Dictionary:
		omission_reason = "missing_family_contract"
		return
	family = parsed
	var discovery: Dictionary = stage.generated.manifest.get("creek_discovery", {})
	var node_id := str(discovery.get("module", ""))
	for index: int in stage.generated.manifest.nodes.size():
		var node: Dictionary = stage.generated.manifest.nodes[index]
		if str(node.id) == node_id:
			if bool(node.get("mirrored", false)):
				omission_reason = "unverified_mirrored_architecture_light"
				return
			source_module = stage.assembler.modules[index]
			break
	if not is_instance_valid(source_module) or source_module.definition.module_id != &"plains_bell_ferry_control":
		omission_reason = "unsupported_or_missing_real_creek_ferry"
		return
	attachment = source_module.get_node_or_null("Platform0") as StaticBody2D
	if not is_instance_valid(attachment):
		omission_reason = "missing_actual_left_dock_body"
		return
	var slab: Rect2 = source_module.definition.platforms[0]
	dock = source_module.global_transform * slab
	var candidate: Dictionary = family.assets[0]
	var values: Array = candidate.opaque_source_bounds
	opaque_source = Rect2(values[0], values[1], values[2], values[3])
	var factor := float(candidate.trial_world_height) / opaque_source.size.y
	wall = Sprite2D.new()
	wall.name = "LeftBankAbutment"
	wall.texture = load(SOURCE_PATH) as Texture2D
	wall.centered = false
	wall.scale = Vector2.ONE * factor
	# The real bank covers the cap. Whole opaque silhouette stays on land side.
	var wall_world_position := Vector2(dock.end.x - float(candidate.channel_clearance) - opaque_source.end.x * factor,
		dock.position.y + float(candidate.bank_overlap) - opaque_source.position.y * factor)
	wall.set_meta("visual_semantics", {"layer": "middle", "semantic": "rooted_architecture", "spatial_use": "left_bank_retaining_abutment"})
	add_child(wall)
	wall.global_position = wall_world_position
	# Static v1 pixel review rejected its entirely hidden placement. Preserve it
	# as inactive, never count an invisible Sprite as environmental coverage.
	wall.visible = false
	_build_recess()
	set_process(true)


func recess_candidate() -> Dictionary:
	var id := str(family.get("active_recess_asset_id", "waterworks_recess_v1"))
	for candidate: Dictionary in family.get("assets", []):
		if str(candidate.id) == id: return candidate
	return {}

func _build_recess() -> void:
	var candidate := recess_candidate()
	if candidate.is_empty(): return
	recess_source_path = "res://" + str(candidate.path)
	var values: Array = candidate.opaque_source_bounds
	var opaque := Rect2(values[0], values[1], values[2], values[3])
	var factor := float(candidate.trial_world_width) / opaque.size.x
	var receiving: Rect2 = source_module.global_transform * source_module.definition.platforms[1]
	var center_x := (dock.get_center().x + receiving.get_center().x) * .5
	parallax_reference = Vector2(center_x, dock.position.y - 100.0)
	parallax_factor = float(candidate.parallax_factor)
	recess_base = Vector2(center_x - float(candidate.trial_world_width) * .5 - opaque.position.x * factor,
		dock.position.y - float(candidate.top_above_bank) - opaque.position.y * factor)
	recess = Sprite2D.new()
	recess.name = "DistantWaterworksRecess"
	recess.texture = load(recess_source_path) as Texture2D
	recess.centered = false
	recess.scale = Vector2.ONE * factor
	recess.position = recess_base
	recess.z_index = -7
	# Cool, receding architecture; functional gold/red objects stay higher contrast.
	recess.modulate = Color(.72, .82, .80, .96)
	add_child(recess)
	recess.global_position = recess_base
	var distance := ShaderMaterial.new()
	distance.shader = preload("res://shaders/plains_waterworks_depth.gdshader")
	distance.set_shader_parameter("fracture_region_px", Vector4(640,560,520,360))
	distance.set_shader_parameter("fracture_recession", 0.62)
	recess.material = distance
	_update_recess_parallax()

func _update_recess_parallax() -> void:
	if not is_instance_valid(recess): return
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		_last_parallax_camera_center = camera.get_screen_center_position()
		recess.global_position = recess_base + (_last_parallax_camera_center - parallax_reference) * parallax_factor

func _area_geometry(id: String) -> Rect2:
	for node: Dictionary in stage.generated.manifest.nodes:
		if str(node.id) == id and node.has("geometry"):
			var values: Array = node.geometry.bounds
			var origin := Vector2(node.offset[0],node.offset[1])
			return stage.global_transform * Rect2(origin+Vector2(values[0],values[1]),Vector2(values[2],values[3]))
	return Rect2()

func _update_bank_materials() -> void:
	if not is_instance_valid(stage.terrain_art) or not is_instance_valid(stage.terrain_art.art): return
	var art: Node2D = stage.terrain_art.art
	if _bank_art_id == art.get_instance_id(): return
	_bank_art_id = art.get_instance_id()
	bank_quads.clear(); bank_regions.clear()
	var discovery: Dictionary = stage.generated.manifest.creek_discovery
	var entry := _area_geometry(str(discovery.entry_area))
	var exit := _area_geometry(str(discovery.exit_area))
	var receiving: Rect2 = source_module.global_transform * source_module.definition.platforms[1]
	if not entry.has_area() or not exit.has_area(): return
	var left := Rect2(Vector2(minf(entry.position.x,dock.position.x),dock.position.y),Vector2(dock.end.x-minf(entry.position.x,dock.position.x),dock.size.y))
	var right := Rect2(receiving.position,Vector2(maxf(exit.end.x,receiving.end.x)-receiving.position.x,receiving.size.y))
	for column: Rect2 in stage.assembler.ground_supports.columns:
		var world: Rect2 = stage.assembler.ground_supports.global_transform * column
		if world.position.x < left.end.x and world.end.x > left.position.x and world.position.y>=dock.position.y and world.position.y<=dock.end.y+.1:
			left.size.y=maxf(left.size.y,world.end.y-left.position.y)
		if world.position.x < right.end.x and world.end.x > right.position.x and world.position.y>=receiving.position.y and world.position.y<=receiving.end.y+.1:
			right.size.y=maxf(right.size.y,world.end.y-right.position.y)
	bank_regions=[left,right]
	for child: Node in art.get_children():
		if not child is ColorRect or not child.material is ShaderMaterial: continue
		var quad := child as ColorRect
		var actual: Rect2 = quad.get_global_transform() * Rect2(Vector2.ZERO,quad.size)
		if not bank_regions.any(func(region: Rect2): return region.intersects(actual)): continue
		var material := quad.material as ShaderMaterial
		material.set_shader_parameter("well_bank_enabled",true)
		material.set_shader_parameter("well_bank_regions",PackedVector4Array([Vector4(left.position.x,left.position.y,left.size.x,left.size.y),Vector4(right.position.x,right.position.y,right.size.x,right.size.y)]))
		material.set_shader_parameter("well_bank_strength",0.78)
		bank_quads.append(quad)

func bank_material_issues() -> Array[String]:
	var issues: Array[String] = []
	if bank_regions.size()!=2 or bank_quads.is_empty():
		issues.append("actual_bank_material_binding_absent")
		return issues
	if bank_regions[0].end.x>dock.end.x+.02 or bank_regions[1].position.x<source_module.to_global(source_module.definition.platforms[1].position).x-.02:
		issues.append("bank_region_crosses_real_open_channel")
	for quad: ColorRect in bank_quads:
		var mat := quad.material as ShaderMaterial
		if mat.get_shader_parameter("well_bank_enabled") != true: issues.append("actual_selected_bank_material_not_enabled")
		var values: PackedVector4Array=mat.get_shader_parameter("well_bank_regions")
		for index: int in mini(values.size(),bank_regions.size()):
			var expected := bank_regions[index]
			if not Rect2(values[index].x,values[index].y,values[index].z,values[index].w).is_equal_approx(expected): issues.append("actual_bank_material_scope_differs_from_real_bank")
	for module: PlatformingModule in stage.assembler.modules:
		for ferry: ModuleMovingPlatform in module.moving_platforms:
			if not is_instance_valid(ferry.painted_art): continue
			for child: Node in ferry.painted_art.get_children():
				if child is ColorRect and child.material is ShaderMaterial and child.material.get_shader_parameter("well_bank_enabled") == true: issues.append("moving_ferry_material_incorrectly_graded_as_bank")
	return issues

func bank_material_measurements() -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	for quad: ColorRect in bank_quads:
		if not is_instance_valid(quad): continue
		var material:=quad.material as ShaderMaterial
		var values: PackedVector4Array=material.get_shader_parameter("well_bank_regions")
		rows.append({"node_path":str(quad.get_path()),"actual_world_bounds":rect_values(quad.get_global_transform()*Rect2(Vector2.ZERO,quad.size)),"shader_path":material.shader.resource_path,"well_bank_enabled":material.get_shader_parameter("well_bank_enabled"),"actual_material_regions":Array(values).map(func(v:Vector4):return [v.x,v.y,v.z,v.w]),"actual_strength":material.get_shader_parameter("well_bank_strength"),"scope":"Actual existing terrain quad/material; RGB-only fragment branch. No new geometry or altered alpha/collision."})
	return rows

func actual_opaque_bounds() -> Rect2:
	return wall.global_transform * opaque_source if is_instance_valid(wall) else Rect2()

func effective_z(item: CanvasItem) -> int:
	var total := item.z_index
	var child: CanvasItem = item
	var parent: Node = item.get_parent()
	while child.z_as_relative and parent is CanvasItem:
		child = parent as CanvasItem
		total += child.z_index
		parent = parent.get_parent()
	return total

func attachment_bounds() -> Rect2:
	if not is_instance_valid(attachment): return Rect2()
	var shape := attachment.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null or not shape.shape is RectangleShape2D: return Rect2()
	var size := (shape.shape as RectangleShape2D).size
	return shape.global_transform * Rect2(-size * .5, size)

func actual_issues() -> Array[String]:
	var issues: Array[String] = []
	if not is_instance_valid(wall) or not is_instance_valid(attachment):
		issues.append("missing_actual_wall_or_attachment")
		return issues
	if not attachment_bounds().is_equal_approx(dock): issues.append("actual_attachment_differs_from_real_dock")
	var opaque := actual_opaque_bounds()
	var candidate: Dictionary = family.assets[0]
	if opaque.end.x > dock.end.x - float(candidate.channel_clearance) + .02: issues.append("abutment_intrudes_into_open_channel")
	if absf(opaque.position.y - dock.position.y - float(candidate.bank_overlap)) > .02: issues.append("abutment_cap_detached_from_actual_bank")
	if not is_equal_approx(opaque.size.y, float(candidate.trial_world_height)): issues.append("actual_scale_differs_from_trial_contract")
	if effective_z(wall) >= -1: issues.append("abutment_not_behind_formal_terrain")
	if FileAccess.get_sha256(SOURCE_PATH) != str(candidate.sha256) or wall.texture.resource_path != SOURCE_PATH: issues.append("actual_texture_differs_from_family_source")
	if is_instance_valid(recess):
		var far_candidate: Dictionary = recess_candidate()
		var far_values: Array = far_candidate.opaque_source_bounds
		var far_opaque := recess.global_transform * Rect2(far_values[0], far_values[1], far_values[2], far_values[3])
		if not is_equal_approx(far_opaque.size.x, float(far_candidate.trial_world_width)): issues.append("actual_recess_scale_differs_from_contract")
		if effective_z(recess) >= -1: issues.append("distant_recess_not_behind_gameplay")
		if FileAccess.get_sha256(recess_source_path) != str(far_candidate.sha256) or recess.texture.resource_path != recess_source_path: issues.append("actual_recess_texture_differs_from_family")
		if not attachment_bounds().is_equal_approx(dock): issues.append("actual_recess_anchor_support_differs_from_real_bank")
		if _last_parallax_camera_center.is_finite():
			var expected := recess_base + (_last_parallax_camera_center - parallax_reference) * parallax_factor
			if recess.global_position.distance_to(expected) > .04: issues.append("actual_recess_anchor_differs_from_real_bank")
		if recess.texture.get_size() != Vector2(1536, 1024): issues.append("actual_recess_texture_extent_differs_from_source")
	return issues

static func rect_values(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]

static func pair(value: Vector2) -> Array:
	return [value.x, value.y]

static func color_values(value: Color) -> Array:
	return [value.r, value.g, value.b, value.a]

static func actual_texture_sha256(texture: Texture2D) -> String:
	if texture == null: return ""
	var path := texture.resource_path
	if texture is AtlasTexture:
		path = (texture as AtlasTexture).atlas.resource_path if (texture as AtlasTexture).atlas != null else ""
	return FileAccess.get_sha256(path) if not path.is_empty() and FileAccess.file_exists(path) else ""

func inactive_wall_measurements() -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	if not is_instance_valid(wall) or not is_instance_valid(attachment): return nodes
	var candidate: Dictionary = family.assets[0]
	nodes.append({"node_path": str(wall.get_path()), "world_bounds": rect_values(wall.global_transform * wall.get_rect()),
		"opaque_source_bounds_world": rect_values(actual_opaque_bounds()), "layer": "middle", "semantic": "rooted_architecture",
		"attachment_node_path": str(attachment.get_path()), "spatial_use": "left_bank_retaining_abutment",
		"asset_family": {"id": family.family_id, "version": family.version, "intended_use": candidate.intended_use, "acceptance": "candidate_not_visual_approved"},
		"actual_global_position": pair(wall.global_position), "actual_global_scale": pair(wall.global_scale),
		"local_z_index": wall.z_index, "effective_z_index": effective_z(wall), "modulate": color_values(wall.modulate),
		"self_modulate": color_values(wall.self_modulate), "visible": wall.visible, "visible_in_tree": wall.is_visible_in_tree(),
		"texture_path": wall.texture.resource_path, "texture_sha256": actual_texture_sha256(wall.texture), "declared_source_sha256": FileAccess.get_sha256(SOURCE_PATH),
		"depth_factor": 0.0, "measurement_note": "Runtime transforms/visibility/z/texture; semantic layer and alpha-source bbox come from declared family. AABB is not proof of pixel occlusion."})
	nodes.append({"node_path": str(attachment.get_path()), "world_bounds": rect_values(attachment_bounds()), "layer": "gameplay",
		"semantic": "actual_static_dock", "actual_global_position": pair(attachment.global_position),
		"local_z_index": attachment.z_index, "effective_z_index": effective_z(attachment),
		"measurement_note": "Actual existing StaticBody2D RectangleShape2D; observer neither creates nor changes collision."})
	return nodes

func measured_nodes() -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	if is_instance_valid(recess):
		nodes.append({"node_path": str(recess.get_path()), "world_bounds": rect_values(recess.global_transform * recess.get_rect()),
			"layer": "far", "semantic": "distant_enclosure", "spatial_use": "distant_waterworks_enclosure",
			"asset_family": {"id": family.family_id, "version": family.version, "intended_use": recess_candidate().intended_use, "acceptance": "candidate_not_visual_approved"},
			"actual_global_position": pair(recess.global_position), "actual_global_scale": pair(recess.global_scale),
			"local_z_index": recess.z_index, "effective_z_index": effective_z(recess), "modulate": color_values(recess.modulate),
			"self_modulate": color_values(recess.self_modulate), "visible": recess.visible, "visible_in_tree": recess.is_visible_in_tree(),
			"texture_path": recess.texture.resource_path, "texture_sha256": actual_texture_sha256(recess.texture), "declared_source_sha256": FileAccess.get_sha256(recess_source_path),
			"depth_factor": parallax_factor, "parallax_reference": pair(parallax_reference), "base_position": pair(recess_base),
			"last_parallax_camera_center": pair(_last_parallax_camera_center),
			"measurement_note": "Actual Sprite properties. Distant foundation is artwork semantics, not physics support. Bounds are not opaque-pixel coverage or beauty proof."})
	var previous := inactive_wall_measurements()
	if previous.size() > 1: nodes.append(previous[1])
	return nodes

func actual_shape_bounds(body: Node2D) -> Rect2:
	for child: Node in body.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var size := (child.shape as RectangleShape2D).size
			return child.global_transform * Rect2(-size * .5, size)
	return Rect2()

func protected_bounds() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(source_module): return result
	result.append({"id": "real_left_dock", "bounds": rect_values(dock)})
	var slab: Rect2 = source_module.definition.platforms[1]
	result.append({"id": "real_receiving_dock", "bounds": rect_values(source_module.global_transform * slab)})
	for ferry: ModuleMovingPlatform in source_module.moving_platforms:
		var real_bounds := actual_shape_bounds(ferry)
		if real_bounds.has_area():
			result.append({"id": str(ferry.get_path()), "bounds": rect_values(real_bounds), "measurement": "actual RectangleShape2D global_transform", "declared_definition_size": pair(ferry.definition.size)})
	var app := stage.get_parent() as DemoApp
	if app != null and is_instance_valid(app.player):
		var real_bounds := actual_shape_bounds(app.player)
		if real_bounds.has_area():
			result.append({"id": "actual_player", "bounds": rect_values(real_bounds), "measurement": "actual player RectangleShape2D global_transform, no added margin"})
	return result

func _process(_delta: float) -> void:
	_update_bank_materials()
	_update_recess_parallax()
	if _output.is_empty(): return
	var frame := Engine.get_physics_frames()
	if frame - _last_physics_frame < 120: return
	_last_physics_frame = frame
	var camera := get_viewport().get_camera_2d()
	_samples.append({"engine_physics_frame": frame, "nodes": measured_nodes(), "protected_world_bounds": protected_bounds(),
		"camera_center": pair(camera.get_screen_center_position()) if camera != null else [],
		"camera_zoom": pair(camera.zoom) if camera != null else [], "issues": actual_issues(), "inactive_nodes": inactive_wall_measurements().slice(0,1), "bank_materials":bank_material_measurements(), "bank_material_issues":bank_material_issues()})

static func validated_output_path(value: String) -> String:
	if value.is_empty(): return ""
	var full := ProjectSettings.globalize_path(value).simplify_path()
	var build_root := ProjectSettings.globalize_path("res://build").simplify_path().trim_suffix("/") + "/"
	return full if full.begins_with(build_root) and full.get_extension() == "json" else ""

func _exit_tree() -> void:
	if _output.is_empty() or _samples.is_empty(): return
	if validated_output_path(_output).is_empty(): return
	var last: Dictionary = _samples[-1]
	var result := {"schema_version": 1, "artifact_kind": "actual_scene_composition_measurements",
		"observer": {"path": OBSERVER_PATH, "sha256": FileAccess.get_sha256("res://" + OBSERVER_PATH)},
		"nodes": last.nodes, "protected_world_bounds": last.protected_world_bounds, "samples": _samples, "inactive_nodes": last.inactive_nodes, "bank_materials": last.bank_materials, "bank_material_issues":last.bank_material_issues,
		"scope": "Actual live Node measurements sampled every120 enginephysicsframes. No pixels/readback/input/state changes. Last sample, not exact native terminal tick; layer/semantics are declarations; pixel occlusion and aesthetics require actual movie review."}
	DirAccess.make_dir_recursive_absolute(_output.get_base_dir())
	var file := FileAccess.open(_output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result) + "\n")
		file.close()
