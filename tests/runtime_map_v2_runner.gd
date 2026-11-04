extends SceneTree
## Controlled real-content loading, not whole-map or device certification.
var assertions := 0
var failures := 0
var trace: Array = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("RUNTIME MAP V2: "+label)

func frames(count: int) -> void:
	for _index: int in count: await physics_frame

func request() -> LevelRequest:
	var value := LevelRequest.new()
	value.root_seed = "930001"
	value.tuning = PlayerTuning.load_default()
	return value

func admission() -> void:
	var inputs := RuntimeMapFrozenSource.read_inputs()
	check(inputs.ok,"actual frozen input bytes match their complete lock")
	if not inputs.ok: return
	var r := request()
	var built := RuntimeMapFrozenSource.load_level(r)
	check(built.accepted(),"actual selected complete module contents admitted: "+built.error)
	if not built.accepted(): return
	check(built.legacy_generated.is_empty(),"v2 consumer has no fabricated legacy Manifest")
	check(built.plan.modules.size()==3 and built.plan.connections.size()==3,"three actual modules and all three internal connections retained")
	check(built.plan.actors.is_empty() and built.plan.pickups.is_empty() and built.plan.boss.is_empty(),"selected source truly has no enemies/rewards/Boss; no coverage invented")
	check(built.plan.modules[0].definition.platforms.size()==5 and built.plan.modules[1].definition.platforms.size()==8 and built.plan.modules[2].definition.platforms.size()==7,"18 original platforms plus exactly two original seals")
	var again := RuntimeMapFrozenSource.load_level(r)
	check(again.accepted() and again.plan.map_hash==built.plan.map_hash,"identical source and selection replay deterministically")
	r.expected_hash = "unknown"
	check(not RuntimeMapFrozenSource.load_level(r).accepted(),"wrong map record refuses instead of substituting source")
	r.expected_hash = ""
	permission_contract(inputs,r)
	identity_contract(inputs,r,built.plan)
	for mode: String in ["schema","seed_precision","mirror","offset","unknown","enemy","service","face","permission","missing_port","disconnected"]:
		var map: Dictionary = inputs.map.duplicate(true)
		var contents: Dictionary = inputs.content.duplicate(true)
		var ids: Array[String] = RuntimeMapFrozenSource.IDS.duplicate()
		var target: Dictionary
		for row: Dictionary in map.instances:
			if row.id == "M16": target = row
		match mode:
			"schema": map.schema = "mapgen/runtime-map/v1"
			"seed_precision": map.seed = 9007199254740992.0
			"mirror": target.transform.content_is_materialized = false
			"offset": target.origin_blocks[0] += 1
			"unknown": contents[target.content_ref].unknown_geometry = [1]
			"enemy": contents[target.content_ref].enemies = [{"id":"unsupported"}]
			"service": target.required_services.append("new_wallet")
			"face":
				for port: Dictionary in target.ports:
					if port.id=="R":
						var old_face: String = port.face
						port.face = "RIGHT" if old_face=="LEFT" else "LEFT"
						check(port.face!=old_face,"face negative actually mutates the mirrored original")
			"permission":
				for port: Dictionary in target.ports:
					if port.id=="R": port.permission = "OUTPUT"
			"missing_port":
				for edge: Dictionary in map.connections:
					if edge.id=="C027": edge.a.port_id = "does_not_exist"
			"disconnected":
				map.connections = map.connections.filter(func(edge: Dictionary) -> bool: return edge.id != "C027")
		var refused := RuntimeMapV2Provider.load_level(r,map,contents,ids,Vector2(-448,846),inputs.lock.files["map.json"],inputs.bindings,inputs.lock)
		check(not refused.accepted() and refused.plan==null and not refused.error.is_empty(),"strict refusal with diagnostic: "+mode)
		trace.append({"case":mode,"error":refused.error})

