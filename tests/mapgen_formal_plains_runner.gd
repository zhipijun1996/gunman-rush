extends SceneTree
## Real main/menu/generation/physics and input checks. Repositioned transaction
## and Boss settlement cases are explicitly fixtures, not whole-map traversal.
const READY := preload("res://tests/formal_region_test_support.gd")
var app: DemoApp
var checks := 0
var failures := 0
var observations: Array[Dictionary]=[]
var first_source := ""
var first_hash := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	observations.append({"check":label,"passed":ok})
	if not ok: failures+=1;push_error("FORMAL MAPGEN: "+label)
func frames(count: int) -> void:
	for i: int in count: await physics_frame
func pointer(owner: Node, prefix: String) -> bool:
	for i: int in 3: await process_frame
	for button: Button in owner.find_children("*","Button",true,false):
		if not button.visible or button.disabled or not button.text.begins_with(prefix): continue
		for pressed: bool in [true,false]:
			var event := InputEventMouseButton.new()
			event.position=button.get_global_rect().get_center();event.global_position=event.position
			event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
			root.push_input(event,true)
			await process_frame
		return true
	return false
func walk_to(x: float, budget: int = 220) -> bool:
	for i: int in budget:
		app.controller.router.set_source_axis(&"formal_mapgen_test",clampf((x-app.player.global_position.x)/5.0,-1,1),true)
		await frames(1)
		if absf(x-app.player.global_position.x)<2 and app.player.is_on_floor(): break
	app.controller.router.set_source_axis(&"formal_mapgen_test",0)
	return absf(x-app.player.global_position.x)<3
func normal_start(weapon: StringName, seed: String) -> bool:
	app.menu.requested_home_weapon.emit(weapon)
	app.menu._seed=seed
	app.home_scene.requested_interaction.emit(&"departure")
	check(await pointer(app.menu,"BEGIN / WINDCHIME PLAINS"),"native Home departure button accepted: "+str(weapon))
	var ready := await READY.ready(app,self)
	check(ready,"actual generated map admitted: "+str(weapon)+" "+app._status)
	return ready
func identity_contract() -> void:
	var stage := app.stage as MapgenPlainsStage
	var plan := stage.level_plan
	var view: Dictionary=stage.generated.manifest
	var source: Dictionary=preload("res://addons/mapgen/data_json.gd").parse(view.mapgen.source_json).value
	check(plan.modules.size()==source.result.map.instances.size() and plan.connections.size()==source.result.map.connections.size(),"whole actual SDK map and every connection installed")
	check(plan.modules.size()>10 and not stage.enemies.is_empty() and not stage.chests.is_empty(),"exploration world includes native enemies and reward sites")
	check(plan.source_id==&"mapgen_runtime_v2" and view.version==PlainsMapGeneration.VERSION,"ordinary departure uses map-gen, not legacy or a slice")
	check(source.result.map.module_package.version=="1.1.0" and source.result.map.generator.implementation=="mapgen/gdscript-candidate-0.4.1","installed SDK and module package identities retained")
	check(not app.controller.traversal.hook_enabled and app.player.tuning.max_jumps==1 and app.player.tuning.max_air_shots==1,"formal base resources stay ungranted and unmodified")
	check(app.controller.is_physics_processing() and app.player.is_physics_processing(),"actual automatic Controller and Motor own movement")
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"actual formal Manifest survives ordinary JSON roundtrip")
	var restored := PlainsMapGeneration.recorded_level(view,app.player.tuning,app.director.seed,app.director.region_map_index)
	check(restored.accepted() and restored.plan.map_hash==plan.map_hash,"exact committed source reconstructs without drawing another map")
	var broken := view.duplicate(true)
	var changed := source.duplicate(true)
	var first: Dictionary=changed.result.content_store.values()[0]
	first.platforms[0][0]+=1
	broken.mapgen.source_json=JSON.stringify(changed,"",true,true)
	check(not PlainsMapGeneration.recorded_level(broken,app.player.tuning,app.director.seed,app.director.region_map_index).accepted(),"changed actual content cannot retain the recorded identity")
	var missing := view.duplicate(true)
	var invalid := source.duplicate(true)
	invalid.result.erase("map")
	missing.mapgen.source_json=JSON.stringify(invalid,"",true,true)
	check(not PlainsMapGeneration.recorded_level(missing,app.player.tuning,app.director.seed,app.director.region_map_index).accepted(),"incomplete recorded SDK source is refused without a script error")
	check(not PlainsMapGeneration.recorded_level(view,app.player.tuning,app.director.seed+"/different",app.director.region_map_index).accepted(),"recorded map cannot be moved to a different run seed")
	var unique := {}
	for enemy: Dictionary in plan.actors: unique[enemy.id]=true
	check(unique.size()==plan.actors.size(),"repeated modules have distinct stable enemy identities")
