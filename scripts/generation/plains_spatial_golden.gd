class_name PlainsSpatialGolden
extends RefCounted
## Explicit experimental content consumer. Ordinary region replay is untouched.
const CONTRACT_PATH := "res://resources/generation/spatial_golden/against_wind_v1.json"

static func generate(seed_value: String, mutation: String = "", open_meadow: bool = false) -> Dictionary:
	if not FileAccess.file_exists(CONTRACT_PATH): return {"ok": false, "error": "Missing spatial golden contract"}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if not raw is Dictionary or raw.get("schema_version") != 1 or raw.get("region_id") != "windchime_plains":
		return {"ok": false, "error": "Invalid spatial golden contract"}
	if mutation not in ["", "remove-recovery-bank"]: return {"ok": false, "error": "Unknown spatial golden mutation"}
	var design: Dictionary = raw.design.duplicate(true)
	design.seed = seed_value
	design.contract_sha256 = FileAccess.get_sha256(CONTRACT_PATH)
	design.mutation = mutation
	if open_meadow:
		# VISUAL-LANGUAGE-01 is a separately identified open-meadow layout.
		# Remove both real polygons before assembly; never hide live collision.
		design.version = "visual-language-open-meadow-v1"
		design.layout_variant = "open_meadow"
		design.solid_polygons = design.solid_polygons.filter(func(p: Dictionary) -> bool: return p.id not in ["left_bell_rib","right_bell_rib"])
		design.architecture_ribs = []
		design.landmark_anchors.erase("left_rib_crown")
		design.landmark_anchors.erase("right_rib_crown")
		design.action_intent = [
			"Open grass-sea visual-language experiment: three actual shores, no hidden bell-rib collision or rib enclosure claim.",
			"First fissure240px,receiver60px higher: original held jump plus accepted backward/downward shot, no new ability.",
			"Recover at x920; automatic memory vessel observes the original successful safe-anchor history rather than a distance-only visual cue.",
			"Observe live RootBell at1240 on original horizontal support, then cross the second rise with original gear and accepted recoil.",
			"Look back from1800,502 over the same two fissures; normal camera, route and reverse-traversal resource rules remain unchanged."
		]
	if mutation == "remove-recovery-bank":
		design.solid_polygons = design.solid_polygons.filter(func(p: Dictionary) -> bool: return p.id != "recovery_shore")
		design.top_polylines = design.top_polylines.filter(func(p: Dictionary) -> bool: return p.id != "recovery_grass")
	var digest := JSON.stringify(design, "", true).sha256_text()
	var m := {"version": design.version, "seed": seed_value, "region": "plains", "layout_id": "visual_language_open_meadow" if open_meadow else "explicit_spatial_golden", "family": "against_wind_golden", "manifest_hash": digest, "world_bounds": design.bounds, "spawn": design.spawn, "areas": [], "connections": [], "nodes": [{"id": "spatial_golden/module", "module_id": "spatial_golden_polygon", "offset": [0,0], "mirrored": false, "solid_polygons": design.solid_polygons}], "enemies": [design.enemy], "pickups": [], "rewards": [], "terminal_exits": [], "ground_supports": [], "shot_latch_plan": {"version": "spatial_golden_no_latches", "latches": []}, "golden_manifest": design}
	for id: String in ["entry", "recovery", "lookback"]:
		m.areas.append({"id": id, "position": design.route_waypoints[id], "role": "junction", "identity": "spatial_golden", "label": "逆风送钟"})
	for pair: Array in [["entry", "recovery"], ["recovery", "lookback"]]:
		var a: Array = design.route_waypoints[pair[0]]
		var b: Array = design.route_waypoints[pair[1]]
		m.connections.append({"id": "spatial_golden/" + pair[0] + "/" + pair[1], "a": pair[0], "b": pair[1], "path": [a,b], "condition": "open", "kind": "horizontal", "bidirectional": true, "modules": [0]})
	return {"ok": true, "manifest": m, "golden_manifest": design, "placement_points": [], "boss_arena": Rect2(), "stage_generator_version": design.version, "encounter_plan": {"version": design.version, "enemies": [design.enemy]}, "shot_latch_plan": m.shot_latch_plan}

static func create_stage() -> PlainsRegionStage:
	return GoldenStage.new()

static func create_camera(profile: Dictionary) -> StageCameraRig:
	var camera := GoldenCamera.new()
	camera.composition_center_y = float(profile.composition_center_y)
	return camera

