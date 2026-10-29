extends SceneTree
## ER-02-04 native lifecycle fixture. Health initialize/restore here deliberately
## exercises paused epochs; this is not gameplay/video evidence or injected combat.
const FOREST := ["forest_lantern","forest_seed_sentry","forest_bark_beetle","forest_swing_pod","forest_crossbranch","forest_thread_spider","forest_bible_weaver"]
var checks := 0
var failures: Array[String] = []
var world: Node2D
var mesh_cases: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)
func ticks(count: int) -> void:
	for _index: int in count: await process_frame

func make_actor(id: String,initial_terminal: bool) -> EnemyActor:
	var prototype := id.begins_with("candidate_")
	var source := "patrol_drone" if prototype else id
	var motor := (load("res://scenes/enemies/%s.tscn" % source) as PackedScene).instantiate() as EnemyMotor
	var actor := motor.get_node("Actor") as EnemyActor
	actor.definition = (load("res://resources/enemies/%s.tres" % ("plains_charger" if prototype else id)) as EnemyDefinition).duplicate(true)
	actor.definition.health_definition = actor.definition.health_definition.duplicate(true) as HealthDefinition
	if initial_terminal: actor.definition.health_definition.initial_current = 0.0
	if prototype:
		actor.definition.stable_id = StringName(id)
		actor.definition.aerial = id=="candidate_crosswind_moth"
		actor.definition.collision_size = Vector2(32,36)
		motor.get_node("Presentation").free()
		var art := PrototypeEnemyPresentation.new()
		art.actor = actor
		art.moth = actor.definition.aerial
		art.name = "Presentation"
		motor.add_child(art)
	world.add_child(motor)
	actor.set_physics_process(false)
	return actor

func poison_previous_epoch(host: Node2D) -> void:
	if host is PrototypeEnemyPresentation:
		host.set("_clock",7.0);host.set("_death_time",0.02)
		host.set("_stride",6.0);host.set("_walking",1.0)
		host.set("_loading",1.0);host.set("_releasing",1.0);host.set("_recovering",1.0)
		host.set("_display_facing",0.25);host.set("_hurt_joint",0.5)
	else:
		var motion := host.get("motion") as ForestMotion02
		motion.clock = 7.0;motion.stride = 6.0
		motion.tension = 1.0;motion.release = 1.0;motion.flight = 1.0
		motion.death_elapsed = 0.02
		motion.set("_facing",0.25);motion.set("_last_body_pose",Vector2(.8,1.2))

func assert_synced(actor: EnemyActor,terminal: bool,label: String) -> void:
	var host := actor.motor.get_node("Presentation") as Node2D
	var sample := (host.get_meta(EnemyHitTemplate.METADATA) as EnemyHitTemplate).sample
	if host is PrototypeEnemyPresentation:
		check(int(host.get("_prototype_epoch"))==actor.health.epoch,label+" prototype immediate current epoch")
		check(float(host.get("_clock"))==0.0 and float(host.get("_stride"))==0.0 and float(host.get("_walking"))==0.0,label+" prototype clocks/gait cleared while paused")
		check(float(host.get("_loading"))==0.0 and float(host.get("_releasing"))==0.0 and float(host.get("_recovering"))==0.0 and float(host.get("_hurt_joint"))==0.0,label+" prototype joints cleared while paused")
		check(float(host.get("_display_facing"))==float(actor.brain.direction),label+" prototype facing is current epoch")
		check(float(host.get("_death_time"))==(0.6 if terminal else 0.0),label+" prototype restored terminal directly settled")
	else:
		var motion := host.get("motion") as ForestMotion02
		check(int(motion.get("_epoch"))==actor.health.epoch,label+" forest immediate current epoch")
		check(motion.clock==0.0 and motion.stride==0.0,label+" forest clocks/gait cleared while paused")
		check(motion.tension==0.0 and motion.release==0.0 and motion.flight==0.0 and motion.get("_last_body_pose")==Vector2.ONE,label+" forest previous epoch joints cleared")
		check(float(motion.get("_facing"))==float(actor.brain.direction),label+" forest facing is current epoch")
		check(motion.death_elapsed==(ForestMotion02.DEATH_SECONDS if terminal else 0.0),label+" forest restored terminal directly settled")
	check(sample.hurt_remaining==0.0 and sample.flash_strength()==0.0,label+" original accepted state cleared")
	check(sample.accepted_death_count==0,label+" restoration creates no accepted defeat replay")