func start_lesson() -> void:
	var stage := app.stage as MapgenPlainsStage
	var latch := stage.runtime_latches.latches[0]
	var player_id := app.player.get_instance_id()
	var start := app.player.global_position
	await frames(5)
	check(not latch.is_open,"generated start's real lesson door begins closed")
	app.controller.router.request_action(&"shoot_release",(latch.bell_body.global_position-app.player.global_position).normalized())
	await frames(30)
	check(latch.is_open and latch.gate_shape.disabled,"real Router projectile opens the materialized start bell")
	var root := stage.level_plan.modules[0]
	var bank: Vector2=root.position+root.definition.exit_port.position
	check(await walk_to(bank.x),"one automatic Motor walks through the opened full start module")
	var first_edge: Dictionary={}
	for edge: Dictionary in stage.level_plan.connections:
		if edge.a.instance_id==root.instance_id or edge.b.instance_id==root.instance_id: first_edge=edge;break
	var peer: String=str(first_edge.b.instance_id if first_edge.a.instance_id==root.instance_id else first_edge.a.instance_id)
	var target: LevelModulePlacement
	for placement: LevelModulePlacement in stage.level_plan.modules:
		if placement.instance_id==peer: target=placement;break
	var source_port: Dictionary={}
	var instance: Dictionary=root.definition.get_meta("runtime_map_v2_instance")
	for port: Dictionary in instance.ports:
		if port.id==first_edge.a.port_id and first_edge.a.instance_id==root.instance_id or port.id==first_edge.b.port_id and first_edge.b.instance_id==root.instance_id: source_port=port;break
	var direction := -1.0 if source_port.face=="LEFT" else 1.0
	var seam_x := float(first_edge.position_pixels[0])
	check(await walk_to(seam_x+direction*35),"real input crosses the actual neighboring-module seam")
	check(app.player.get_instance_id()==player_id and app.player.global_position.distance_to(start)>100,"continuous start-to-neighbor movement keeps the original player")
	var hash_before := stage.level_plan.map_hash
	var openings := stage.region_state.opened.duplicate(true)
	app._stage_pending=true
	await app._load_stage()
	check(not app._stage_pending and app.stage.level_plan.map_hash==hash_before,"world reinstall consumes the committed map, not new generation")
	check(app.stage.region_state.opened==openings and (app.stage as MapgenPlainsStage).runtime_latches.latches[0].is_open,"actual opened mechanism survives reinstall")
func position_fixture(point: Vector2) -> void:
	# Disclosed setup for isolated transactions, never a traversal result.
	# Use native selective cancellation/epoch rules so contact sweeps do not
	# interpret a fixture relocation as movement across intervening hazards.
	app.controller.return_to_segment(point)
	app.lifetime.invalidate_actor()

