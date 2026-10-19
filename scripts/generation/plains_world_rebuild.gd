class_name PlainsWorldRebuild
extends RefCounted

## An isolated world-section source. Collision and painting consume the same
## complete bodies; route and layer intentions are derived from those bodies.
## This is structure, not a declaration that a painted asset family is ready.
const CATALOG_PATH := "res://resources/generation/plains_world_rebuild.json"
const VERSION := "plains-world-rebuild-v3"
const WORLD_SUBPIXELS := 100
const PREVIOUS_SOURCE_COMMIT := "5871a02bb2d54670dea0bcd643a307d575bce6e7"

static func generate(seed: String, variant: int = 0) -> Dictionary:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var tuning_source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
	if not source is Dictionary or not tuning_source is Dictionary:
		return {"error": "missing_world_or_actual_player_configuration"}
	var catalog: Dictionary = source
	if not catalog.get("layout_variants", {}).has(str(variant)):
		return {"error": "unregistered_source_layout_variant"}
	var tuning: Dictionary = tuning_source
	var geometry := _layout_geometry(catalog, variant)
	var layout: Dictionary = catalog["layout_variants"][str(variant)]
	var route_mode := str(layout["route_mode"])
	var enemy_definition: EnemyDefinition = load("res://resources/enemies/plains_charger.tres")
	if enemy_definition == null:
		return {"error": "missing_existing_enemy_definition"}
	var west_frame: Dictionary = {"source_path": geometry["source_path"], "source_size": geometry["source_size"], "origin": geometry["west_origin"], "uniform_scale": geometry["west_scale"], "mirror_x": false, "source_coordinate_mode": "full_image_pixels"}
	var east_frame: Dictionary = {"source_path": geometry["east_source_path"], "source_size": geometry["source_size"], "origin": geometry["east_origin"], "uniform_scale": geometry["east_scale"], "mirror_x": true, "source_coordinate_mode": "full_image_pixels"}
	var bodies: Array = [_source_body("west_meadow_ridge", west_frame, geometry), _source_body("east_meadow_ridge", east_frame, geometry)]
	var creek: float = float(geometry["creek_surface_y"])
	var creek_scale: float = float(geometry["creek_fixed_scale"])
	var west_wall := _outline_x_at_y(bodies[0]["polygon"], creek, true)
	var east_wall := _outline_x_at_y(bodies[1]["polygon"], creek, false)
	var creek_center := _q((west_wall + east_wall) * 0.5)
	var creek_size: Array = geometry["creek_source_size"]
	var creek_source_top: Array = geometry["creek_source_top_poly"]
	var creek_origin: Array = [_q(creek_center - float(creek_size[0]) * creek_scale * 0.5), _q(creek - float(creek_source_top[0][1]) * creek_scale)]
	var creek_frame: Dictionary = {"source_path": geometry["creek_source_path"], "source_size": creek_size, "origin": creek_origin, "uniform_scale": creek_scale, "mirror_x": false, "source_coordinate_mode": "full_image_pixels"}
	var creek_geometry: Dictionary = {"top_poly": creek_source_top, "side_poly": geometry["creek_source_side_poly"]}
	var foundation := _source_body("creek_foundation", creek_frame, creek_geometry)
	foundation["kind"] = "source_anchored_creek_bedrock"
	foundation["top_surfaces"] = [{"from": [west_wall, creek], "to": [east_wall, creek], "role": "lower_recovery"}]
	foundation["connections"] = ["west_creek_root", "east_creek_root"]
	foundation["paint_z"] = -3
	bodies.append(foundation)
	var root := _q(float(creek_origin[1]) + float(creek_size[1]) * creek_scale)
	var overlap := float(creek_size[0]) * creek_scale * 0.5 - (east_wall - west_wall) * 0.5
	var world_root_extent := maxf(root, maxf(float(bodies[0]["polygon"][-1][1]), float(bodies[1]["polygon"][0][1])))
	var west_top: Array = bodies[0]["top_surfaces"]
	var east_top: Array = bodies[1]["top_surfaces"]
	var west_rim: Array = west_top[-1]["to"]
	var east_rim: Array = east_top[0]["from"]
	var player_size := _player_body_size()
	var spawn := _surface_anchor(bodies[0],100.0)
	# Clear the high side across the actual player's complete rectangular feet.
	# SegmentRespawn's existing full-body/three-foot safety query is unchanged.
	var high_foot := minf(float(_surface_anchor(bodies[0],100.0-player_size.x*0.5)[1]),float(_surface_anchor(bodies[0],100.0+player_size.x*0.5)[1]))
	spawn[1] = _q(high_foot-player_size.y*0.5-0.1)
	var far_right: float = float(east_top[-1]["to"][0])
	var exit_position := _surface_anchor(bodies[1], far_right - 140.0)
	exit_position[1] = _q(float(exit_position[1]) - 18.0)
	var enemy_anchor := _surface_anchor(bodies[1], float(east_rim[0]) + 490.0)
	var layers := _layers(float(west_rim[0]), float(east_rim[0]), float(west_rim[1]), creek, far_right, bodies)
	var shed_anchor := _surface_anchor(bodies[1], float(east_rim[0]) + 490.0)
	layers["composition_assets"][1]["anchor"] = shed_anchor
	var west_entry := _standing_anchor(bodies[0], float(west_rim[0]) - 30.0)
	var east_landing := _standing_anchor(bodies[1], float(east_rim[0]) + 54.0)
	var creek_launch: Array = [_q((west_wall + east_wall) * 0.5), _q(creek - 18.0)]
	var creek_walk: Array = [_q((west_wall + east_wall) * 0.5 + (east_wall - west_wall) * 0.25), _q(creek - 18.0)]
	if route_mode == "lower_pass":
		# Both recovery launches have actual body-width clearance to the cliff;
		# return to the west uses the same floor instead of an unproven rim leap.
		creek_launch = [_q(west_wall + player_size.x * 0.5 + 20.0), _q(creek - player_size.y * 0.5)]
		creek_walk = [_q(east_wall - player_size.x * 0.5 - 20.0), _q(creek - player_size.y * 0.5)]
	var main_points: Array = [spawn, _standing_anchor(bodies[0], 600.0), west_entry, east_landing, exit_position]
	if route_mode == "lower_pass":
		main_points = [spawn, west_entry, creek_launch, creek_walk, east_landing, exit_position]
	var data: Dictionary = {
		"version": VERSION, "root_seed": seed, "variant": variant, "geometry_revision": "v3_source_painting_is_world_construction", "previous_source_commit": PREVIOUS_SOURCE_COMMIT,
		"status": str(layout["status"]), "bounds": [float(west_top[0]["from"][0]), 140.0, _q(far_right-float(west_top[0]["from"][0])), world_root_extent + 40.0],
		"spawn": spawn, "exit": exit_position, "bodies": bodies, "formal_pool": false,
		"construction": {"source_geometry": geometry.duplicate(true), "main_contact_gap": float(east_rim[0]) - float(west_rim[0]), "creek_open_width": east_wall - west_wall, "root_depth": root - creek, "registered_unit_source": CATALOG_PATH, "randomness_status": "seed_recorded_finite_registered_layouts_not_random_region", "route_mode": route_mode, "upper_shortcut_status": "unverified_optional" if route_mode == "lower_pass" else "actual_route_evidence_separate", "extension_join_status":"external_source_cross_sections_not_connected_in_this_finite_preview"},
		"routes": [
			{"id": "main", "mode": route_mode, "required_action": "descend_creek_walk_then_legal_recoil_climb_return_to_west" if route_mode == "lower_pass" else "walk_source_derived_surface_then_legal_recoil_crossing", "points": main_points, "validation_status": "unverified_motor"},
			{"id": "lower_creek", "required_action": "controlled_drop_then_legal_downshot_recoil_return", "points": [west_entry, creek_launch, creek_walk, east_landing], "validation_status": "unverified_motor"}
		],
		"enemy_spawns": [{"id": "east_guard", "definition": "res://resources/enemies/plains_charger.tres", "position": [enemy_anchor[0], float(enemy_anchor[1]) - enemy_definition.collision_size.y * 0.5], "body": "east_meadow_ridge"}], "device_spawns": [],
		"encounter_reservations": [{"id": "east_guard", "position": enemy_anchor, "clear_landing_radius": 160.0, "status": "runtime_existing_enemy_contract_required"}], "layers": layers,
		"interfaces": [{"id": "west_extension", "position": west_top[0]["from"], "direction": [-1, 0], "root_y": float(bodies[0]["polygon"][-1][1]), "kind": "source_body_cross_section"}, {"id": "east_extension", "position": east_top[-1]["to"], "direction": [1, 0], "root_y": float(bodies[1]["polygon"][0][1]), "kind": "source_body_cross_section"}, {"id": "west_creek_root", "overlap_width": overlap, "top_y": creek, "kind": "solid_root_overlap"}, {"id": "east_creek_root", "overlap_width": overlap, "top_y": creek, "kind": "solid_root_overlap"}],
		"planning_limits": catalog["limits"].duplicate(true), "player_source": {"path": "res://config/player_tuning.json", "ground_speed": tuning["ground_speed"], "gravity": tuning["gravity"], "jump_speeds": tuning["jump_speeds"], "max_jumps": tuning["max_jumps"], "max_air_shots": tuning["max_air_shots"], "body_size": [player_size.x,player_size.y]}, "admission": catalog["admission"].duplicate(true)
	}
	# Canonical world coordinates are integer centipixels expressed in world
	# units. Quantize geometry, never authoritative source pixels or tuning.
	var actual_player_source: Dictionary = data["player_source"]
	data = _q_world_tree(data)
	data["player_source"] = actual_player_source
	data["construction"]["source_geometry"] = geometry.duplicate(true)
	data["world_coordinate_protocol"] = catalog["world_coordinate_protocol"].duplicate(true)
	data["validation_errors"] = validate(data)
	return data

