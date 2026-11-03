extends SceneTree
## Actual generation/Stage/physics, independent M35 only. The one saw contact
## relocation occurs inside this running scene; it is not initial entry or a route.
const SCENE := preload("res://experiments/generation/runtime_map_m35_slice.tscn")
const M35 := preload("res://experiments/generation/runtime_map_m35_slice.gd")
const INPUT_ID: StringName = &"m35_runtime_test"
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []
var hits: Array[Dictionary] = []
var returns: Array[Dictionary] = []

class UnsafeSpawn extends RuntimeMapM35Slice:
	var admission_calls := 0
	func _read_host_bindings() -> Dictionary:
		var host := super()
		if host.ok:
			host.bindings = host.bindings.duplicate(true)
			# In-memory host input negative only: inside the original fall plane.
			host.bindings.spawns.seam = [1626,1828]
		return host
	func _physics_admission() -> String:
		admission_calls += 1
		return super()

class StaleBeforeCommit extends RuntimeMapM35Slice:
	var admission_calls := 0
	var safe_before_invalidation := false
	func _physics_admission() -> String:
		admission_calls += 1
		var problem := super()
		safe_before_invalidation = problem.is_empty()
		if problem.is_empty(): session.lifetime.invalidate_actor()
		return problem

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	observations.append({"check":label,"passed":value})
	if not value:
		failures += 1
		push_error("M35 RUNTIME: "+label)

func frames(count: int) -> void:
	for index: int in count: await physics_frame

func wait_for_source(world: RuntimeMapM35Slice) -> void:
	var started := Time.get_ticks_msec()
	var count := 0
	while not world.ready_ok and world.error.is_empty() and count<10000 and Time.get_ticks_msec()-started<60000:
		await process_frame
		count += 1
	observations.append({"case":"generation_wait","frames":count,"elapsed_ms":Time.get_ticks_msec()-started,"ready":world.ready_ok,"error":world.error})

func service_ids(world: RuntimeMapM35Slice) -> Dictionary:
	return {"player":world.session.player.get_instance_id(),"controller":world.session.controller.get_instance_id(),"lifetime":world.session.lifetime.get_instance_id(),"health":world.session.controller.actor_resources.health.get_instance_id(),"wallet":world.session.wallet.get_instance_id(),"build":world.session.build.get_instance_id(),"inventory":world.session.build.inventory.get_instance_id(),"equipment":world.session.build.equipment.get_instance_id(),"rewards":world.session.rewards.get_instance_id(),"shop":world.session.shop.get_instance_id()}

func count_kind(node: Node, kind: String) -> int:
	var count := 0
	if (kind=="player" and node is PlayerMotor) or (kind=="controller" and node is PlayerController) or (kind=="policy" and node is FrameDamagePolicy): count += 1
	for child: Node in node.get_children(): count += count_kind(child,kind)
	return count

func negative_admission(stale: bool) -> void:
	var world: RuntimeMapM35Slice = StaleBeforeCommit.new() if stale else UnsafeSpawn.new()
	root.add_child(world)
	var services := service_ids(world)
	var hp := world.session.controller.actor_resources.health.current
	check(not world.session.controller.active and world.stage==null,"negative entrance begins inactive with no provisional Stage")
	await wait_for_source(world)
	check(not world.ready_ok and not world.error.is_empty() and world.generation.phase(world.ticket)!="committed","negative physics admission never commits: "+world.error)
	check(world.stage==null and world.policy==null and not world.session.controller.active,"failed/stale provisional admission discards Stage/policy before activation")
	check(service_ids(world)==services and world.session.controller.actor_resources.health.current==hp,"failed/stale admission does not replace services or spend HP")
	if stale:
		var altered := world as StaleBeforeCommit
		check(altered.admission_calls==1 and altered.safe_before_invalidation,"actual first-physics safe admission precedes deliberate original actor invalidation")
	else:
		var unsafe := world as UnsafeSpawn
		check(unsafe.admission_calls==1 and "unsafe" in unsafe.error,"in-memory unsafe spawn reaches actual SegmentRespawn physics safety rejection")
	check(world.generation.take_plan(world.ticket,world.session.lifetime)==null and not world.generation.commit(world.ticket,world.session.lifetime),"no late take/commit after discarded provisional Stage")
	check(await world.close_preview(),"negative entrance drains through original close_preview")
	world.free()
	await process_frame

