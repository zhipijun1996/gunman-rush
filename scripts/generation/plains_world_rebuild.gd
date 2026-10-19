class_name PlainsWorldRebuild
extends RefCounted

## An isolated world-section source. Collision and painting consume the same
## complete bodies; route and layer intentions are derived from those bodies.
## This is structure, not a declaration that a painted asset family is ready.
const CATALOG_PATH := "res://resources/generation/plains_world_rebuild.json"
const VERSION := "plains-world-rebuild-v1"

static func generate(seed: String, variant: int = 0) -> Dictionary:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var tuning_source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
	if not source is Dictionary or not tuning_source is Dictionary:
		return {"error": "missing_world_or_actual_player_configuration"}
	if variant < 0 or variant > 1:
		return {"error": "unregistered_structure_variant"}
	var enemy_definition: EnemyDefinition = load("res://resources/enemies/plains_charger.tres")
	if enemy_definition == null:
		return {"error": "missing_existing_enemy_definition"}
	var catalog: Dictionary = source
	var tuning: Dictionary = tuning_source
	var units: Dictionary = catalog["body_units"]
	# Local RNG never mutates the game's RunRandomStream or save state.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(VERSION + ":" + seed)
	var option := rng.randi_range(0, 1)
	var left: float = float(units["ridge_widths"][variant])
	var gap: float = float(units["fissure_widths"][option])
	var right := left + gap
	var top: float = float(units["main_surface_y"][variant])
	var creek := top + float(units["creek_depths"][variant])
	var root := creek + float(units["root_depth"])
	var far_right := right + float(units["landing_widths"][variant])
	var approach: Array = [[-240.0, top + 60.0], [560.0, top + 60.0], [640.0, top], [left, top]]
	if variant == 1:
		# A longer stepped approach changes the cross-section, not merely pigment.
		approach = [[-240.0, top + 120.0], [480.0, top + 120.0], [560.0, top + 60.0], [840.0, top + 60.0], [920.0, top], [left, top]]
	var left_polygon: Array = approach.duplicate(true)
	left_polygon.append_array([[left + 14.0, top + 30.0], [left - 20.0, top + 74.0], [left - 12.0, top + 100.0], [left - 88.0, top + 148.0], [left - 120.0, top + 210.0], [left - 208.0, creek - 44.0], [left - 260.0, creek], [left - 300.0, creek + 120.0], [left - 360.0, root], [-240.0, root]])
	var right_top: Array = [[right, top], [right + 260.0, top], [right + 340.0, top - 40.0], [right + 1000.0, top - 40.0], [right + 1080.0, top], [far_right, top]]
	var right_polygon: Array = right_top.duplicate(true)
	right_polygon.append_array([[far_right + 40.0, top + 90.0], [far_right + 80.0, creek + 60.0], [far_right + 120.0, root], [right + 360.0, root], [right + 300.0, creek + 120.0], [right + 260.0, creek], [right + 208.0, creek - 44.0], [right + 120.0, top + 210.0], [right + 88.0, top + 148.0], [right + 12.0, top + 100.0], [right + 20.0, top + 74.0], [right - 14.0, top + 30.0]])
	var creek_polygon: Array = [[left - 360.0, creek], [right + 360.0, creek], [right + 400.0, root], [left - 400.0, root]]
	var bodies: Array = [
		_body("west_meadow_ridge", "grounded_grass_ridge", left_polygon, _surfaces(approach, "main_route"), ["west_extension", "west_creek_root"]),
		_body("east_meadow_ridge", "grounded_grass_ridge", right_polygon, _surfaces(right_top, "main_route"), ["east_extension", "east_creek_root"]),
		_body("creek_foundation", "creek_bedrock", creek_polygon, [{"from": [left - 260.0, creek], "to": [right + 260.0, creek], "role": "lower_recovery"}], ["west_creek_root", "east_creek_root"])
	]
	var spawn_y := float(approach[0][1]) - 18.0
	var bounds: Array = [-240.0, top - 360.0, far_right + 360.0, root - top + 540.0]
	var data: Dictionary = {
		"version": VERSION, "root_seed": seed, "variant": variant,
		"status": "first_structure_candidate" if variant == 0 else "second_layout_pre_research_not_admitted",
		"bounds": bounds, "spawn": [100.0, spawn_y], "exit": [far_right - 140.0, top - 18.0],
		"bodies": bodies, "formal_pool": false,
		"construction": {"west_width": left, "east_width": far_right - right, "fissure_width": gap, "main_y": top, "creek_depth": creek - top, "root_depth": root - creek, "registered_unit_source": CATALOG_PATH},
		"routes": [
			{"id": "main", "required_action": "walk_full_jump_with_optional_recoil", "points": [[100.0, spawn_y], [660.0, (top if variant == 0 else top + 60.0) - 18.0], [left - 48.0, top - 18.0], [right + 64.0, top - 18.0], [right + 420.0, top - 58.0], [far_right - 140.0, top - 18.0]], "validation_status": "unverified_motor"},
			{"id": "lower_creek", "required_action": "controlled_drop_then_legal_downshot_recoil_return", "points": [[left - 48.0, top - 18.0], [(left + right) * 0.5, creek - 18.0], [right + 80.0, creek - 18.0], [right + 64.0, top - 18.0]], "validation_status": "unverified_motor"}
		],
		"enemy_spawns": [{"id": "east_guard", "definition": "res://resources/enemies/plains_charger.tres", "position": [right + 640.0, top - 40.0 - enemy_definition.collision_size.y * 0.5], "body": "east_meadow_ridge"}], "device_spawns": [],
		"encounter_reservations": [{"id": "east_guard", "position": [right + 640.0, top - 58.0], "clear_landing_radius": 160.0, "status": "runtime_existing_enemy_contract_required"}],
		"layers": _layers(left, right, top, creek, far_right, bodies),
		"interfaces": [
			{"id": "west_extension", "position": [-240.0, float(approach[0][1])], "direction": [-1, 0], "root_y": root, "kind": "continuous_ridge_cross_section"},
			{"id": "east_extension", "position": [far_right, top], "direction": [1, 0], "root_y": root, "kind": "continuous_ridge_cross_section"},
			{"id": "west_creek_root", "overlap_width": 100.0, "top_y": creek, "kind": "solid_root_overlap"},
			{"id": "east_creek_root", "overlap_width": 100.0, "top_y": creek, "kind": "solid_root_overlap"}
		],
		"planning_limits": catalog["limits"].duplicate(true),
		"player_source": {"path": "res://config/player_tuning.json", "ground_speed": tuning["ground_speed"], "gravity": tuning["gravity"], "jump_speeds": tuning["jump_speeds"], "max_jumps": tuning["max_jumps"], "max_air_shots": tuning["max_air_shots"], "body_size": [24, 36]},
		"admission": catalog["admission"].duplicate(true)
	}
	data["validation_errors"] = validate(data)
	return data

