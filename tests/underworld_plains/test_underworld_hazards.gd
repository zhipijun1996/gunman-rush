extends SceneTree
## Geometry checks plus real DemoApp/environment contact. Explicit contact poses
## are consumer fixtures, not continuous route or user/device acceptance.
var assertions := 0
var failures := 0
var observations: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func frames(count: int) -> void:
	for unused: int in count: await physics_frame

func geometry() -> void:
	var spec := UnderworldHazardTiles.specification()
	var tiles := load("res://"+str(spec.atlas.tileset)) as TileSet
	check(tiles != null and tiles.get_source_count()==1,"real reusable hazard TileSet consumed")
	check(tiles.get_physics_layers_count()==0,"visual material never introduces duplicate colliders")
	check((tiles.get_source(0) as TileSetAtlasSource).get_tiles_count()==4,"four terminal material variants")
	var host := Rect2(100, 100, 160, 64)
	for face: int in [0, 1, 2, 3]:
		for length: float in [1, 7, 16, 31, 32, 33, 64]:
			var thorn := PlatformThornDefinition.new()
			thorn.face = face
			thorn.length = length
			thorn.start_offset = 0
			thorn.depth = 24
			var hosts: Array[Rect2] = [host]
			check(thorn.is_valid(hosts), "valid four-face source")
			var danger := thorn.danger(hosts)
			var parts := UnderworldHazardTiles.surface_plan(danger, face, host)
			var sum_area := 0.0
			for part: Dictionary in parts:
				check(danger.encloses(part.danger_world), "tips never exceed hurt band")
				check(host.encloses(part.root_world), "roots remain inside host")
				check(not (part.root_world as Rect2).intersects(danger), "embedded roots are solid material")
				sum_area += (part.danger_world as Rect2).get_area()
			check(is_equal_approx(sum_area, danger.get_area()), "complete continuous contact band")
			check(parts.size() == ceili(length / 32.0), "short and terminal exact clipping")
			# Both adjacent safe ends are excluded, including a one-unit short strip.
			for part: Dictionary in parts:
				var bounds: Rect2 = part.danger_world
				if face in [0, 3]:
					check(bounds.position.x >= danger.position.x and bounds.end.x <= danger.end.x, "safe horizontal neighbor stays safe")
				else:
					check(bounds.position.y >= danger.position.y and bounds.end.y <= danger.end.y, "safe vertical neighbor stays safe")
	var shallow := Rect2(100,100,64,3)
	var top := Rect2(100,76,64,24)
	for part: Dictionary in UnderworldHazardTiles.surface_plan(top,0,shallow):
		check(shallow.encloses(part.root_world), "thin platform root crop")
	check(UnderworldHazardTiles.supported_legacy_face(Rect2(110,80,32,20),[host]).size()==2,"legacy surface has real material host")
	check(UnderworldHazardTiles.supported_legacy_face(Rect2(300,200,32,20),[host]).is_empty(),"unsupported drop not floating thorn art")
	var outer := Node2D.new()
	var inner := Node2D.new()
	outer.add_child(inner)
	check(not UnderworldHazardTiles.enabled(inner),"historical pixel fixture unchanged")
	outer.set_meta("underworld_formal_style",true)
	check(UnderworldHazardTiles.enabled(inner),"explicit ancestor style enables material")
	outer.free()

func contact_fixture(face: int, length: float) -> void:
	var world := Node2D.new()
	world.set_meta("underworld_formal_style", true)
	root.add_child(world)
	var host := Rect2(100,100,160,64)
	for rect: Rect2 in [host,Rect2(-100,254,500,32) if face==3 else Rect2(-100,164,500,32)]:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		body.add_child(collision)
		world.add_child(body)
	var thorn := PlatformThornDefinition.new()
	thorn.face = face
	thorn.length = length
	thorn.start_offset = 30 if face in [1,2] else 64
	thorn.depth = 24
	var danger := thorn.danger([host])
	var motor: PlayerMotor = preload("res://game/player/player.tscn").instantiate()
	if face==0: motor.position = Vector2(danger.position.x-13,82)
	elif face==3: motor.position = Vector2(danger.get_center().x,236)
	elif face==1: motor.position = Vector2(danger.position.x-35,146)
	else: motor.position = Vector2(danger.end.x+35,146)
	world.add_child(motor)
	var controller := motor.get_node("Controller") as PlayerController
	motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	var life := DemoLifetime.new()
	var policy := FrameDamagePolicy.new()
	policy.lifetime = life
	world.add_child(policy)
	var health := controller.actor_resources.health
	policy.register_target(&"player",health,true)
	var emitter := DemoContactEmitter.new()
	emitter.policy = policy
	emitter.controller = controller
	emitter.kind = DamageRequest.Kind.ENVIRONMENT
	emitter.source_id = StringName("four_face_%d_%s" % [face,length])
	emitter.half_size = danger.size/2
	emitter.position = danger.get_center()
	world.add_child(emitter)
	var before := health.current
	var events: Array[Dictionary] = []
	var jumps: Array[int] = []
	controller.jump_ability.jumped.connect(func() -> void: jumps.append(Engine.get_physics_frames()))
	policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results: events.append({"source":str(result.request.source_id),"physics_tick":result.request.physics_tick,"epoch":result.request.actor_epoch}))
	await frames(2)
	if face==0:
		await frames(8)
		check(health.current==before,"adjacent safe tile remains physically safe length=%s" % length)
		controller.router.set_move_axis(1)
	elif face==1: controller.router.set_move_axis(1)
	elif face==2: controller.router.set_move_axis(-1)
	elif face==3: controller.router.request_action(&"jump")
	var initial := motor.global_position
	for unused: int in 90:
		await frames(1)
		if health.current < before: break
	check(health.current==before-1,"actual Router/Motor/environment damage face=%d length=%s" % [face,length])
	check(events.size()==1,"one actual exposure result face=%d length=%s" % [face,length])
	check(motor.global_position.distance_to(initial)>0.01,"real Motor owns contact approach")
	if face==3: check(not jumps.is_empty(),"bottom-band contact follows accepted real jump event")
	# Old actor callbacks must be rejected even when the old lifetime token remains
	# stage-valid; this is the existing independent actor-epoch boundary.
	var stale := DamageRequest.new()
	stale.token = life.token()
	stale.actor_epoch = life.actor_epoch
	stale.health_epoch = health.epoch
	stale.target_id = &"player"
	stale.source_id = &"stale_surface"
	stale.event_id = &"stale_surface"
	stale.kind = DamageRequest.Kind.ENVIRONMENT
	stale.amount = 1
	life.invalidate_actor()
	check(not policy.submit(stale),"old exposure rejected after actor return")
	observations.append({"fixture":"four_face_physical_contact","face":face,"length":length,"events":events,"accepted_jump_ticks":jumps,"travel_wu":motor.global_position.distance_to(initial),"scope":"Explicit initial fixture pose, actual subsequent Router/Motor/contact/Health; not formal map route"})
	if not await load("res://tests/audio_teardown.gd").drain_world(world): check(false,"fixture audio teardown")
	world.free()
	await process_frame