static func _player_body_size() -> Vector2:
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var state := packed.get_state()
	for index: int in state.get_node_count():
		if state.get_node_type(index)!=&"CollisionShape2D":continue
		for property_index: int in state.get_node_property_count(index):
			if state.get_node_property_name(index,property_index)==&"shape":
				var shape := state.get_node_property_value(index,property_index) as RectangleShape2D
				if shape!=null:return shape.size
	push_error("Actual Player rectangular collision source missing")
	return Vector2.ZERO

static func _source_body(id: String, frame: Dictionary, geometry: Dictionary) -> Dictionary:
	var source_polygon: Array = geometry["top_poly"].duplicate(true)
	source_polygon.append_array(geometry["side_poly"].duplicate(true))
	var world_polygon: Array = []
	var world_top: Array = []
	for point: Array in source_polygon:
		world_polygon.append(_source_to_world(point, frame))
	for point: Array in geometry["top_poly"]:
		world_top.append(_source_to_world(point, frame))
	if bool(frame["mirror_x"]):
		world_polygon.reverse()
		world_top.reverse()
	var body := _body(id, "source_anchored_grass_ridge", world_polygon, _surfaces(world_top, "main_route"), ["west_extension", "west_creek_root"] if not bool(frame["mirror_x"]) else ["east_extension", "east_creek_root"])
	body["paint_frame"] = frame.duplicate(true)
	body["source_sha256"] = FileAccess.get_sha256(str(frame["source_path"])) if FileAccess.file_exists(str(frame["source_path"])) else ""
	body["source_polygon"] = source_polygon
	body["source_top_poly"] = geometry["top_poly"].duplicate(true)
	body["visual_status"] = "direct_source_frame_not_uv_deformed; contact_approximation_requires_real_motor_and_art_review"
	return body

