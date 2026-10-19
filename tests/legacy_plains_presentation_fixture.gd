extends RefCounted
## Explicit historical presentation compatibility on current physics, never a formal style.
const PROFILES := ["terrain_family", "directed_space", "waterworks", "connected_family"]
const FLAG := "--legacy-presentation-fixture="
const REFERENCE_COMMIT := "ac002e7641fd282c291cdd7c25c9cf5d2450ce0a"
const REFERENCE_MOVING_BLOB := "ebcd7a7332225b39ab0b5355ddb2cf4cd93329c4"
const REFERENCE_STUDY_BLOB := "67665e07910164cb1c155727be32797dd7533e95"

# Only the historical presentation factory is overridden. The current study's
# collect_solids, process/lifecycle and set_candidate remain inherited.
class LegacyTerrainStudy extends PlainsTerrainStudy:
	func refresh_geometry() -> void:
		var solids := collect_solids()
		if solids == authored_solids: return
		var was_enabled := enabled
		set_candidate(false)
		if is_instance_valid(art): art.free()
		authored_solids = solids
		var started := Time.get_ticks_msec()
		art = PlainsTerrainFamilySampler.build(stage, solids)
		if art == null:
			push_warning("Terrain study refused unsupported local boundary density; baseline preserved")
			return
		print("TERRAIN STUDY: solids=%s pieces=%s setup_ms=%s" % [solids.size(), art.get_child_count(), Time.get_ticks_msec()-started])
		art.z_index = -1
		add_child(art)
		set_candidate(was_enabled)

static func _shape_geometry(shape: Shape2D) -> Dictionary:
	if shape == null: return {}
	var geometry: Dictionary = {"class":shape.get_class()}
	# Actual stored shape parameters include radius/height/size, and polygon
	# points/segments. Equal AABBs do not imply equal collision geometry.
	for property: Dictionary in shape.get_property_list():
		var key: String = str(property.name)
		if key in ["script", "resource_local_to_scene", "resource_name", "resource_path"]: continue
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) != 0:
			geometry[key] = var_to_str(shape.get(key))
	if shape is ConvexPolygonShape2D: geometry["actual_points"] = var_to_str(shape.points)
	if shape is ConcavePolygonShape2D: geometry["actual_segments"] = var_to_str(shape.segments)
	return geometry

static func _physics(node: Node, rows: Array[Dictionary]) -> void:
	if node is CollisionObject2D:
		rows.append({"path":str(node.get_path()), "transform":var_to_str(node.global_transform),
			"layer":node.collision_layer, "mask":node.collision_mask})
	if node is CollisionShape2D:
		rows.append({"path":str(node.get_path()), "transform":var_to_str(node.global_transform),
			"shape_geometry":_shape_geometry(node.shape), "shape_rect":var_to_str(node.shape.get_rect()) if node.shape != null else "",
			"disabled":node.disabled, "one_way":node.one_way_collision, "one_way_margin":node.one_way_collision_margin})
	if node is CollisionPolygon2D:
		rows.append({"path":str(node.get_path()), "transform":var_to_str(node.global_transform),
			"polygon":var_to_str(node.polygon), "build_mode":node.build_mode, "disabled":node.disabled,
			"one_way":node.one_way_collision, "one_way_margin":node.one_way_collision_margin})
	for child: Node in node.get_children(): _physics(child, rows)

