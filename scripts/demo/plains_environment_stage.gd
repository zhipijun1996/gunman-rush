class_name PlainsEnvironmentStage
extends PlainsRegionStage
## Real DemoApp candidate; intentionally not admitted into the two-map content pool.
var environment_plan: Dictionary = {}
var environment_renderer: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	environment_plan = generated.environment_plan
	if region_state == null: region_state = PlainsRegionState.new()
	if not region_state.bind_map(str(generated.manifest.manifest_hash)): return
	var environment_assembler := PlainsEnvironmentAssembler.new()
	assembler = environment_assembler
	environment_assembler.region_state = region_state
	add_child(assembler)
	var result := assembler.build(generated.manifest,tuning)
	if not result.ok:
		push_error(str(result.error))
		return
	assembly_ok = true
	bounds = assembler.bounds
	spawn = assembler.world_entry()
	anchors = assembler.world_anchors()
	anchor_position = Vector2(environment_plan.places[1].entry_port.position[0],environment_plan.places[1].entry_port.position[1])
	if generated.manifest.get("version") == PlainsPlacePlan.VERSION:
		var recovery: Array = environment_plan.places[1].safe_stands[0].position
		anchor_position = Vector2(recovery[0],recovery[1])
	merchant_position = Vector2.INF
	supply_position = spawn
	reward_position = Vector2(environment_plan.places.back().exit_port.position[0],environment_plan.places.back().exit_port.position[1])
	boss_arena = Rect2(-2000,-2000,1,1)
	exits.clear()
	exit_positions.clear()
	encounter_plan = generated.encounter_plan
	_spawn_enemies_from_plan()
	for index: int in enemies.size():
		var id: String = enemy_manifest[index].id
		if not region_state.actors.has(id): continue
		var actor := enemies[index].get_node("Actor") as EnemyActor
		var saved: Dictionary = region_state.actors[id]
		if not actor.restore_instance_health(float(saved.health)):
			assembly_ok = false
			return
		if saved.has("position"): enemies[index].position = Vector2(saved.position[0],saved.position[1])
		if float(saved.health)<=0: enemies[index].hide()
	var map_layer := CanvasLayer.new()
	map_layer.layer = 1
	add_child(map_layer)
	map_view = PlainsRegionMap.new()
	map_view.stage = self
	map_view.region_chip = true
	map_view.position = Vector2(1098,14)
	map_layer.add_child(map_view)
	set_meta("visual_language_sample_path","res://resources/visual_development/p1_candidate.json")
	var actor_script := load("res://scripts/art/visual_language_sample.gd") as Script
	var actor_presentation := actor_script.new() as Node2D
	actor_presentation.call("configure",self,{"presentation_scope":"formal_second_space"})
	add_child(actor_presentation)
	var renderer_path := "res://scripts/art/plains_environment_composer.gd"
	if generated.manifest.get("version") == PlainsPlacePlan.VERSION:
		renderer_path = "res://scripts/art/plains_place_composer.gd"
	if ResourceLoader.exists(renderer_path):
		var script := load(renderer_path) as Script
		if script != null:
			environment_renderer = script.new() as Node2D
			add_child(environment_renderer)
			environment_renderer.call("install",self,environment_plan)
	print("PLAINS ENVIRONMENT CANDIDATE: real polygon modules; production_pool=false; plan=",environment_plan.contract_sha256)

func setup_shot_latches(_controller: PlayerController, _lifetime: DemoLifetime) -> bool:
	return true

func capture_state() -> void:
	if not assembly_ok: return
	PlainsMapExploration.reveal(region_state,global_player_position())
	for place: Dictionary in environment_plan.places:
		var r: Array = place.bounds
		if Rect2(r[0],r[1],r[2],r[3]).has_point(global_player_position()):
			region_state.visited[place.id] = true
			visited_area = str(place.label)
	for index: int in assembler.modules.size():
		region_state.clocks[generated.manifest.nodes[index].id] = assembler.modules[index].clock
	for index: int in enemies.size():
		var actor := enemies[index].get_node("Actor") as EnemyActor
		region_state.actors[enemy_manifest[index].id] = actor.region_snapshot()

func composition_focus() -> Vector2: return Vector2.INF

func get_environment_snapshot() -> Dictionary:
	var actual: Array[Dictionary] = []
	var saws: Array[Dictionary] = []
	for module: PlainsEnvironmentModule in assembler.modules:
		for shape: CollisionPolygon2D in module.collision_nodes:
			var points: Array = []
			for p: Vector2 in shape.polygon:
				var world := shape.global_transform*p
				points.append([world.x,world.y])
			actual.append({"node_path":str(shape.get_path()),"points":points,"disabled":shape.disabled})
		for saw: ModuleSawHazard in module.hazards:
			saws.append({"node_path":str(saw.get_path()),"position":[saw.global_position.x,saw.global_position.y],"radius":saw.definition.radius,"enabled":saw.enabled,"clock":module.clock})
	var art: Dictionary = {}
	if is_instance_valid(environment_renderer) and environment_renderer.has_method("measured_nodes"):
		art = environment_renderer.call("measured_nodes")
	return {"environment_plan":environment_plan,"manifest_hash":generated.manifest.manifest_hash,"solid_polygons":actual,"saws":saws,"art":art,"production_pool":false,"scope":"Explicit development places through original DemoApp systems; not admitted campaign content"}

func _draw() -> void:
	# Original actors, hazards, HUD and contacts remain their actual consumers.
	pass