func static_damage_contract(world: RuntimeMapM35Slice, actual: Dictionary) -> void:
	var module := world.stage.assembler.modules[0]
	var placement := world.stage.plan.modules[0]
	var instance: Dictionary = {}
	for row: Dictionary in actual.map.instances:
		if row.id=="M35": instance = row
	check(not instance.is_empty(),"M35 resolves through this actual completed generation")
	if instance.is_empty(): return
	var content: Dictionary = actual.content_store[instance.content_ref]
	observations.append({"case":"actual_module_scope","instance_id":instance.id,"actual_module_id":instance.module_id,"plan_template_id":str(placement.template_id),"definition_module_id":str(module.definition.module_id),"content_stable_id":content.stable_id})
	check(world.stage.plan.modules.size()==1 and placement.instance_id=="M35" and world.stage.plan.connections.is_empty(),"only original generated M35 installed; no neighboring geometry or seam connection fabricated")
	check(module.definition.platforms.size()==content.platforms.size() and world.stage.plan.ground_supports.is_empty(),"no additional floor/support or authored platform deletion")
	for index: int in content.platforms.size():
		var rect: Array = content.platforms[index]
		check(module.definition.platforms[index]==Rect2(rect[0],rect[1],rect[2],rect[3]),"authored platform preserved exactly: "+str(index))
	check(module.definition.danger_bounds.size()==content.hazards.size() and module.hazards.size()==content.saws.size() and module.moving_platforms.size()==content.moving_platforms.size(),"complete actual hazard/saw/ferry inventory is installed")
	check(module.moving_platforms.size()==2 and module.hazards.size()==1 and content.hazards.size()==1,"locked M35 scenario contains two linear ferries, one saw and original fall plane")
	var records := world.stage.assembler.world_static_hazard_records()
	var contacts: Array[DemoContactEmitter] = []
	var identities: Array[int] = []
	for child: Node in world.stage.get_children():
		if child is DemoContactEmitter:
			contacts.append(child)
			identities.append(child.get_instance_id())
	check(contacts.size()==records.size() and not contacts.is_empty(),"one original policy emitter per nonempty static hazard record")
	for index: int in contacts.size():
		var contact := contacts[index]
		var record: Dictionary = records[index]
		var rect: Rect2 = record.rect
		check(contact.global_position==rect.get_center() and contact.half_size==rect.size/2.0 and contact.policy==world.policy and contact.controller==world.session.controller,"static contact uses actual full authored rect and existing player/policy")
		check(contact.fall_plane==(record.role=="fall_plane") and contact.get_meta("hazard_role")==record.role and contact.get_meta("hazard_module")==record.module_id and contact.get_meta("hazard_authored_id")==record.authored_id,"static emitter retains fall-plane/surface and authored provenance metadata")
	world.stage.bind_damage(world.session.controller,world.policy,world.session.lifetime)
	var repeated: Array[int] = []
	for child: Node in world.stage.get_children():
		if child is DemoContactEmitter: repeated.append(child.get_instance_id())
	check(repeated==identities,"same damage bind is idempotent and adds no duplicate static sources")
	for saw: ModuleSawHazard in module.hazards:
		check(saw.policy==world.policy and saw.lifetime==world.session.lifetime and saw.controller==world.session.controller,"original saw uses the same existing policy/lifetime/controller")
	check(world.segment!=null and world.segment.lifetime==world.session.lifetime and world.segment.controller==world.session.controller and world.segment.danger_bounds==world.stage.assembler.world_dangers(),"one original SegmentRespawn uses actual complete danger bounds and existing authority")