static func _source_to_world(point: Array, frame: Dictionary) -> Array:
	var source_x := float(point[0])
	if bool(frame["mirror_x"]):
		source_x = float(frame["source_size"][0]) - source_x
	return [_q(float(frame["origin"][0]) + source_x * float(frame["uniform_scale"])), _q(float(frame["origin"][1]) + float(point[1]) * float(frame["uniform_scale"]))]

static func _standing_anchor(body: Dictionary, x: float) -> Array:
	var anchor := _surface_anchor(body, x)
	if not anchor.is_empty():
		anchor[1] = _q(float(anchor[1]) - 18.0)
	return anchor

static func _outline_x_at_y(polygon: Array, y: float, choose_max: bool) -> float:
	var intersections: Array[float] = []
	for index: int in polygon.size():
		var a: Array = polygon[index]
		var b: Array = polygon[(index + 1) % polygon.size()]
		if is_equal_approx(float(a[1]), float(b[1])):
			continue
		if y >= minf(float(a[1]), float(b[1])) and y <= maxf(float(a[1]), float(b[1])):
			intersections.append(lerpf(float(a[0]), float(b[0]), (y - float(a[1])) / (float(b[1]) - float(a[1]))))
	if intersections.is_empty():
		return NAN
	intersections.sort()
	return _q(intersections[-1] if choose_max else intersections[0])