class GoldenModule extends PlatformingModule:
	var golden_manifest: Dictionary
	var collision_nodes: Array[CollisionPolygon2D] = []
	func _ready() -> void:
		# Polygon content has its own explicit contract; the legacy rectangle
		# authoring validator and its admitted module pool are not weakened.
		process_mode = Node.PROCESS_MODE_PAUSABLE
		process_physics_priority = -200
		for solid: Dictionary in golden_manifest.solid_polygons:
			var points := PackedVector2Array()
			for p: Array in solid.points: points.append(Vector2(p[0],p[1]))
			var body := StaticBody2D.new()
			body.name = str(solid.id)
			body.collision_layer = 1
			var shape := CollisionPolygon2D.new()
			shape.name = "ActualPolygon"
			shape.polygon = points
			body.add_child(shape)
			add_child(body)
			collision_nodes.append(shape)
		var hazard := ModuleSawHazard.new()
		hazard.name = str(definition.saws[0].source_id)
		hazard.definition = definition.saws[0]
		hazard.module = self
		hazards.append(hazard)
		add_child(hazard)
		queue_redraw()
	func _draw() -> void:
		if bool(get_meta("art_active", false)): return
		for solid: Dictionary in golden_manifest.solid_polygons:
			var points := PackedVector2Array()
			for p: Array in solid.points: points.append(Vector2(p[0],p[1]))
			draw_colored_polygon(points, Color("354b4d") if solid.material == "clock_rib" else Color("82938b"))
		for edge: Dictionary in golden_manifest.top_polylines:
			var points := PackedVector2Array()
			for p: Array in edge.points: points.append(Vector2(p[0],p[1]))
			draw_polyline(points, Color("b9cd8a"), 4.0, true)

class GoldenAssembler extends PlainsRegionAssembler:
	var golden_manifest: Dictionary
	func build(recorded: Dictionary, _tuning: PlayerTuning) -> Dictionary:
		manifest = recorded.duplicate(true)
		golden_manifest = manifest.golden_manifest
		var b: Array = golden_manifest.bounds
		bounds = Rect2(b[0],b[1],b[2],b[3])
		var module := GoldenModule.new()
		module.name = "SpatialGoldenPolygonModule"
		module.golden_manifest = golden_manifest
		module.authoring_debug = false
		var d := PlatformingModuleDefinition.new()
		d.module_id = &"spatial_golden_polygon"
		d.world_bounds = bounds
		d.entry_port = PlatformingModulePort.new()
		d.entry_port.port_id = &"entry"
		d.entry_port.position = Vector2(golden_manifest.spawn[0],golden_manifest.spawn[1])
		d.exit_port = PlatformingModulePort.new()
		d.exit_port.port_id = &"lookback"
		var exit: Array = golden_manifest.route_waypoints.lookback
		d.exit_port.position = Vector2(exit[0],exit[1])
		for p: Array in golden_manifest.anchors: d.anchors.append(Vector2(p[0],p[1]))
		for r: Array in golden_manifest.danger_bounds: d.danger_bounds.append(Rect2(r[0],r[1],r[2],r[3]))
		var mech: Dictionary = golden_manifest.mechanism
		var saw := ModuleSawDefinition.new()
		saw.source_id = StringName(mech.id)
		saw.origin = Vector2(mech.origin[0],mech.origin[1])
		saw.travel = Vector2(mech.travel[0],mech.travel[1])
		saw.radius = mech.radius
		saw.period = mech.period
		saw.initial_phase = mech.initial_phase
		d.saws.append(saw)
		module.definition = d
		modules.append(module)
		add_child(module)
		return {"ok": true}
	func world_entry() -> Vector2:
		return Vector2(golden_manifest.spawn[0],golden_manifest.spawn[1])
	func world_anchors() -> Array[Vector2]:
		return modules[0].world_anchors()
	func world_exits() -> Array[Dictionary]: return []