func permission_contract(inputs: Dictionary, r: LevelRequest) -> void:
	for value: Variant in ["INOUT","INPUT","OUTPUT","IN","OUT","input","",12]:
		var map: Dictionary = inputs.map.duplicate(true)
		for instance: Dictionary in map.instances:
			if instance.id != "M16": continue
			for port: Dictionary in instance.ports:
				if port.id == "R": port.permission = value
		var result := RuntimeMapV2Provider.load_level(r,map,inputs.content,RuntimeMapFrozenSource.IDS,Vector2(-448,846),inputs.lock.files["map.json"],inputs.bindings,inputs.lock)
		if value is String and value == "INOUT":
			check(result.accepted(),"valid bidirectional protocol remains supported")
		elif value is String and value in ["INPUT","OUTPUT"]:
			check(not result.accepted() and "host capability unsupported for legal "+str(value) in result.error,"legal unidirectional seam explicitly unsupported: "+str(value))
		else:
			check(not result.accepted() and "permission: invalid protocol value" in result.error,"protocol-external permission explicitly invalid: "+str(value))
		trace.append({"case":"permission_contract","value":value,"error":result.error})

func identity_contract(inputs: Dictionary, r: LevelRequest, original: LevelPlan) -> void:
	var identity: Dictionary = original.get_meta("runtime_map_v2_identity")
	check(identity.generation_input_fingerprint==inputs.map.generator.request_fingerprint,"upstream generation input fingerprint preserved verbatim")
	check(identity.host_load_identity==original.map_hash and identity.map_content_identity!=original.map_hash and identity.generation_input_fingerprint!=original.map_hash,"generation input, loaded map content and host load are distinct identities")
	check(identity.host_load.bindings_version==inputs.bindings.version and identity.map_content.content.size()==3,"identity names binding version and actual loaded content scope")
	var state := PlainsRegionState.new()
	state.bind_map(original.map_hash)
	state.visited["M18"] = true
	state.clocks["M16"] = 1.25
	var saved := state.snapshot()
	check(PlainsRegionState.new().restore(saved,original.map_hash),"same host load restores existing run-local schema")
	for mode: String in ["content","content_precision","bindings_content","bindings_version","selection","implementation","library","generator_source"]:
		var map: Dictionary = inputs.map.duplicate(true)
		var contents: Dictionary = inputs.content.duplicate(true)
		var bindings: Dictionary = inputs.bindings.duplicate(true)
		var source: Dictionary = inputs.lock.duplicate(true)
		var ids: Array[String] = RuntimeMapFrozenSource.IDS.duplicate()
		match mode:
			"content":
				contents["content/M16.json"].moving_platforms[0].ellipse_period = 10.0
				contents["content/M16.json"].moving_platforms[0].travel_duration = 10.0
			"content_precision":
				contents["content/M16.json"].moving_platforms[0].ellipse_period = 8.000000000001
				contents["content/M16.json"].moving_platforms[0].travel_duration = 8.000000000001
			"bindings_content": bindings.spawns.carrier[0] += 1
			"bindings_version": bindings.version = "loading-slice-next"
			"selection":
				ids.assign(["M18","M21"])
				bindings.selected_instances = ["M18","M21"]
			"implementation": map.generator.implementation += "/next"
			"library":
				map.module_package.sha256 = "f".repeat(64)
				source.library_sha256 = map.module_package.sha256
			"generator_source": source.mapgen_commit = "f".repeat(40)
		var changed := RuntimeMapV2Provider.load_level(r,map,contents,ids,Vector2(-448,846),source.files["map.json"],bindings,source)
		check(changed.accepted(),"changed valid data can be admitted as a NEW load: "+mode+" "+changed.error)
		if not changed.accepted(): continue
		var next_identity: Dictionary = changed.plan.get_meta("runtime_map_v2_identity")
		check(next_identity.generation_input_fingerprint==identity.generation_input_fingerprint and map.generator.request_fingerprint==inputs.map.generator.request_fingerprint,"host changes never overwrite upstream fingerprint: "+mode)
		check(changed.plan.map_hash!=original.map_hash and not PlainsRegionState.new().restore(saved,changed.plan.map_hash),"old restore record explicitly refuses changed load: "+mode)
		if mode.begins_with("bindings"):
			check(next_identity.map_content_identity==identity.map_content_identity,"host-only binding change preserves map content identity")
		var stage := RuntimeMapSliceStage.new()
		stage.plan = changed.plan
		stage.state = state
		root.add_child(stage)
		check(not stage.assembly_ok and stage.error=="Missing plan/state or map identity changed" and stage.get_child_count()==0,"real Stage refuses old state BEFORE creating geometry: "+mode)
		stage.free()
		trace.append({"case":"identity_change","field":mode,"generation_input_fingerprint":next_identity.generation_input_fingerprint,"map_content_identity":next_identity.map_content_identity,"host_load_identity":changed.plan.map_hash,"old_record_refused":true})
	var reversed_ids: Array[String] = RuntimeMapFrozenSource.IDS.duplicate()
	reversed_ids.reverse()
	var reordered := RuntimeMapV2Provider.load_level(r,inputs.map,inputs.content,reversed_ids,Vector2(-448,846),inputs.lock.files["map.json"],inputs.bindings,inputs.lock)
	check(reordered.accepted() and reordered.plan.map_hash==original.map_hash,"set-equivalent selection order does not change load identity")
	var reordered_content: Dictionary = inputs.content.duplicate(true)
	var keys: Array = reordered_content["content/M16.json"].keys()
	keys.reverse()
	var same_content: Dictionary = {}
	for key: String in keys: same_content[key] = reordered_content["content/M16.json"][key]
	reordered_content["content/M16.json"] = same_content
	var same := RuntimeMapV2Provider.load_level(r,inputs.map,reordered_content,RuntimeMapFrozenSource.IDS,Vector2(-448,846),inputs.lock.files["map.json"],inputs.bindings,inputs.lock)
	check(same.accepted() and same.plan.map_hash==original.map_hash,"content dictionary key insertion order does not change identity")
	var old_identity := JSON.stringify([inputs.lock.files["map.json"],RuntimeMapFrozenSource.IDS]).sha256_text()
	var weak_record := saved.duplicate(true)
	weak_record.manifest_hash = old_identity
	check(not PlainsRegionState.new().restore(weak_record,original.map_hash),"prior weak map-plus-IDs record explicitly rejected without save schema migration")