func enemy_combat_fixture() -> void:
	var stage := app.stage as MapgenPlainsStage
	var target: EnemyMotor
	var standing := Vector2.INF
	for motor: EnemyMotor in stage.enemies:
		var actor := motor.get_node("Actor") as EnemyActor
		if actor.definition.aerial or actor.health.terminal: continue
		for side: float in [-1.0,1.0]:
			var at := motor.global_position+Vector2(side*150,-80)
			var ray := PhysicsRayQueryParameters2D.create(at,at+Vector2(0,180),1,[app.player.get_rid()])
			var floor_hit := app.player.get_world_2d().direct_space_state.intersect_ray(ray)
			if floor_hit.is_empty(): continue
			var bank: Vector2=floor_hit.position-Vector2(0,18)
			if absf(bank.y-motor.global_position.y)>30: continue
			var line := PhysicsRayQueryParameters2D.create(bank,motor.global_position,1,[app.player.get_rid()])
			if not app.player.get_world_2d().direct_space_state.intersect_ray(line).is_empty(): continue
			target=motor;standing=bank;break
		if target!=null: break
	check(target!=null,"combat fixture finds a real supported enemy approach")
	if target==null: return
	var actor := target.get_node("Actor") as EnemyActor
	var index := stage.enemies.find(target)
	var id: String=stage.enemy_manifest[index].id
	position_fixture(standing) # HP is preserved; subsequent motion and shots are native.
	await frames(3)
	for tick: int in 240:
		if actor.health.terminal or not app.lifetime.active: break
		if app.controller.shoot_ability.cooldown_remaining<=0:
			app.controller.router.request_action(&"shoot_release",(target.global_position-app.player.global_position).normalized())
		await frames(1)
	check(actor.health.terminal,"real Router weapon projectiles defeat the original native enemy")
	await frames(4)
	check(stage.region_state.actors.has(id) and float(stage.region_state.actors[id].health)==0 and stage.region_state.drops.has(id),"native enemy defeat records health and its drop receipt")

func reward_fixture() -> void:
	var stage := app.stage as MapgenPlainsStage
	var chest: Dictionary=stage.chests[0]
	position_fixture(chest.position)
	await frames(2)
	app._region_interact()
	check(app.reward_modal.opened and app._region_offer.candidates.size()==2,"native cache opens its real two-choice modal")
	var before := app.build.inventory.instances().size()
	check(await pointer(app.reward_modal,"选择 / PICK"),"real pointer submits a generated cache option")
	await frames(5)
	check(chest.claimed and stage.region_state.claimed.has(chest.id),"committed choice opens the actual chest and records its entitlement")
	check(app.build.inventory.instances().size()==before+1,"native V5 item enters inventory once")
	var coins := app.wallet.balance
	app._region_interact()
	await frames(2)
	check(app.build.inventory.instances().size()==before+1 and app.wallet.balance==coins,"repeat interaction cannot grant the same cache again")
func defeat_fixture() -> bool:
	var stage := app.stage as PlainsRegionStage
	position_fixture(stage.boss_arena.get_center()+Vector2(-200,stage.boss_arena.size.y/2-18)) # Settlement fixture only.
	await frames(3)
	var boss := stage.boss.get_node("Encounter") as BossEncounter
	if not app._boss_started: return false
	var request := DamageRequest.new()
	request.token=app.lifetime.token();request.actor_epoch=app.lifetime.actor_epoch
	request.health_epoch=boss.health.epoch;request.target_id=&"boss"
	request.source_id=&"explicit_mapgen_flow_fixture";request.event_id=app._next_id("mapgen_fixture_defeat")
	request.amount=boss.health.current
	if not app.policy.submit(request): return false
	for i: int in 240:
		await frames(1)
		if app.director.stage_complete and stage.reward_available: return true
	return false
func gate_fixture() -> bool:
	position_fixture(app.stage.reward_position)
	await frames(2)
	if app.exit_modal.opened: return app._confirm_generated_exit()
	return app._enter_generated_exit(&"boss_home")
func disposed_loading_owner() -> void:
	var before := get_node_count()
	var temporary: DemoApp=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	temporary.meta_persistence_enabled=false
	root.add_child(temporary)
	for i: int in 3: await process_frame
	temporary.menu._start_title_adventure()
	await process_frame
	temporary.start_plains("free-during-generation")
	for i: int in 2: await process_frame
	check(temporary._stage_pending,"disposal case actually suspends in cooperative loading")
	temporary.free()
	for i: int in 8: await process_frame
	check(get_node_count()==before,"freeing the loading App leaves no generation-view or world nodes")

