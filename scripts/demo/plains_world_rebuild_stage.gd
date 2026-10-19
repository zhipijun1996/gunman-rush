class_name PlainsWorldRebuildStage
extends GeneratedDemoStage
## Isolated world-first experiment. No old platform module, rear-wall or scenery
## geometry is instantiated. Collision and painting read the same world bodies.
var world_plan: Dictionary = {}
var world_composer: Node2D
var body_colliders: Array[CollisionPolygon2D] = []

func configure_world(data: Dictionary, player_tuning: PlayerTuning) -> void:
	world_plan = data.duplicate(true)
	tuning = player_tuning
	# Small adapter for the existing Run logging/HUD contract; this is explicitly
	# not a PlainsRegionGenerator Manifest and does not claim old save compatibility.
	generated = {"stage_generator_version":str(data.get("version","")), "placement_points":[],
		"manifest":{"seed":str(data.get("root_seed","")), "nodes":[{"id":"continuous_world", "mirrored":false}],
		"shot_latch_plan":{}, "world_rebuild_plan":world_plan}}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var generator := load("res://scripts/generation/plains_world_rebuild.gd") as Script
	var errors: Array = generator.validate(world_plan)
	if not errors.is_empty():
		push_error("World rebuild refused: " + str(errors))
		return
	var values: Array = world_plan.bounds
	bounds = Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))
	exits.clear()
	exit_positions.clear()
	spawn = point(world_plan.spawn)
	anchor_position = spawn
	supply_position = spawn
	reward_position = point(world_plan.exit)
	# Keep the normal shared damage/lifetime interfaces without generating any
	# legacy modules. All physical bodies below belong to the new world plan.
	assembler = RandomStageAssembler.new()
	assembler.name = "WorldRunAdapterNoLegacyModules"
	add_child(assembler)
	assembler.bounds = bounds
	anchors.append(spawn)
	generated.placement_points.append(spawn)
	for body: Dictionary in world_plan.bodies:
		var solid := StaticBody2D.new()
		solid.name = str(body.id).validate_node_name()
		solid.collision_layer = 1
		solid.collision_mask = 0
		var collider := CollisionPolygon2D.new()
		collider.name = "SharedWorldPolygon"
		var polygon := PackedVector2Array()
		for value: Array in body.polygon:
			polygon.append(point(value))
		collider.polygon = polygon
		collider.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		collider.one_way_collision = false
		collider.set_meta("world_body_id",str(body.id))
		solid.add_child(collider)
		add_child(solid)
		body_colliders.append(collider)
	for row: Dictionary in world_plan.get("enemy_spawns",[]):
		var drone := PATROL.instantiate() as EnemyMotor
		drone.name = str(row.id).validate_node_name()
		drone.position = point(row.position)
		var actor := drone.get_node("Actor") as EnemyActor
		var definition := load(str(row.definition)) as EnemyDefinition
		if definition == null:
			push_error("World rebuild enemy Definition missing")
			return
		actor.definition = definition.duplicate(true) as EnemyDefinition
		add_child(drone)
		enemies.append(drone)
		enemy_manifest.append({"id":str(row.id),"position":row.position,"definition":row.definition})
	if not enemies.is_empty():enemy = enemies[0]
	encounter_plan = {"version":"world-rebuild-existing-enemy-v1","enemies":enemy_manifest.duplicate(true)}
	var composer_script := load("res://scripts/art/plains_world_rebuild_composer.gd") as Script
	if composer_script == null:
		push_error("World rebuild real painting consumer missing")
		return
	world_composer = composer_script.new() as Node2D
	world_composer.name = "WorldPainting"
	add_child(world_composer)
	world_composer.call("configure",world_plan)
	assembly_ok = true

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

func setup_shot_latches(_controller: PlayerController, _lifetime: DemoLifetime) -> bool:
	# This experiment contains no legacy shot-latch layout. No grant or reset.
	return world_plan.get("device_spawns",[]).is_empty()

func reached_finish(_location: Vector2) -> bool:
	# Review space stays open; never advances into an unrelated formal map.
	return false

func get_world_rebuild_snapshot() -> Dictionary:
	var physical: Array = []
	for collider: CollisionPolygon2D in body_colliders:
		var polygon: Array = []
		for value: Vector2 in collider.polygon:
			polygon.append([value.x,value.y])
		physical.append({"id":collider.get_meta("world_body_id"),"polygon":polygon,
			"disabled":collider.disabled,"one_way":collider.one_way_collision,
			"build_mode":collider.build_mode,"collision_layer":(collider.get_parent() as StaticBody2D).collision_layer})
	var painting: Dictionary = {}
	if is_instance_valid(world_composer) and world_composer.has_method("measured_nodes"):
		painting = world_composer.call("measured_nodes")
	return {"ready":assembly_ok,"world_plan":world_plan,"actual_collisions":physical,
		"painting":painting,"actual_enemies":enemies.size(),"legacy_modules":assembler.modules.size() if assembler!=null else 0,
		"production_pool":false,"route_validation":"unverified_until_actual_input_trace"}

func _draw() -> void:
	pass