func check_prototype_orientation(actor: EnemyActor,label: String) -> void:
	var host := actor.motor.get_node("Presentation") as PrototypeEnemyPresentation
	var points: PackedVector2Array = host.get("_native_points")
	var mesh := host.get("_mesh") as ArrayMesh
	check(points.size()==63 and mesh.get_surface_count()==1,label+" actual shared mesh retains all 63 vertices")
	check(actor.restore_instance_health(0.0),label+" mesh envelope terminal test fixture")
	var minimum_area := INF
	var nonpositive := 0
	var poses := 0
	for elapsed: float in [0.0,0.15,0.30,0.45]:
		for loading: float in [0.0,1.0]:
			for releasing: float in [0.0,1.0]:
				for recovering: float in [0.0,1.0]:
					for hurt: float in [0.0,0.6]:
						for clock: float in [0.0,0.2,0.8]:
							for stride: float in [0.0,PI*0.5]:
								host.set("_death_time",elapsed);host.set("_clock",clock)
								host.set("_loading",loading);host.set("_releasing",releasing);host.set("_recovering",recovering)
								host.set("_hurt_joint",hurt);host.set("_walking",1.0);host.set("_stride",stride)
								var positions := PackedVector2Array()
								for point: Vector2 in points:
									var displaced: Vector2 = host.call("_deform_master",point)
									positions.append(displaced)
								for row: int in PrototypeEnemyPresentation.GRID_ROWS:
									for column: int in PrototypeEnemyPresentation.GRID_COLUMNS:
										var first := row*7+column
										for triangle: Array in [[first,first+1,first+8],[first,first+8,first+7]]:
											var a := positions[triangle[0]]
											var area := (positions[triangle[1]]-a).cross(positions[triangle[2]]-a)*0.5
											minimum_area = minf(minimum_area,area)
											if area<=0.0: nonpositive += 1
								poses += 1
	check(nonpositive==0,label+" actual native master deformation never reverses any triangle in mesh envelope")
	mesh_cases.append({"id":label,"poses":poses,"triangles_per_pose":96,"nonpositive":nonpositive,"minimum_native_px2":minimum_area})

func one(id: String,initial_terminal: bool) -> void:
	var actor := make_actor(id,initial_terminal)
	var host := actor.motor.get_node("Presentation") as Node2D
	var health := actor.health
	var label := id+("/initial-terminal" if initial_terminal else "/initial-alive")
	assert_synced(actor,initial_terminal,label)
	if host is PrototypeEnemyPresentation and not initial_terminal:
		check_prototype_orientation(actor,label)
	poison_previous_epoch(host)
	actor.brain.direction = -1
	check(actor.restore_instance_health(actor.health.capacity),label+" real paused alive restore")
	actor.set_physics_process(false)
	# No frame or _process call intervenes: the actual initialize signal must sync.
	assert_synced(actor,false,label+"/paused-alive")
	await ticks(2)
	assert_synced(actor,false,label+"/held-alive")
	poison_previous_epoch(host)
	actor.brain.direction = 1
	check(actor.restore_instance_health(0.0),label+" real paused dead restore")
	assert_synced(actor,true,label+"/paused-dead")
	await ticks(2)
	assert_synced(actor,true,label+"/held-dead")
	var reference: WeakRef = weakref(host)
	actor.motor.queue_free()
	await ticks(2)
	check(reference.get_ref()==null,label+" paused unload frees presentation")
	check(health.changed.get_connections().is_empty(),label+" unload disconnects native health listeners")

func run() -> void:
	world = Node2D.new()
	world.set_meta(ForestBibleActors.METADATA,true)
	root.add_child(world)
	paused = true
	for id: String in FOREST:
		await one(id,false)
		await one(id,true)
	for id: String in ["candidate_lure_guard","candidate_crosswind_moth"]:
		await one(id,false)
		await one(id,true)
	paused = false
	world.queue_free()
	await ticks(2)
	var report := {"scope":"ER-02-04 paused epoch native fixture, not video evidence","checks":checks,"failures":failures,"prototype_mesh_cases":mesh_cases}
	DirAccess.make_dir_recursive_absolute("res://build/enemy_all_02/motion_lifecycle")
	var file := FileAccess.open("res://build/enemy_all_02/motion_lifecycle/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ENEMY-ALL-02 MOTION LIFECYCLE: %s assertions, %s failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