static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("version", "")) != VERSION:
		errors.append("unregistered_world_version")
	var bodies: Array = data.get("bodies", [])
	if bodies.size() != 3:
		errors.append("expected_two_full_ridges_and_shared_creek_foundation")
	var ids: Array[String] = []
	for value: Variant in bodies:
		var body: Dictionary = value
		var id := str(body.get("id", ""))
		if id.is_empty() or id in ids:
			errors.append("missing_or_duplicate_body_id")
		ids.append(id)
		var points := PackedVector2Array()
		for point: Variant in body.get("polygon", []):
			if not point is Array or point.size() != 2:
				errors.append("invalid_polygon_coordinate:" + id)
				continue
			points.append(Vector2(float(point[0]), float(point[1])))
		if points.size() < 4 or Geometry2D.triangulate_polygon(points).is_empty():
			errors.append("body_not_triangulatable:" + id)
		if str(body.get("collision_source", "")) != "polygon" or str(body.get("painting_source", "")) != "polygon":
			errors.append("collision_and_painting_must_share_complete_body:" + id)
		for surface: Dictionary in body.get("top_surfaces", []):
			var a := Vector2(float(surface["from"][0]), float(surface["from"][1]))
			var b := Vector2(float(surface["to"][0]), float(surface["to"][1]))
			if b.x <= a.x:
				errors.append("surface_not_forward:" + id)
			if absf(rad_to_deg((b - a).angle())) > float(data.get("planning_limits", {}).get("max_walk_slope_degrees", 0)):
				errors.append("main_surface_slope_outside_grammar:" + id)
			var midpoint := (a + b) * 0.5
			if not Geometry2D.is_point_in_polygon(midpoint + Vector2(0, 2), points):
				errors.append("standing_surface_without_solid_underneath:" + id)
	if bodies.size() == 3:
		var west: Dictionary = bodies[0]
		var east: Dictionary = bodies[1]
		var west_surfaces: Array = west.get("top_surfaces", [])
		var east_surfaces: Array = east.get("top_surfaces", [])
		if not west_surfaces.is_empty() and not east_surfaces.is_empty():
			var gap := float(east_surfaces[0]["from"][0]) - float(west_surfaces[-1]["to"][0])
			if gap < 72.0 or gap > float(data.get("planning_limits", {}).get("max_main_gap", 0)):
				errors.append("fissure_width_outside_registered_jump_and_painting_interface")
	if bodies.size() == 3:
		var west_polygon := _packed(bodies[0]["polygon"])
		var east_polygon := _packed(bodies[1]["polygon"])
		var bed_polygon := _packed(bodies[2]["polygon"])
		if Geometry2D.intersect_polygons(west_polygon, bed_polygon).is_empty() or Geometry2D.intersect_polygons(east_polygon, bed_polygon).is_empty():
			errors.append("creek_foundation_must_physically_join_both_ridge_roots")
		if not Geometry2D.intersect_polygons(west_polygon, east_polygon).is_empty():
			errors.append("open_fissure_must_not_be_filled_by_ridges")
	var layer_plan: Dictionary = data.get("layers", {})
	for asset: Dictionary in layer_plan.get("composition_assets", []):
		var body_found := false
		for body: Dictionary in bodies:
			if str(body["id"]) != str(asset.get("body_id", "")):
				continue
			body_found = true
			var expected := _surface_anchor(body, float(asset["anchor"][0]))
			if expected.is_empty() or expected != asset["anchor"]:
				errors.append("composition_asset_not_rooted_on_real_surface:" + str(asset.get("id", "")))
		if not body_found:
			errors.append("composition_asset_missing_parent_body:" + str(asset.get("id", "")))
	return errors