func clock_contract(world: RuntimeMapM35Slice) -> void:
	var module := world.stage.assembler.modules[0]
	var before := module.clock
	var ferry_before: Array[Vector2] = []
	for ferry: ModuleMovingPlatform in module.moving_platforms: ferry_before.append(ferry.position)
	var saw_before := module.hazards[0].position
	var coherent := true
	for index: int in 210:
		await physics_frame
		for ferry: ModuleMovingPlatform in module.moving_platforms:
			coherent = coherent and ferry.module==module and not ferry.bell_controlled and ferry.position.distance_to(ferry.definition.at_time(module.clock))<0.001
		for saw: ModuleSawHazard in module.hazards:
			coherent = coherent and saw.module==module and saw.position.distance_to(saw.definition.at_time(module.clock))<0.001
	check(coherent and module.clock>before,"both original ferry positions and saw sample the same real physics module.clock")
	for index: int in module.moving_platforms.size():
		check(module.moving_platforms[index].position.distance_to(ferry_before[index])>1.0,"actual linear ferry moved over real physics frames: "+str(index))
	check(module.hazards[0].position.distance_to(saw_before)>1.0,"actual saw moved over shared-clock real physics frames")
	observations.append({"case":"shared_clock","clock_before":before,"clock_after":module.clock,"ferry_positions":[[module.moving_platforms[0].position.x,module.moving_platforms[0].position.y],[module.moving_platforms[1].position.x,module.moving_platforms[1].position.y]],"saw_position":[module.hazards[0].position.x,module.hazards[0].position.y],"physics_frames":210})

func observe_policy(values: Array[DamageResult], world: RuntimeMapM35Slice) -> void:
	for value: DamageResult in values:
		hits.append({"source":str(value.request.source_id),"event":str(value.request.event_id),"hp_lost":value.hp_lost,"hp":value.health.current,"lethal":value.lethal,"kind":int(value.request.kind),"fall":value.request.fall,"actor_epoch":value.request.actor_epoch,"clock":world.stage.assembler.modules[0].clock,"policy_clock":world.policy.player_clock()})

func observe_return(id: StringName, world: RuntimeMapM35Slice) -> void:
	returns.append({"anchor":str(id),"point":[world.session.player.global_position.x,world.session.player.global_position.y],"clock":world.stage.assembler.modules[0].clock,"actor_epoch":world.session.lifetime.actor_epoch})

func walk_to_hazard(world: RuntimeMapM35Slice, label: String) -> void:
	var hp := world.session.controller.actor_resources.health.current
	var before := world.session.player.global_position
	var steps := world.session.player.motion_steps
	world.session.controller.router.set_source_axis(INPUT_ID,1.0,true)
	var waited := 0
	while world.session.controller.actor_resources.health.current==hp and world.session.lifetime.active and waited<480:
		await physics_frame
		waited += 1
	world.session.controller.router.set_source_axis(INPUT_ID,0.0)
	check(world.session.player.motion_steps>steps and world.session.controller.actor_resources.health.current==hp-1.0,label+": real Router/Motor walkoff causes one actual HP loss")
	observations.append({"case":label,"input":"axis+1 only; no position write","start":[before.x,before.y],"end":[world.session.player.global_position.x,world.session.player.global_position.y],"physics_frames":waited,"motor_steps":world.session.player.motion_steps-steps,"hp_before":hp,"hp_after":world.session.controller.actor_resources.health.current})

