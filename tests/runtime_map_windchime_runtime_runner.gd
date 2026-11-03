extends SceneTree
## Finite runtime consumer proof. The complete source module is read from the
## locked real1.1.0 ZIP and transformed by the original SDK. This is a fixture
## placement, not an algorithm result, generated entrance, or neighbor proof.
const PLAYER := preload("res://game/player/player.tscn")
const DATA := preload("res://addons/mapgen/data_json.gd")
const TRANSFORM := preload("res://addons/mapgen/content_transform.gd")
const ADAPTER := preload("res://game/world/levels/content/runtime_map_shot_latch_adapter.gd")
const ZIP_PATH := "res://resources/mapgen/module-pack-1.1.0.zip"
const ZIP_SHA := "5ad5a7871941b2c1ffa759b18f7b1e80f2fe7e571b72f95d1e0ef26031f08723"
const CONTENT_SHA := "ec162e3811e8cb01df6ecd20a09185bb7fcdf14e57a3e6133c2d8cc4a0d0594f"
var assertions := 0
var failures := 0
var observations: Array[Dictionary] = []
var world: Node2D
var session: RunSession
var stage: RuntimeMapSliceStage
var plan: LevelPlan
var policy: FrameDamagePolicy
var content: Dictionary
var instance: Dictionary

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	assertions += 1
	observations.append({"check":label,"passed":value})
	if not value:
		failures += 1
		push_error("RUNTIME MAP WINDCHIME MECHANISMS: "+label)

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		if session!=null and is_instance_valid(session.controller): session.controller.physics_tick(1.0/60.0)

func read_content(mirrored: bool) -> Dictionary:
	if FileAccess.get_sha256(ZIP_PATH)!=ZIP_SHA: return {}
	var zip := ZIPReader.new()
	if zip.open(ZIP_PATH)!=OK: return {}
	var raw := zip.read_file("modules/game-plains-windchime-lesson/compiled-content.json")
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(raw)
	if context.finish().hex_encode()!=CONTENT_SHA:
		zip.close()
		return {}
	var decoded: Dictionary = DATA.parse(raw.get_string_from_utf8())
	var catalog: Dictionary = DATA.parse(zip.read_file("catalog.json").get_string_from_utf8())
	zip.close()
	if not decoded.ok or not catalog.ok: return {}
	for row: Dictionary in catalog.value.modules:
		if row.id==ADAPTER.MODULE_ID:
			var template := {"compiled_content":decoded.value,"size_blocks":row.sizeBlocks,"source_bounds":row.bounds}
			return TRANSFORM.materialize(template,mirrored,128)
	return {}

func fixture_plan(mirrored: bool) -> LevelPlan:
	content = read_content(mirrored)
	check(not content.is_empty(),"real locked module ZIP and full compiled-content SHA verified")
	if content.is_empty(): return null
	instance = {"id":"fixture-start","module_id":ADAPTER.MODULE_ID,"content_version":ADAPTER.CONTENT_VERSION,"role":"start","transform":{"content_is_materialized":true,"mirror_x":mirrored}}
	check(ADAPTER.validation_error(content,instance).is_empty(),"original SDK-materialized safe_lesson admitted without host mirror/offset")
	var definition := PlatformingModuleDefinition.new()
	definition.module_id = StringName(instance.module_id)
	definition.world_bounds = ADAPTER.rectangle(content.world_bounds)
	for rectangle: Array in content.platforms: definition.platforms.append(ADAPTER.rectangle(rectangle))
	var entry := PlatformingModulePort.new()
	entry.port_id = &"fixture_open_entry"
	entry.position = ADAPTER.point(content.entry_port)
	var finish := PlatformingModulePort.new()
	finish.port_id = &"fixture_open_exit"
	finish.position = ADAPTER.point(content.exit_port)
	entry.direction = Vector2.LEFT if mirrored else Vector2.RIGHT
	finish.direction = entry.direction
	definition.entry_port = entry
	definition.exit_port = finish
	definition.anchors.assign([entry.position,finish.position])
	definition.set_meta("runtime_map_v2_instance",instance.duplicate(true))
	definition.set_meta("runtime_map_v2_content",content.duplicate(true))
	check(definition.is_valid(),"complete original platforms and open fixture body ports retain native geometry validation")
	var placement := LevelModulePlacement.new()
	placement.instance_id = str(instance.id)
	placement.template_id = definition.module_id
	placement.definition = definition
	placement.position = Vector2(128,-256)
	var value := LevelPlan.new()
	value.region_id = &"plains"
	value.source_id = &"real_module_fixture_only"
	value.source_version = "module-pack1.1.0/materialized"
	value.seed = "fixture-no-algorithm"
	value.map_hash = JSON.stringify({"content":content,"instance":instance,"placement":[128,-256]},"",true,true).sha256_text()
	value.modules.append(placement)
	value.bounds = Rect2(placement.position+definition.world_bounds.position,definition.world_bounds.size)
	value.spawn = placement.position+entry.position
	value.anchors.assign([value.spawn,placement.position+finish.position])
	check(value.validation_error().is_empty(),"real content fixture is a valid ordinary transient LevelPlan")
	return value

