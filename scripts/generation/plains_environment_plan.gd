class_name PlainsEnvironmentPlan
extends RefCounted
## Explicit development content. A resolved plan owns collision and visual anchors.
const CONTRACT_PATH := "res://resources/generation/environment_grammar/lee_post_v1.json"
const VERSION := "plains-environment-candidate-v1"

static func generate(seed_value: String, tuning: PlayerTuning, variant: String = "A", mutation: String = "") -> Dictionary:
	if seed_value.is_empty() or tuning == null or tuning.max_jumps < 1 or tuning.max_air_shots < 2:
		return {"ok": false, "error": "Environment candidate requires the actual base jump and two native shots"}
	if variant != "A" or mutation not in ["", "remove-recovery-bank"]:
		return {"ok": false, "error": "Unverified environment variant or mutation"}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if not raw is Dictionary or raw.get("schema_version") != 1:
		return {"ok": false, "error": "Environment source plan is invalid"}
	var plan: Dictionary = raw.duplicate(true)
	plan.seed = seed_value
	plan.contract_sha256 = FileAccess.get_sha256(CONTRACT_PATH)
	plan.mutation = mutation
	plan.player_tuning_sha256 = FileAccess.get_sha256("res://config/player_tuning.json")
	var phases := RunRandomStream.new(seed_value, "environment_phases", "postal_wind_gear", VERSION)
	for mechanism: Dictionary in plan.mechanisms:
		mechanism.initial_phase = float(phases.next_int(4)) / 4.0
	if mutation == "remove-recovery-bank":
		plan.solid_polygons = plan.solid_polygons.filter(func(p: Dictionary) -> bool: return p.id != "fissure_bank")
	_resolve_surfaces(plan)
	var errors := design_errors(plan)
	if not errors.is_empty(): return {"ok": false, "error": "; ".join(errors)}
	var m := {"version": VERSION, "seed": seed_value, "region": "plains", "layout_id": "environment_development_candidate", "family": "lee_post_A", "production_pool": false, "world_bounds": plan.bounds, "spawn": plan.spawn, "areas": [], "nodes": [], "connections": [], "ground_supports": [], "terminal_exits": [], "rewards": [], "pickups": [], "enemies": plan.enemies.duplicate(true), "enemy_drops": {}, "merchant_id": "", "merchant_position": [1000000,1000000], "boss_arena": [-2000,-2000,1,1], "shot_latch_plan": {"version": "environment_no_latches_v1", "latches": []}, "environment_plan": plan, "streams": {"phases": "environment_phases", "phases_position": phases.position(), "algorithm": RunRandomStream.ALGORITHM}}
	var points: Array[Vector2] = []
	for place: Dictionary in plan.places:
		m.areas.append({"id": place.id, "position": place.entry_port.position, "role": "junction", "identity": place.id, "label": place.label})
		m.nodes.append({"id": "environment/" + str(place.id), "place_id": place.id, "module_id": "environment_polygon", "offset": [0,0], "mirrored": false})
		for stand: Dictionary in place.safe_stands: points.append(Vector2(stand.position[0],stand.position[1]))
	for index: int in plan.places.size() - 1:
		var a: Dictionary = plan.places[index]
		var b: Dictionary = plan.places[index+1]
		m.connections.append({"id": "environment/"+str(a.id)+"/"+str(b.id), "a": a.id, "b": b.id, "condition": "open", "kind": "horizontal", "bidirectional": true, "path": [a.exit_port.position,b.entry_port.position], "modules": [index,index+1]})
	var drops := EnemyDropService.new()
	if not drops.configure(seed_value,"plains_region"):
		return {"ok": false, "error": "Original enemy drop service rejected candidate seed"}
	for enemy: Dictionary in m.enemies: m.enemy_drops[enemy.id] = drops.settle(StringName(enemy.id))
	m.manifest_hash = _hash(m)
	return {"ok": true, "manifest": m, "environment_plan": plan, "placement_points": points, "boss_arena": Rect2(-2000,-2000,1,1), "stage_generator_version": VERSION, "encounter_plan": {"version": VERSION, "enemies": m.enemies}, "shot_latch_plan": m.shot_latch_plan}

static func validate_recorded(recorded: Dictionary, tuning: PlayerTuning) -> bool:
	if recorded.get("version") != VERSION or not recorded.get("environment_plan") is Dictionary:
		return false
	var plan: Dictionary = recorded.environment_plan
	var replay := generate(str(recorded.get("seed","")),tuning,str(plan.get("structure_variant","")),str(plan.get("mutation","")))
	return replay.get("ok",false) and recorded.get("manifest_hash") == _hash(recorded) and replay.manifest.manifest_hash == recorded.manifest_hash

static func _hash(data: Dictionary) -> String:
	var copy := data.duplicate(true)
	copy.erase("manifest_hash")
	return JSON.stringify(copy,"",true).sha256_text()

static func _resolve_surfaces(plan: Dictionary) -> void:
	var solids: Dictionary = {}
	for solid: Dictionary in plan.solid_polygons: solids[solid.id] = solid
	var surfaces: Dictionary = {}
	for surface: Dictionary in plan.surfaces:
		surface.points = []
		if not solids.has(surface.solid_id): continue
		var points: Array = solids[surface.solid_id].points
		for index: int in surface.edge_indices:
			if surface.points.is_empty(): surface.points.append(points[index])
			surface.points.append(points[(index+1)%points.size()])
		surfaces[surface.id] = surface
	for attachment: Dictionary in plan.attachments:
		attachment.available = surfaces.has(attachment.surface_id)
		if not attachment.available: continue
		attachment.position = _surface_point(surfaces[attachment.surface_id].points,float(attachment.t))
	for place: Dictionary in plan.places:
		place.safe_stands = place.safe_stands.filter(func(s: Dictionary) -> bool: return surfaces.has(s.surface_id))
	plan.safe_stands = []
	for place: Dictionary in plan.places: plan.safe_stands.append_array(place.safe_stands)

static func _surface_point(points: Array, t: float) -> Array:
	var total := 0.0
	for index: int in points.size()-1: total += Vector2(points[index+1][0]-points[index][0],points[index+1][1]-points[index][1]).length()
	var remaining := clampf(t,0.0,1.0)*total
	for index: int in points.size()-1:
		var a := Vector2(points[index][0],points[index][1])
		var b := Vector2(points[index+1][0],points[index+1][1])
		var distance := a.distance_to(b)
		if remaining <= distance:
			var point := a.lerp(b,remaining/maxf(distance,0.001))
			return [point.x,point.y]
		remaining -= distance
	return points.back().duplicate()

static func design_errors(plan: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	for solid: Dictionary in plan.solid_polygons:
		if ids.has(solid.id): errors.append("Duplicate solid id")
		ids[solid.id] = true
		var polygon := PackedVector2Array()
		for p: Array in solid.points:
			var point := Vector2(p[0],p[1])
			if not point.is_finite(): errors.append("Non-finite collision point")
			polygon.append(point)
		if polygon.size()<3 or Geometry2D.triangulate_polygon(polygon).is_empty(): errors.append("Non-simple collision polygon: "+str(solid.id))
	if plan.places.size() != 5: errors.append("Candidate must preserve its five continuous places")
	for waypoint: Dictionary in plan.route_waypoints:
		if float(waypoint.tolerance)>22.0 or not bool(waypoint.require_grounded): errors.append("Route standing contract changed")
	return errors

static func create_stage() -> PlainsRegionStage:
	var script := load("res://scripts/demo/plains_environment_stage.gd") as Script
	return script.new() as PlainsRegionStage