func damage_contract(world: RuntimeMapM35Slice) -> void:
	var module := world.stage.assembler.modules[0]
	var services := service_ids(world)
	var state := world.session.region_state
	var wallet := world.session.wallet.balance
	var epoch := world.session.lifetime.actor_epoch
	var clock_before := module.clock
	var old_token := world.session.lifetime.token()
	var health_epoch := world.session.controller.actor_resources.health.epoch
	world.policy.batch_resolved.connect(observe_policy.bind(world))
	world.segment.returned.connect(observe_return.bind(world))
	await walk_to_hazard(world,"natural_walkoff")
	check(returns.size()==1 and not hits.is_empty() and hits.back().source.begins_with("runtime_map_static_") and hits.back().fall and not hits.back().lethal,"actual original fall-plane contact requests one environment return")
	check(world.session.player.global_position.distance_to(world.stage.plan.spawn)<0.1 and world.session.lifetime.actor_epoch==epoch+1,"original SegmentRespawn returns to same admitted entry and invalidates old actor epoch")
	check(module.clock>=clock_before and world.session.region_state==state and service_ids(world)==services and world.session.wallet.balance==wallet,"environment return preserves module clock, region state and existing service/wallet identities")
	var captured := world.stage.capture_state()
	check(float(captured.clocks.M35)>=clock_before,"capture records continuing M35 clock instead of rebuilding it at zero")
	var stale := DamageRequest.new()
	stale.token = old_token
	stale.actor_epoch = epoch
	stale.health_epoch = health_epoch
	stale.target_id = &"player"
	stale.source_id = &"m35_stale_probe"
	stale.event_id = &"m35_stale_actor_hit"
	stale.amount = 1.0
	stale.kind = DamageRequest.Kind.ENVIRONMENT
	check(not world.policy.submit(stale),"previous actor epoch hit cannot damage the returned player")
	await frames(50)
	# One explicit in-scene contact-test relocation via the original controller.
	# This is after normal play, not initial entry or continuous-route evidence.
	# No per-frame actor motion, direct settlement, extra support or protection.
	var saw := module.hazards[0]
	var hp_before := world.session.controller.actor_resources.health.current
	var saw_hits_before := hits.size()
	var fixture := saw.global_position
	var setup_motion_steps := world.session.player.motion_steps
	var setup_actor_epoch := world.session.lifetime.actor_epoch
	check(world.session.controller.return_to_segment(fixture),"one explicit in-scene saw contact relocation uses original controller.return_to_segment; not initial entry or route proof")
	world.session.lifetime.invalidate_actor()
	var waited := 0
	while world.session.controller.actor_resources.health.current==hp_before and waited<90:
		await physics_frame
		waited += 1
	check(hits.size()==saw_hits_before+1 and hits.back().source==str(saw.runtime_source_id) and hits.back().hp_lost==1.0 and not hits.back().lethal,"actual original swept saw contact applies1HP and returns through existing policy")
	check(is_equal_approx(saw.definition.contact_interval,0.7) and is_equal_approx(saw.definition.damage,1.0),"saw retains declared0.7s contact_interval and actual1HP damage without synthetic settlement")
	if hits.size()>saw_hits_before:
		var next_pulse: float = saw.get("_next_pulse")
		var remaining := next_pulse-float(hits.back().policy_clock)
		check(remaining>=0.7-1.1/float(Engine.physics_ticks_per_second) and remaining<=0.70001,"actual single swept hit schedules next pulse at0.7s; not proof of two-hit spacing")
	check(returns.size()==2 and service_ids(world)==services and world.session.wallet.balance==wallet and module.clock>clock_before,"saw return preserves same services/ledger and continuing mechanism clock")
	observations.append({"case":"saw_in_scene_contact_relocation","point":[fixture.x,fixture.y],"setup_motion_steps":setup_motion_steps,"setup_actor_epoch":setup_actor_epoch,"hp_before":hp_before,"physics_frames":waited,"scope":"one explicit in-scene contact-test relocation via original controller.return_to_segment; not initial entry or continuous-route proof; next_pulse is scheduling only"})
	var health := world.session.controller.actor_resources.health
	var remaining_hp := health.current
	var walkoff_budget := 0
	var valid_remaining := is_finite(remaining_hp) and remaining_hp>0.0 and remaining_hp<=health.capacity
	check(valid_remaining,"fatal counterexample derives a finite positive walkoff bound from actual remaining HP/capacity")
	if valid_remaining: walkoff_budget = int(ceil(remaining_hp)) # Existing1HP environment requests, no HP writes.
	var returns_before_fatal_walks := returns.size()
	var attempted := 0
	for index: int in walkoff_budget:
		if health.terminal or not world.session.lifetime.active: break
		var protection_frames := int(ceil(maxf(world.policy.spawn_protection,0.0)*float(Engine.physics_ticks_per_second)))+2
		await frames(protection_frames)
		var before_return_count := returns.size()
		await walk_to_hazard(world,"natural_remaining_walkoff_%d" % (index+1))
		attempted += 1
		if not health.terminal:
			check(returns.size()==before_return_count+1,"each additional nonfatal natural walkoff returns through the same segment")
			check(service_ids(world)==services and world.session.wallet.balance==wallet and module.clock>clock_before,"additional nonfatal returns keep service/HP ledger ownership and continuing clock")
	observations.append({"case":"bounded_natural_fatal_walkoffs","actual_remaining_hp":remaining_hp,"standard_environment_hp_per_hit":1.0,"walkoff_budget":walkoff_budget,"attempted":attempted,"returns_before":returns_before_fatal_walks,"returns_after":returns.size(),"scope":"only real Router axis input after original protection expires; health values/capacity unchanged by test"})
	check(world.terminal_failure and world.session.controller.actor_resources.health.terminal and not world.session.controller.active and not world.session.lifetime.active,"fatal original environment hit uses existing controller death and lifetime invalidation")
	check(world.session.flow.state==DemoRunDirector.State.ENDING_FAILURE and not world.closed and world.stage!=null,"fatal path leaves scene present with original flow failure; never quits SceneTree")
	check(returns.size()==returns_before_fatal_walks+maxi(0,walkoff_budget-1) and hits.back().lethal,"death takes priority over environment return after all actual remaining HP is naturally spent")
	check("ESC" in world.get("_label").text,"native fatal remains inspectable with explicit ESC exit hint")
	check(not world.policy.submit(stale),"ended run rejects previous hit after fatal/close boundary")