func create_fixture(mirrored: bool = false) -> bool:
	plan = fixture_plan(mirrored)
	if plan==null: return false
	world = Node2D.new()
	root.add_child(world)
	var audio := PlayerWeaponFeelAudioV2.new()
	audio.name = "GameAudio"
	world.add_child(audio)
	session = RunSession.new()
	check(RunComposition.create_player(world,session,HomeWeaponSelection.new()),"existing RunComposition creates exactly one real player/controller")
	if session.controller==null: return false
	session.controller.set_physics_process(false)
	check(RunComposition.configure_capabilities(session.controller,true,false),"same development weapon setup, no grapple grant or resource refill")
	session.receipt_prefix = "windchime-real-module-fixture"
	session.create_run_services(&"plains",false)
	session.create_item_services(false)
	check(session.flow.start("windchime-fixture",RunProfile.development()).accepted(),"existing RunSession owns fixture lifecycle")
	session.select_map_state(1)
	stage = RuntimeMapSliceStage.new()
	stage.plan = plan
	stage.state = session.region_state
	world.add_child(stage)
	check(stage.assembly_ok,"shared Stage assembles full source platforms: "+stage.error)
	if not stage.assembly_ok: return false
	policy = FrameDamagePolicy.new()
	policy.lifetime = session.lifetime
	world.add_child(policy)
	policy.register_target(&"player",session.controller.actor_resources.health,true)
	policy.register_player_controller(session.controller)
	stage.bind_damage(session.controller,policy,session.lifetime)
	check(stage.bind_mechanisms(session.controller,session.lifetime),"finite encounter uses supplied original controller/lifetime")
	check(session.controller.return_to_segment(plan.spawn),"only initial fixture placement uses accepted controller return API")
	await frames(8)
	return stage.shot_latch_encounter!=null and stage.shot_latch_encounter.latches.size()==1

func count_bodies(node: Node) -> int:
	var result := 1 if node is StaticBody2D else 0
	for child: Node in node.get_children(): result += count_bodies(child)
	return result

func walk_to(target: float, budget: int = 180) -> void:
	for index: int in budget:
		session.controller.router.set_source_axis(&"windchime_runtime_fixture",clampf((target-session.player.global_position.x)/5.0,-1.0,1.0),true)
		await frames(1)
		if absf(target-session.player.global_position.x)<1.5 and session.player.is_on_floor(): break
	session.controller.router.set_source_axis(&"windchime_runtime_fixture",0.0)

func dispose() -> void:
	if session!=null and is_instance_valid(session.controller):
		session.controller.router.clear("windchime_fixture_exit")
		session.controller.active = false
		session.controller.shoot_ability.clear_projectiles()
	if is_instance_valid(stage):
		stage.capture_state()
		stage.cancel_mechanisms()
	if session!=null:
		session.lifetime.end()
		if session.build!=null: session.clear_run_services()
	if is_instance_valid(world):
		check(await WorldAudioLifecycle.drain_world(world),"existing audio lifecycle drains finite source fixture")
		world.queue_free()
	session = null
	stage = null
	world = null
	await physics_frame
	await process_frame