class GoldenStage extends PlainsRegionStage:
	var golden_manifest: Dictionary
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		golden_manifest = generated.golden_manifest
		if region_state == null: region_state = PlainsRegionState.new()
		if not region_state.bind_map(str(generated.manifest.manifest_hash)): return
		assembler = GoldenAssembler.new()
		add_child(assembler)
		var result := assembler.build(generated.manifest,tuning)
		if not result.ok: return
		assembly_ok = true
		bounds = assembler.bounds
		spawn = assembler.world_entry()
		anchors = assembler.world_anchors()
		anchor_position = Vector2(golden_manifest.route_waypoints.recovery[0],golden_manifest.route_waypoints.recovery[1])
		merchant_position = Vector2.INF
		supply_position = spawn
		reward_position = Vector2(golden_manifest.route_waypoints.lookback[0],golden_manifest.route_waypoints.lookback[1])
		boss_arena = Rect2(-2000,-2000,1,1)
		exits.clear()
		exit_positions.clear()
		encounter_plan = generated.encounter_plan
		_spawn_enemies_from_plan()
		var map_layer := CanvasLayer.new()
		map_layer.layer = 1
		add_child(map_layer)
		map_view = GoldenMap.new()
		map_view.stage = self
		map_view.region_chip = true
		map_view.position = Vector2(1098,14)
		map_layer.add_child(map_view)
		var art_path := "res://scripts/art/plains_spatial_golden_art.gd"
		if not str(get_meta("visual_language_sample_path", "")).is_empty():
			art_path = "res://scripts/art/visual_language_sample.gd"
		# Exported scripts are remapped to .gdc; resolve the resource rather
		# than silently skipping the actual art consumer in a PCK.
		if ResourceLoader.exists(art_path):
			var script := load(art_path) as Script
			if script != null:
				var art: Node2D = script.new()
				if art.has_method("configure"):
					art.call("configure",self,golden_manifest)
					add_child(art)
					assembler.modules[0].set_meta("art_active",true)
					assembler.modules[0].queue_redraw()
		print("SPATIAL GOLDEN: true polygon collision, original DemoApp systems, explicit experimental content; contract=",golden_manifest.contract_sha256)
	func setup_shot_latches(_controller: PlayerController, _lifetime: DemoLifetime) -> bool:
		# This first space uses the actual moving gear, no bell gate is claimed.
		return true
	func capture_state() -> void:
		if not assembly_ok: return
		PlainsMapExploration.reveal(region_state,global_player_position())
		visited_area = "逆风送钟"
		for index: int in enemies.size():
			var actor := enemies[index].get_node("Actor") as EnemyActor
			region_state.actors[enemy_manifest[index].id] = {"health":actor.health.current}
		region_state.clocks["spatial_golden/module"] = assembler.modules[0].clock
	func composition_focus() -> Vector2: return Vector2.INF
	func get_spatial_snapshot() -> Dictionary:
		var module := assembler.modules[0] as GoldenModule
		var actual: Array[Dictionary] = []
		for shape: CollisionPolygon2D in module.collision_nodes:
			var points: Array = []
			for p: Vector2 in shape.polygon:
				var world := shape.global_transform * p
				points.append([world.x,world.y])
			actual.append({"node_path":str(shape.get_path()),"points":points,"disabled":shape.disabled})
		var saws: Array[Dictionary] = []
		for saw: ModuleSawHazard in module.hazards: saws.append({"position":[saw.global_position.x,saw.global_position.y],"enabled":saw.enabled,"clock":module.clock,"radius":saw.definition.radius})
		return {"golden_manifest":golden_manifest,"mutation":golden_manifest.mutation,"solid_polygons":actual,"saws":saws,"spawn":[spawn.x,spawn.y],"scope":"Actual experimental polygon consumers; no old region geometry or AI instantiated"}

class GoldenMap extends PlainsRegionMap:
	func _draw() -> void:
		if expanded:
			super._draw()
			return
		draw_style_box(panel(),Rect2(Vector2.ZERO,size))
		draw_string(ThemeDB.fallback_font,Vector2(12,21),"逆风送钟",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("dbd7ab"))


class GoldenCamera extends StageCameraRig:
	var composition_center_y := 560.0
	## A single-room vertical composition; horizontal motion uses the original Rig.
	## The actual actor envelope always wins over the compositional center.
	func snap_to_target() -> void:
		super.snap_to_target()
		if not is_instance_valid(target): return
		_apply_room_composition(target.global_position)
	func advance_follow(actor_position: Vector2, movement_speed: float, run_speed: float, delta: float) -> void:
		super.advance_follow(actor_position,movement_speed,run_speed,delta)
		_apply_room_composition(actor_position)
	func _apply_room_composition(actor_position: Vector2) -> void:
		var margin := (get_viewport_rect().size/(2.0*zoom)-Vector2(64,64)).max(Vector2(24,24))
		var desired_y := clampf(composition_center_y,actor_position.y-margin.y,actor_position.y+margin.y)
		var safe := bounded_center(Vector2(global_position.x,desired_y))
		_anchor.y=safe.y
		_spring_velocity.y=0.0
		global_position=safe