static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var registered_source: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not registered_source is Dictionary:
		errors.append("missing_external_source_frame_catalog")
		return errors
	var registered_catalog: Dictionary = registered_source
	if int(registered_catalog.get("world_coordinate_protocol", {}).get("subpixels_per_world", 0)) != WORLD_SUBPIXELS:
		errors.append("external_world_subpixel_protocol_mismatch")
	if str(registered_catalog.get("version", "")) != VERSION:
		errors.append("external_catalog_version_mismatch")
	if str(data.get("version", "")) != VERSION:
		errors.append("unregistered_world_version")
	var variant := int(data.get("variant", -1))
	if not registered_catalog.get("layout_variants", {}).has(str(variant)):
		errors.append("unregistered_source_layout_variant")
		return errors
	var registered_layout: Dictionary = registered_catalog["layout_variants"][str(variant)]
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
		var expected_body := _registered_source_body(id, registered_catalog, int(data.get("variant", -1)))
		if expected_body.is_empty():
			errors.append("body_id_not_registered_in_external_source_catalog:" + id)
			continue
		var expected_frame: Dictionary = expected_body["paint_frame"]
		if body.get("paint_frame", {}) != expected_frame:
			errors.append("paint_frame_differs_from_external_registration:" + id)
		if body.get("source_polygon", []) != expected_body["source_polygon"] or body.get("source_top_poly", []) != expected_body["source_top_poly"]:
			errors.append("source_outline_differs_from_external_registration:" + id)
		if body.get("polygon", []) != expected_body["polygon"]:
			errors.append("world_collision_does_not_equal_registered_source_transform:" + id)
		if body.get("top_surfaces", []) != expected_body["top_surfaces"]:
			errors.append("standing_surfaces_do_not_equal_registered_source_contacts:" + id)
		var path := str(expected_frame["source_path"])
		var source_sha_map: Dictionary = registered_catalog.get("source_sha_map", {})
		var registered_sha := str(source_sha_map.get(path, ""))
		if registered_sha.length() != 64:
			errors.append("missing_external_source_byte_hash:" + id)
		elif str(body.get("source_sha256", "")) != registered_sha:
			errors.append("body_source_hash_differs_from_external_registration:" + id)
		if not FileAccess.file_exists(path):
			errors.append("registered_paint_source_missing:" + id)
		else:
			if registered_sha.length() == 64 and FileAccess.get_sha256(path) != registered_sha:
				errors.append("registered_paint_source_bytes_changed:" + id)
			var source_texture := load(path) as Texture2D
			if source_texture == null:
				errors.append("registered_paint_source_not_decodable:" + id)
			elif source_texture.get_width() != int(expected_frame["source_size"][0]) or source_texture.get_height() != int(expected_frame["source_size"][1]):
				errors.append("registered_paint_source_size_mismatch:" + id)
		var points := PackedVector2Array()
		for point: Variant in body.get("polygon", []):
			if not point is Array or point.size() != 2:
				errors.append("invalid_polygon_coordinate:" + id)
				continue
			points.append(Vector2(float(point[0]), float(point[1])))
		if points.size() < 4 or Geometry2D.triangulate_polygon(points).is_empty():
			errors.append("body_not_triangulatable:" + id)
		if str(body.get("collision_source", "")) != "polygon" or str(body.get("painting_source", "")) != "paint_frame":
			errors.append("collision_and_painting_must_share_registered_source:" + id)
		for surface: Dictionary in body.get("top_surfaces", []):
			var a := Vector2(float(surface["from"][0]), float(surface["from"][1]))
			var b := Vector2(float(surface["to"][0]), float(surface["to"][1]))
			if b.x <= a.x:
				errors.append("surface_not_forward:" + id)
			if absf(rad_to_deg((b - a).angle())) > float(registered_catalog.get("limits", {}).get("max_walk_slope_degrees", 0)):
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
			if gap < 72.0 or (str(registered_layout["route_mode"]) == "upper_fissure" and gap > float(registered_catalog.get("limits", {}).get("max_source_rim_gap", 240.0))):
				errors.append("fissure_width_outside_registered_jump_and_painting_interface")
	if bodies.size() == 3:
		var west_polygon := _packed(bodies[0]["polygon"])
		var east_polygon := _packed(bodies[1]["polygon"])
		var bed_polygon := _packed(bodies[2]["polygon"])
		if Geometry2D.intersect_polygons(west_polygon, bed_polygon).is_empty() or Geometry2D.intersect_polygons(east_polygon, bed_polygon).is_empty():
			errors.append("creek_foundation_must_physically_join_both_ridge_roots")
		if not Geometry2D.intersect_polygons(west_polygon, east_polygon).is_empty():
			errors.append("open_fissure_must_not_be_filled_by_ridges")
		var actual_creek_y: float = float(bodies[2]["top_surfaces"][0]["from"][1])
		var wall_left := _outline_x_at_y(bodies[0]["polygon"], actual_creek_y, true)
		var wall_right := _outline_x_at_y(bodies[1]["polygon"], actual_creek_y, false)
		var bed_frame: Dictionary = bodies[2]["paint_frame"]
		var actual_overlap := _q(float(bed_frame["source_size"][0]) * float(bed_frame["uniform_scale"]) * 0.5 - (wall_right - wall_left) * 0.5)
		if actual_overlap < float(registered_layout["minimum_root_overlap"]):
			errors.append("actual_source_root_overlap_below_registered_layout_minimum")
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