func adapter_contract() -> void:
	var actual := read_content(false)
	var source := {"id":"fixture-start","module_id":ADAPTER.MODULE_ID,"content_version":ADAPTER.CONTENT_VERSION,"role":"start","transform":{"content_is_materialized":true,"mirror_x":false}}
	for mode: String in ["kind","timed","extra","id","duplicate","bell","gate","color","version","role","materialization"]:
		var changed: Dictionary = actual.duplicate(true)
		var changed_source: Dictionary = source.duplicate(true)
		match mode:
			"kind": changed.latches[0].kind = "remote_sequence"
			"timed": changed.latches[0].open_seconds = 1.0
			"extra": changed.latches[0].sequence_offset = [20,0]
			"id": changed.latches[0].id = "unmapped_latch"
			"duplicate": changed.latches.append(changed.latches[0].duplicate(true))
			"bell": changed.latches[0].bell = [INF,0]
			"gate": changed.latches[0].gate[2] = -1
			"color": changed.latches[0].link_color = "not-a-color"
			"version": changed_source.content_version = "sha256:"+"0".repeat(64)
			"role": changed_source.role = "traversal"
			"materialization": changed_source.transform.content_is_materialized = false
		check(not ADAPTER.validation_error(changed,changed_source).is_empty(),"strict mechanism admission refuses actual altered field: "+mode)
	check(ADAPTER.validation_error(actual,source).is_empty(),"negative admission checks did not mutate original real content")
	var no_latches: Dictionary = actual.duplicate(true)
	no_latches.latches = []
	check(ADAPTER.validation_error(no_latches,{}).is_empty(),"empty mechanism inventory does not expand other mechanism support")

func physical_and_restore_contract(mirrored: bool) -> void:
	if not await create_fixture(mirrored):
		check(false,"real source fixture could start")
		await dispose()
		return
	var encounter := stage.shot_latch_encounter
	var latch := encounter.latches[0]
	var key := encounter.state_keys[0]
	var player_id := session.player.get_instance_id()
	var service_id := session.wallet.get_instance_id()
	check(session.player.is_on_floor() and session.player.global_position.distance_to(plan.spawn)<0.1,"real player stands on the source floor at initial body port")
	check(stage.assembler.modules[0].definition.platforms.size()==content.platforms.size() and count_bodies(stage)==content.platforms.size()+2,"all original platforms plus exactly one native gate and one native bell collision")
	check(latch.bell_body.global_position==plan.modules[0].position+ADAPTER.point(content.latches[0].bell) and latch.gate_rect==ADAPTER.rectangle(content.latches[0].gate),"materialized bell/gate receive one placement translation, no extra source offset or mirror")
	check(not latch.is_open and not latch.gate_shape.disabled,"complete safe_lesson begins physically closed")
	var latch_id := latch.get_instance_id()
	check(stage.bind_mechanisms(session.controller,session.lifetime) and stage.shot_latch_encounter.latches[0].get_instance_id()==latch_id and count_bodies(stage)==content.platforms.size()+2,"same mechanism binding is idempotent with no duplicated collisions")
	var exit := plan.modules[0].position+ADAPTER.point(content.exit_port)
	var forward := signf(exit.x-plan.spawn.x)
	await walk_to(exit.x)
	var gate := latch.to_global(latch.gate_rect.get_center())
	check((session.player.global_position.x-gate.x)*forward<0 and not latch.is_open,"closed source gate actually blocks real Motor route")
	var hp := session.controller.actor_resources.health.current
	var serial := session.controller.shoot_ability._shot_serial
	session.controller.router.request_action(&"shoot_release",Vector2.UP)
	await frames(30)
	check(not latch.is_open,"real Router projectile miss does not open gate")
	session.controller.router.request_action(&"shoot_release",(latch.bell_body.global_position-session.player.global_position).normalized())
	await frames(30)
	check(latch.is_open and latch.open_count==1 and latch.health.terminal and latch.gate_shape.disabled,"real accepted Router shot collides with original bell and permanently opens once")
	check(session.region_state.opened.get(key)==true and session.region_state.mechanisms.has(key),"existing instance mechanism/opened ledgers commit immediately on accepted open")
	session.controller.router.request_action(&"shoot_release",(latch.bell_body.global_position-session.player.global_position).normalized())
	await frames(30)
	check(latch.open_count==1 and latch.is_open,"repeated actual hit attempt is idempotent")
	check(session.controller.shoot_ability._shot_serial>=serial+2 and session.controller.actor_resources.health.current==hp,"real shots use original ability/health rules, no synthetic hit or resource grant")
	await walk_to(exit.x)
	await frames(6)
	check(session.player.is_on_floor() and absf(session.player.global_position.x-exit.x)<1.5,"real Motor crosses opened gate and reaches complete original exit shore")
	var saved := stage.capture_state()
	var restored := PlainsRegionState.new()
	check(restored.restore(saved,plan.map_hash),"existing run-local state schema restores same load identity")
	check(not PlainsRegionState.new().restore(saved,"different-load"),"wrong load identity refuses saved gate record")
	session.controller.router.clear("windchime_fixture_reload")
	session.controller.shoot_ability.clear_projectiles()
	session.lifetime.invalidate_actor()
	world.remove_child(stage)
	stage.queue_free()
	session.region_state = restored
	session.region_states[1] = restored
	stage = RuntimeMapSliceStage.new()
	stage.plan = plan
	stage.state = restored
	world.add_child(stage)
	check(stage.assembly_ok and stage.bind_mechanisms(session.controller,session.lifetime),"same Stage path restores original source geometry and supplied lifecycle")
	await frames(3)
	var reloaded := stage.shot_latch_encounter.latches[0]
	check(reloaded.is_open and reloaded.open_count==1 and reloaded.gate_shape.disabled,"original restore_region_opened actually disables restored permanent gate")
	check(session.player.get_instance_id()==player_id and session.wallet.get_instance_id()==service_id,"state restore retains same real player and wallet authority")
	observations.append({"case":"source_fixture","mirrored":mirrored,"source_zip_sha256":ZIP_SHA,"source_content_sha256":CONTENT_SHA,"observed_latches":stage.shot_latch_encounter.observations(),"state_key":key,"scope":"Real complete module in controlled fixture; not algorithm or neighbor traversal"})
	await dispose()