func formal_contact() -> void:
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("underworld-integrated-hazard-01"), "real formal stage starts")
	await frames(10)
	var stage := app.stage as PlainsRegionStage
	check(stage != null and stage.assembly_ok, "formal generated Manifest assembles")
	if stage == null:
		app.free()
		return
	var selected: PlatformingModule
	var thorn: PlatformThornDefinition
	for module: PlatformingModule in stage.assembler.modules:
		if not module.definition.surface_thorns.is_empty() and module.definition.saws.is_empty():
			selected = module
			thorn = module.definition.surface_thorns[0]
			break
	check(selected != null, "formal map includes actual rooted danger consumer")
	if selected == null:
		app.free()
		return
	var danger := thorn.danger(selected.definition.platforms)
	danger.position = selected.to_global(danger.position)
	await frames(45) # Expire genuine initial spawn protection on its game clock.
	var before := app.controller.actor_resources.health.current
	var epoch_before := app.lifetime.actor_epoch
	var accepted: Array[Dictionary] = []
	app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results:
			accepted.append({"source":str(result.request.source_id),"kind":result.request.kind,"amount":result.request.amount,"epoch":result.request.actor_epoch}))
	# The existing environment bridge uses DemoContactEmitter -> FrameDamagePolicy
	# -> HealthState. Damageable is the projectile adapter, not this contact path.
	# Pose inside the existing band as an explicit consumer fixture, submit genuine
	# input, then let the real contact/health/return transaction run. Four-direction
	# entry from outside is exercised separately above. No contact is disabled.
	app.controller.return_to_segment(danger.get_center())
	app.lifetime.invalidate_actor() # Fixture relocation must not sweep across the map.
	epoch_before = app.lifetime.actor_epoch
	app.controller.router.set_move_axis(0.1)
	for unused: int in 90:
		await frames(1)
		if app.controller.actor_resources.health.current < before: break
	check(app.controller.actor_resources.health.current == before-1,"actual contact commits existing one damage")
	check(app.lifetime.actor_epoch > epoch_before,"actual environment return invalidates old actor epoch")
	check(accepted.any(func(row: Dictionary) -> bool: return row.kind == DamageRequest.Kind.ENVIRONMENT and str(row.source).begins_with("generated_spikes_")),"formal emitter produces actual accepted environment result")
	var stored: String = stage.generated.manifest.manifest_hash
	observations.append({"seed":"underworld-integrated-hazard-01","manifest_hash":stored,"module_id":str(selected.definition.module_id),"face":thorn.face,"damage_results":accepted,"scope":"Explicit contact pose and real Router/Motor/Health/return; not route traversal"})
	# Reload goes through the real app lifecycle and builds new material consumers.
	app.stage.capture_state()
	app._load_stage()
	await frames(10)
	check(app.stage != stage and app.stage is PlainsRegionStage,"real unload/reload replaces visual consumers")
	check(app.stage.generated.manifest.manifest_hash == stored,"reload retains same authored hazard geometry")
	if not await load("res://tests/audio_teardown.gd").drain_world(app):
		check(false,"actual audio teardown")
	app.free()
	await process_frame

func run() -> void:
	geometry()
	for face: int in [0,1,2,3]:
		for length: float in [1,32]: await contact_fixture(face,length)
	await formal_contact()
	var report := {"schema_version":1,"task_id":"UNDERWORLD-PLAINS-01","assertions":assertions,"failures":failures,"observations":observations,"scope":"Exact hazard material geometry plus actual formal contact/reload; no four-face route, pixel, aesthetic or device acceptance"}
	DirAccess.make_dir_recursive_absolute("res://build/underworld_plains/hazards")
	var file := FileAccess.open("res://build/underworld_plains/hazards/runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("UNDERWORLD HAZARD TESTS: %d assertions, %d failures" % [assertions,failures])
	quit(1 if failures else 0)