static func invariant(app: DemoApp) -> String:
	var bodies: Array[Dictionary] = []
	_physics(app.stage, bodies)
	_physics(app.player, bodies)
	var tuning: Dictionary = {}
	for row: Dictionary in app.player.tuning.get_property_list():
		if str(row.name) in ["script", "resource_local_to_scene", "resource_path", "resource_name"]: continue
		if (int(row.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			tuning[str(row.name)] = var_to_str(app.player.tuning.get(str(row.name)))
	return JSON.stringify({"manifest":JSON.stringify(app.stage.generated.manifest), "physics":bodies,
		"player_tuning":tuning, "tuning_file":FileAccess.get_sha256("res://config/player_tuning.json"),
		"traversal":FileAccess.get_sha256("res://resources/player/traversal.tres")}).sha256_text()

static func pixel_default(app: DemoApp) -> bool:
	var stage := app.stage as PlainsRegionStage
	var background := app.get_node_or_null("PixelPlainsParallax") as UnderworldParallax
	return stage != null and not stage.has_meta("legacy_presentation_fixture") \
		and stage.terrain_art != null and stage.terrain_art.art is UnderworldTerrain \
		and stage.get_node_or_null("PixelRegionScenery") is UnderworldScenery \
		and app.player.get_node_or_null("PixelPlainsActor") is UnderworldPlayer \
		and stage.get_meta("underworld_formal_style",false) \
		and stage.find_child("DirectedSemanticLandscape",true,false) == null \
		and stage.find_child("ConnectedLandscape",true,false) == null \
		and stage.find_child("CreekWaterworksSpace",true,false) == null \
		and app._uses_pixel_plains_presentation() and background != null and background.visible \
		and background.panels.size() == 9

static func _install(app: DemoApp, profile: String, arguments: PackedStringArray) -> Dictionary:
	if profile not in PROFILES or arguments.count(FLAG+profile) != 1:
		return {"installed":false, "error":"explicit_legacy_profile_required"}
	for argument: String in arguments:
		if argument.begins_with(FLAG) and argument != FLAG+profile:
			return {"installed":false, "error":"conflicting_legacy_profile"}
	if profile == "waterworks" and "--legacy-waterworks-contract" not in arguments:
		return {"installed":false, "error":"original_waterworks_flag_required"}
	if not pixel_default(app): return {"installed":false, "error":"actual_pixel_default_precondition_failed"}
	var stage := app.stage as PlainsRegionStage
	var before := invariant(app)
	var scenery := stage.get_node("PixelRegionScenery")
	stage.remove_child(scenery)
	scenery.free()
	var current_study := stage.terrain_art
	current_study.set_candidate(false)
	stage.remove_child(current_study)
	current_study.free()
	var study := LegacyTerrainStudy.new()
	study.name = "ExplicitLegacyTerrainStudy"
	study.stage = stage
	stage.terrain_art = study
	stage.add_child(study)
	var moving_presentation: Array[Dictionary] = []
	if profile == "waterworks":
		# Explicit historical shader consumer only. Current moving body/clock and
		# the other fixture profiles retain their current production behavior.
		for module: PlatformingModule in stage.assembler.modules:
			for ferry: ModuleMovingPlatform in module.moving_platforms:
				if is_instance_valid(ferry.painted_art):
					ferry.remove_child(ferry.painted_art)
					ferry.painted_art.free()
				var local_rect: Rect2 = Rect2(-ferry.definition.size / 2.0, ferry.definition.size)
				var local_solids: Array[Rect2] = [local_rect]
				ferry.painted_art = PlainsTileComposer.build_rectangles(local_solids)
				var shader_count: int = 0
				if ferry.painted_art != null:
					for quad: ColorRect in ferry.painted_art.get_children():
						quad.material.set_shader_parameter("body_local_material", true)
						shader_count += 1
					ferry.add_child(ferry.painted_art)
					ferry.painted_art.visible = true
				ferry.queue_redraw()
				moving_presentation.append({"actual_ferry_path":str(ferry.get_path()),
					"actual_art_path":str(ferry.painted_art.get_path()) if ferry.painted_art != null else "",
					"local_rect":var_to_str(local_rect), "actual_shader_children":shader_count,
					"reference_moving_blob":REFERENCE_MOVING_BLOB, "body_local_material":true})
	if profile != "terrain_family":
		var legacy := PlainsRegionScenery.new()
		legacy.name = "ExplicitLegacyRegionScenery"
		legacy.configure(stage.generated.manifest, PlainsRegionScenery.solid_supports(stage), PlainsRegionScenery.protection(stage))
		stage.add_child(legacy)
	var background := app.get_node("PlainsBackground") as PlainsBackground
	background.visible = true
	background.use_region_layers()
	(app.get_node("PixelPlainsParallax") as PixelPlainsParallax).visible = false
	var record := {"installed":true, "consumer_mode":"explicit_legacy_presentation_not_default", "profile":profile,
		"reference_commit":REFERENCE_COMMIT, "reference_study_blob":REFERENCE_STUDY_BLOB,
		"fixture_sha256":FileAccess.get_sha256("res://tests/legacy_plains_presentation_fixture.gd"),
		"stage_instance_id":stage.get_instance_id(), "invariant_before":before, "invariant_after":invariant(app),
		"legacy_study_path":str(study.get_path()), "scope":"Historical presentation compatibility on current unchanged physics; not default pixel/style acceptance"}
	if profile == "waterworks": record["moving_presentation"] = moving_presentation
	record["unchanged"] = record.invariant_before == record.invariant_after
	stage.set_meta("legacy_presentation_fixture", record.duplicate(true))
	return record

static func prepare(app: DemoApp, profile: String) -> Dictionary:
	var before := invariant(app)
	var actual_default := pixel_default(app)
	var absent := _install(app, profile, PackedStringArray())
	var wrong := _install(app, profile, PackedStringArray([FLAG+"wrong_profile"]))
	var refused_cleanly: bool = not absent.installed and not wrong.installed and before == invariant(app) and pixel_default(app)
	var record := _install(app, profile, OS.get_cmdline_user_args())
	record["pixel_default_before"] = actual_default
	record["no_flag_and_wrong_profile_refused_without_mutation"] = refused_cleanly
	record["no_flag_result"] = absent
	record["wrong_profile_result"] = wrong
	return record