static func _layout_geometry(catalog: Dictionary, variant: int) -> Dictionary:
	if not catalog.get("layout_variants", {}).has(str(variant)):
		return {}
	var geometry: Dictionary = catalog["source_geometry"].duplicate(true)
	var layout: Dictionary = catalog["layout_variants"][str(variant)]
	# Only finite registered frame origins and creek elevation vary. Source
	# pixels, source bytes and uniform scale remain the frozen family.
	for key: String in ["west_origin", "east_origin", "creek_surface_y"]:
		geometry[key] = layout[key]
	return geometry

static func _registered_source_body(id: String, catalog: Dictionary, variant: int = 0) -> Dictionary:
	# Trust the external catalog and actual source bytes, never a body's copied
	# provenance fields. Rebuild the expected frame and geometry independently.
	var geometry := _layout_geometry(catalog, variant)
	if geometry.is_empty():
		return {}
	if id == "west_meadow_ridge" or id == "east_meadow_ridge":
		var is_east := id == "east_meadow_ridge"
		var ridge_frame: Dictionary = {"source_path": geometry["east_source_path"] if is_east else geometry["source_path"], "source_size": geometry["source_size"], "origin": geometry["east_origin"] if is_east else geometry["west_origin"], "uniform_scale": geometry["east_scale"] if is_east else geometry["west_scale"], "mirror_x": is_east, "source_coordinate_mode": "full_image_pixels"}
		return _source_body(id, ridge_frame, geometry)
	if id != "creek_foundation":
		return {}
	var west_registered := _registered_source_body("west_meadow_ridge", catalog, variant)
	var east_registered := _registered_source_body("east_meadow_ridge", catalog, variant)
	var creek: float = float(geometry["creek_surface_y"])
	var west_wall := _outline_x_at_y(west_registered["polygon"], creek, true)
	var east_wall := _outline_x_at_y(east_registered["polygon"], creek, false)
	var scale: float = float(geometry["creek_fixed_scale"])
	var size: Array = geometry["creek_source_size"]
	var source_top: Array = geometry["creek_source_top_poly"]
	var origin: Array = [_q(_q((west_wall + east_wall) * 0.5) - float(size[0]) * scale * 0.5), _q(creek - float(source_top[0][1]) * scale)]
	var frame: Dictionary = {"source_path": geometry["creek_source_path"], "source_size": size, "origin": origin, "uniform_scale": scale, "mirror_x": false, "source_coordinate_mode": "full_image_pixels"}
	var result := _source_body(id, frame, {"top_poly": source_top, "side_poly": geometry["creek_source_side_poly"]})
	result["top_surfaces"] = [{"from": [west_wall, creek], "to": [east_wall, creek], "role": "lower_recovery"}]
	return result

static func _q(value: float) -> float:
	return float(roundi(value * WORLD_SUBPIXELS)) / WORLD_SUBPIXELS

static func _q_world_tree(value: Variant) -> Variant:
	if value is float:
		return _q(float(value))
	if value is Array:
		var result: Array = []
		for child: Variant in value:
			result.append(_q_world_tree(child))
		return result
	if value is Dictionary:
		var mapping: Dictionary = {}
		for key: Variant in value:
			mapping[key] = value[key] if str(key) in ["source_polygon", "source_top_poly", "source_size", "uniform_scale", "source_geometry", "player_source"] else _q_world_tree(value[key])
		return mapping
	return value

static func _surface_anchor(body: Dictionary, x: float) -> Array:
	for surface: Dictionary in body.get("top_surfaces", []):
		var a: Array = surface["from"]
		var b: Array = surface["to"]
		if x >= float(a[0]) and x <= float(b[0]) and float(b[0]) > float(a[0]):
			var weight := (x - float(a[0])) / (float(b[0]) - float(a[0]))
			return [_q(x), _q(lerpf(float(a[1]), float(b[1]), weight))]
	return []

static func _packed(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value: Array in values:
		result.append(Vector2(float(value[0]), float(value[1])))
	return result

static func _body(id: String, kind: String, polygon: Array, surfaces: Array, connections: Array) -> Dictionary:
	return {"id": id, "kind": kind, "polygon": polygon, "top_surfaces": surfaces, "collision_source": "polygon", "painting_source": "paint_frame", "paint_family": "p1_continuous_meadow_candidate", "paint_z": -2, "connections": connections, "visual_status": "source_frame_candidate_requires_actual_art_admission"}

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