static func _surface_anchor(body: Dictionary, x: float) -> Array:
	for surface: Dictionary in body.get("top_surfaces", []):
		var a: Array = surface["from"]
		var b: Array = surface["to"]
		if x >= float(a[0]) and x <= float(b[0]) and float(b[0]) > float(a[0]):
			var weight := (x - float(a[0])) / (float(b[0]) - float(a[0]))
			return [x, lerpf(float(a[1]), float(b[1]), weight)]
	return []

static func _packed(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value: Array in values:
		result.append(Vector2(float(value[0]), float(value[1])))
	return result

static func _body(id: String, kind: String, polygon: Array, surfaces: Array, connections: Array) -> Dictionary:
	return {"id": id, "kind": kind, "polygon": polygon, "top_surfaces": surfaces, "collision_source": "polygon", "painting_source": "polygon", "paint_family": "p1_continuous_meadow_candidate", "paint_z": 0, "connections": connections, "visual_status": "requires_whole_body_hand_painted_implementation"}

static func _surfaces(points: Array, role: String) -> Array:
	var surfaces: Array = []
	for index: int in range(points.size() - 1):
		surfaces.append({"from": points[index].duplicate(), "to": points[index + 1].duplicate(), "role": role})
	return surfaces

static func _layers(left: float, right: float, top: float, creek: float, far_right: float, bodies: Array) -> Dictionary:
	return {
		"composition_assets": [
			{"id": "west_sheltering_tree", "kind": "meadow_tree", "body_id": "west_meadow_ridge", "anchor": _surface_anchor(bodies[0], 280.0), "world_size": [480, 375], "z_index": -8, "relation": "roots_attached_to_body_surface; canopy_frames_entry_without_hiding_player"},
			{"id": "east_wind_keeper_shed", "kind": "keeper_shed", "body_id": "east_meadow_ridge", "anchor": _surface_anchor(bodies[1], right + 490.0), "world_size": [370, 230], "z_index": -8, "relation": "foundation_attached_to_body_surface; non_interactive_behind_patrol_and_landing"}
		],
		"far_image_domain": [-420.0, top - 400.0, 3456.0, 575.0],
		"rear": [{"id": "distant_meadow_fold", "kind": "finite_distant_rolling_formation", "parallax": 0.34, "z_index": -50, "polygon": [[-400, top + 100], [80, top - 160], [420, top - 220], [860, top - 80], [1300, top - 180], [1800, top - 250], [far_right + 300, top - 40], [far_right + 300, creek + 120], [-400, creek + 120]], "interaction": "none"}],
		"foreground": [{"id": "creek_near_bank", "kind": "non_interactive_low_silhouette", "z_index": 30, "polygon": [[left - 400, creek + 110], [left - 200, creek + 70], [right + 100, creek + 94], [right + 430, creek + 80], [right + 430, creek + 240], [left - 400, creek + 240]], "interaction": "none"}],
		"vegetation_anchors": [{"body": "west_meadow_ridge", "span": [80, 420], "relation": "rooted_on_declared_top_surface", "height_range": [28, 90]}, {"body": "east_meadow_ridge", "span": [right + 440, right + 840], "relation": "rooted_on_declared_top_surface", "height_range": [24, 76]}],
		"camera_intentions": [{"id": "approach", "focus": [left - 320, top - 120], "clear_sky_above_surface": 260}, {"id": "fissure", "focus": [(left + right) * 0.5, top + 50], "keep_visible": ["both_rims", "creek_recovery"]}],
		"open_air": [{"id": "creek_valley", "bounds": [left - 260, top - 240, right - left + 520, creek - top + 240], "exclude_rear_solid_wall": true}]
	}