func cancelled_loading() -> void:
	check(app.start_plains("cancel-formal"),"normal departure starts cancellable generation")
	for i: int in 2: await process_frame
	var token := app.lifetime.token()
	check(app._stage_pending,"cancel case actually waits on cooperative generation")
	app.abandon_run()
	for i: int in 8: await process_frame
	check(app.director.state==DemoRunDirector.State.HOME and not app.lifetime.accepts(token) and not is_instance_valid(app.stage),"cancel returns to Home and invalidates the pending world")
	check(app.run_session.plains_generation.phase=="cancelled","cancelled run discards its generation result and committed-map cache")
	app.menu.close_panel()

func run() -> void:
	root.size=Vector2i(1280,720)
	await disposed_loading_owner()
	app=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	app.meta_persistence_enabled=false
	root.add_child(app)
	for i: int in 3: await process_frame
	check(app.menu.visible_panel==&"title","configured project starts at the real title")
	app.menu._start_title_adventure()
	await frames(2)
	check(is_instance_valid(app.home_scene),"title creates the actual playable home")
	await cancelled_loading()
	if not await normal_start(&"pulse_gun","ci-smoke"): await finish();return
	identity_contract()
	first_source=app.stage.generated.manifest.mapgen.source_json
	first_hash=app.stage.level_plan.map_hash
	await start_lesson()
	await enemy_combat_fixture()
	await reward_fixture()
	var inventory := app.build.inventory.instances().size()
	var actor_id := app.player.get_instance_id()
	check(await defeat_fixture(),"explicit fixture settles map1 Bellstrider under the original frame policy")
	check(await gate_fixture(),"map1 real exit requests map2")
	check(await READY.ready(app,self),"second complete generated map physically admitted")
	if not app.stage is MapgenPlainsStage: await finish();return
	check(app.director.region_map_index==2 and app.player.get_instance_id()==actor_id and app.build.inventory.instances().size()==inventory,"map transition retains the real player and inventory")
	check(app.stage.boss.get_node("Encounter") is WindkeeperPressureEncounter,"map2 installs the existing active-pressure Windkeeper")
	identity_contract()
	check(await defeat_fixture(),"explicit fixture settles map2 native Windkeeper")
	check(await gate_fixture() and app.reward_modal.opened,"native gold reward opens separately from core ability")
	check(await pointer(app.reward_modal,"选择 / PICK"),"real pointer commits the native gold item")
	check(app.progression_modal.opened and not app.controller.traversal.hook_enabled,"gold does not silently grant H")
	check(await pointer(app.progression_modal,"H / GRAPPLE"),"real pointer selects the existing H offer")
	check(app.controller.traversal.hook_enabled,"existing campaign grants H")
	check(await pointer(app.progression_modal,"ENTER / THORN FOREST"),"real pointer selects the existing Forest route")
	check(await READY.ready(app,self) and app.stage is ThornForestRegionStage,"natural next-region flow installs the existing forest")
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"mixed mapgen-Plains/Forest campaign Manifest roundtrip")
	app.abandon_run()
	for i: int in 8: await process_frame
	app.menu.close_panel()
	if await normal_start(&"pulse_gun","ci-smoke"):
		check(app.stage.level_plan.map_hash==first_hash and app.stage.generated.manifest.mapgen.source_json==first_source,"fresh run reproduces exact map/source independently of generation clocks and cache warmth")
	await finish()
func finish() -> void:
	if app.lifetime.active: app.abandon_run()
	for i: int in 8: await process_frame
	check(await preload("res://tests/audio_teardown.gd").drain_world(app),"owned audio drains at real Home cleanup")
	app.queue_free()
	for i: int in 4: await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/mapgen_formal")
	var file := FileAccess.open("res://build/mapgen_formal/formal_checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t"))
	print("MAPGEN FORMAL PLAINS: %s assertions, %s failures" % [checks,failures])
	quit(1 if failures else 0)