func enter(binding: String) -> RuntimeMapSlice:
	var world := RuntimeMapSlice.new()
	world.spawn_binding = binding
	root.add_child(world)
	check(world.ready_ok,"real player/services and Stage ready for "+binding+": "+world.error)
	return world

func inspect_geometry(world: RuntimeMapSlice) -> void:
	var stage := world.stage
	check(stage.assembler.manifest.is_empty() and stage.assembler.ground_supports==null,"one shared LevelRuntime geometry set; no legacy generator/ground support duplicates")
	var count := 0
	for index: int in stage.plan.modules.size():
		var placement := stage.plan.modules[index]
		var module := stage.assembler.modules[index]
		check(module.position==placement.position and module.scale==Vector2.ONE and module.rotation==0,"materialized translation only: "+placement.instance_id)
		for n: int in placement.definition.platforms.size():
			var rect := placement.definition.platforms[n]
			var body := module.get_node("Platform%d" % n) as StaticBody2D
			var shape := body.get_node("CollisionShape2D") as CollisionShape2D
			check(body.global_position==placement.position+rect.get_center() and (shape.shape as RectangleShape2D).size==rect.size,"actual collision has exactly one source offset: %s/%d" % [placement.instance_id,n])
			check(shape.one_way_collision==(n in placement.definition.one_way_platform_indices),"original one-way declaration retained")
			count += 1
	var static_bodies := world.find_children("*","StaticBody2D",true,false).filter(func(node: Node) -> bool: return not node is AnimatableBody2D)
	check(count==20 and static_bodies.size()==20 and world.find_children("*","AnimatableBody2D",true,false).size()==1,"exactly20 static source bodies plus one native carrier; no second collision set")
	trace.append({"case":"collision_inventory","static":static_bodies.size(),"moving":world.find_children("*","AnimatableBody2D",true,false).size(),"player":world.find_children("*","CharacterBody2D",true,false).size()})
	var policies := world.find_children("*","Node",true,false).filter(func(node: Node) -> bool: return node is FrameDamagePolicy)
	check(world.session.player is PlayerMotor and world.find_children("*","CharacterBody2D",true,false).size()==1 and policies.size()==1,"one formal PlayerMotor and one shared damage policy")
	check(world.session.build.controller==world.session.controller and world.policy.lifetime==world.session.lifetime,"services and policy share the real controller/lifetime")
	var ferry := stage.assembler.modules[0].moving_platforms[0]
	check(ferry.definition is RuntimeMapEllipseDefinition and (ferry.definition as RuntimeMapEllipseDefinition).x_sign == -1,"mirrored ellipse survives both Resource duplicates")
	check(ferry.definition.at_time(0)==Vector2(480,256),"exact native phase plus materialized x-sign, no second reflection")