func run() -> void:
	root.size = Vector2i(1280,720)
	check(FileAccess.get_sha256(M35.BINDINGS_PATH)==M35.BINDINGS_SHA256,"single actual M35 binding file retains exact source SHA")
	await negative_admission(false)
	await negative_admission(true)
	var world := SCENE.instantiate() as RuntimeMapM35Slice
	root.add_child(world)
	var initial_positions: Array[Vector2] = []
	world.session.controller.segment_returned.connect(func() -> void: initial_positions.append(world.session.player.global_position))
	await wait_for_source(world)
	check(world.ready_ok and world.entry_admitted and world.error.is_empty(),"real generation M35 becomes ready only after actual safe physics admission: "+world.error)
	if world.ready_ok:
		check(world.generation.phase(world.ticket)=="committed" and world.session.controller.active,"same current generated ticket commits before activating player")
		check(world.session.player.global_position.distance_to(Vector2(1626,1742))<0.1,"actual initial player body is at original safe spawn, not merely a target coordinate")
		check(initial_positions.size()==1 and initial_positions[0]==world.stage.plan.spawn,"exactly one actual initial controller return event occurs at plan.spawn before activation")
		check(count_kind(world,"player")==1 and count_kind(world,"controller")==1 and count_kind(world,"policy")==1,"one original player/controller/policy composition")
		check(not world.session.controller.traversal.hook_enabled,"controlled M35 source never grants grapple")
		var actual: Dictionary = world.generation.actual_result(world.ticket,world.session.lifetime)
		static_damage_contract(world,actual)
		await clock_contract(world)
		await damage_contract(world)
	var token := world.session.lifetime.token()
	var stage_ref: WeakRef = weakref(world.stage) if is_instance_valid(world.stage) else null
	check(await world.close_preview(),"M35 original close_preview drains world audio and detaches Stage")
	check(world.closed and world.stage==null and not world.session.lifetime.accepts(token),"exit invalidates lifetime and rejects late generation/damage")
	await process_frame
	check(stage_ref==null or stage_ref.get_ref()==null,"closed M35 Stage and its hazard sources are released")
	world.free()
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/mapgen_godot_03")
	var output := FileAccess.open("res://build/mapgen_godot_03/m35_runtime.json",FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"actual generated independent M35 hazards/saw/linear physics and lifecycle only; not adjacency/fullmap/Web/device","observations":observations,"hits":hits,"returns":returns}))
		output.close()
	else:
		check(false,"write actual M35 runtime receipt")
	print("RUNTIME_MAP_M35_RUNTIME checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