func cancellation_contract(mode: String) -> void:
	if not await create_fixture():
		check(false,"cancel fixture could start")
		await dispose()
		return
	var latch := stage.shot_latch_encounter.latches[0]
	var key := stage.shot_latch_encounter.state_keys[0]
	session.controller.router.request_action(&"shoot_release",(latch.bell_body.global_position-session.player.global_position).normalized())
	await frames(1)
	check(not latch._eligible_shots.is_empty() and not latch.is_open,"real in-flight projectile is registered before "+mode)
	if mode=="actor": session.lifetime.invalidate_actor()
	else: stage.cancel_mechanisms()
	await frames(35)
	check(not latch.is_open and latch.open_count==0 and not session.region_state.opened.has(key),"late real projectile cannot settle gate after "+mode)
	await dispose()

func invalid_saved_state_contract() -> void:
	var value := fixture_plan(false)
	if value==null: return
	var state := PlainsRegionState.new()
	state.bind_map(value.map_hash)
	var key := ADAPTER.state_key("fixture-start",ADAPTER.LATCH_ID)
	state.mechanisms[key] = {"clock":NAN,"opened_at":-1,"is_open":false,"sequence_step":0,"open_count":0,"motion_clock":0,"motion_running":false}
	var rejected := RuntimeMapSliceStage.new()
	rejected.plan = value
	rejected.state = state
	root.add_child(rejected)
	check(not rejected.assembly_ok and rejected.get_child_count()==0 and "clock" in rejected.error,"invalid saved mechanism rejected before any geometry or latch nodes")
	rejected.free()
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	adapter_contract()
	await physical_and_restore_contract(false)
	await physical_and_restore_contract(true)
	await cancellation_contract("cancel")
	await cancellation_contract("actor")
	await invalid_saved_state_contract()
	DirAccess.make_dir_recursive_absolute("res://build/mapgen041")
	var file := FileAccess.open("res://build/mapgen041/windchime_mechanisms.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"scope":"Real module1.1.0 complete-content Stage/ShotLatch fixture; not algorithm/generated entrance/full map or seam","source_zip_sha256":ZIP_SHA,"source_content_sha256":CONTENT_SHA,"observations":observations},"\t",true,true))
		file.close()
	print("RUNTIME MAP WINDCHIME MECHANISMS: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