func dispose(world: RuntimeMapSlice) -> void:
	var token := world.load_token
	var stage_reference: WeakRef = weakref(world.stage) if is_instance_valid(world.stage) else null
	check(await world.close_slice(),"existing world-audio lifecycle drains on exit")
	check(not world.accepts_result(token) and not world.session.lifetime.active,"old loading result cannot commit after exit")
	await process_frame
	check(stage_reference==null or stage_reference.get_ref()==null,"all source module nodes are released on exit")
	world.free()
	await process_frame

func walk(binding: String, seam: float, from: String, to: String) -> void:
	var world := enter(binding)
	if not world.ready_ok:
		await dispose(world)
		return
	inspect_geometry(world)
	await frames(8)
	var player := world.session.player
	var before := player.global_position
	var hp := world.session.controller.actor_resources.health.current
	var wallet := world.session.wallet
	var policy := world.policy
	world.session.controller.router.set_source_axis(&"mapgen_trace",1.0,true)
	for tick: int in 20:
		await physics_frame
		trace.append({"case":binding,"tick":tick,"position":[player.global_position.x,player.global_position.y],"grounded":player.is_on_floor()})
	world.session.controller.router.set_source_axis(&"mapgen_trace",0.0)
	check(before.x<seam and player.global_position.x>seam and player.is_on_floor(),"real Motor crosses original connection on authored collision: "+binding)
	check(world.session.region_state.visited.has(from) and world.session.region_state.visited.has(to),"stable source instance visitation crosses without stage reload")
	check(world.session.wallet==wallet and world.policy==policy and world.session.controller.actor_resources.health.current==hp,"crossing keeps the same services and health")
	var position := player.global_position
	var clocks: Dictionary = world.stage.capture_state().clocks.duplicate()
	var token := world.load_token
	check(world.reload_slice(),"original map state restores through a new Stage, without old Manifest")
	check(player.global_position==position and world.session.wallet==wallet and world.policy==policy,"same-map restore does not teleport/reset the player or replace services")
	check(not world.accepts_result(token),"old actor-scope result is invalid after reload")
	for index: int in world.stage.plan.modules.size():
		check(world.stage.assembler.modules[index].clock==clocks[world.stage.plan.modules[index].instance_id],"stable module clock restores exactly")
	await dispose(world)

func ride() -> void:
	var world := enter("carrier")
	if not world.ready_ok:
		await dispose(world)
		return
	await frames(8)
	var player := world.session.player
	var ferry := world.stage.assembler.modules[0].moving_platforms[0]
	var before := player.global_position
	var carrier_before := ferry.global_position
	var contact_frames := 0
	for tick: int in 60:
		await physics_frame
		for n: int in player.get_slide_collision_count():
			if player.get_slide_collision(n).get_collider()==ferry: contact_frames += 1
		trace.append({"case":"carrier","tick":tick,"player":[player.global_position.x,player.global_position.y],"carrier":[ferry.global_position.x,ferry.global_position.y],"grounded":player.is_on_floor()})
	var movement := player.global_position-before
	var carrier_movement := ferry.global_position-carrier_before
	check(contact_frames>30 and movement.length()>40,"real Motor physically rides the actual native ellipse platform")
	check(movement.distance_to(carrier_movement)<5.0,"existing AnimatableBody2D carries the player without host position writes")
	await dispose(world)

func run() -> void:
	root.size = Vector2i(1280,720)
	admission()
	await walk("seam",-384,"M18","M16")
	await walk("adjacent",-1152,"M21","M18")
	await ride()
	DirAccess.make_dir_recursive_absolute("res://build/mapgen_host_v2_01")
	var file := FileAccess.open("res://build/mapgen_host_v2_01/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"controlled_loading_slice_not_whole_map","assertions":assertions,"failures":failures,"trace":trace,"uncovered":["enemies","rewards","boss","runtime_generation","Web","device"]}))
	file.close()
	print("RUNTIME MAP V2 HOST: %d assertions, %d failures" % [assertions,failures])
	quit(1 if failures else 0)
