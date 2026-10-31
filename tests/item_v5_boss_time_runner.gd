extends SceneTree
## Formal P06 integration. Known rewards, Director completion, relocation and
## the explicit flight-extension position below are SETUP FIXTURES, never a
## natural Boss clear. HP/stamina are never injected. Space/mouse/D use the
## actual installed adapter; attacks come from the real Windkeeper encounter.
var app: Variant
var assertions := 0
var failures := 0
var damage_records: Array[Dictionary] = []
var shot_count := 0
func shot(_direction: Vector2, _id: int) -> void: shot_count += 1

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func frames(n := 2) -> void:
	for unused: int in n: await process_frame
func ticks(n := 2) -> void:
	for unused: int in n:
		await physics_frame
		await process_frame
func wait_stage() -> bool:
	for unused: int in 300:
		if is_instance_valid(app.stage) and not app._stage_pending: return true
		await frames(1)
	return false
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event,true)
func aim(down: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(700,300)
	motion.relative = Vector2(1,-1)
	root.push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.position = motion.position
	event.button_index = int(app.controller.router.profile.values.mouse_shoot_button) if is_instance_valid(app.controller) else MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event,true)
func nodes_of(node: Node, script_class: String) -> Array[Node]:
	var result: Array[Node] = []
	var script := node.get_script() as Script
	if script != null and script.get_global_name() == script_class: result.append(node)
	for child: Node in node.get_children(): result.append_array(nodes_of(child,script_class))
	return result
func reward(id: StringName, suffix := "") -> void:
	var offer_id := StringName("boss_time_fixture/"+String(id)+suffix)
	var catalog: Variant = load("res://scripts/items/v5/item_catalog_v5.gd")
	var choices: Variant = catalog.all_items()
	choices.clear()
	choices.append(catalog.get_item(id))
	var offer: Variant = app.rewards.create_cache_offer(offer_id,choices,offer_id)
	check(offer != null,"SETUP original reward service admits "+String(id))
	var request: Variant = load("res://scripts/rewards/reward_claim_request.gd").new()
	request.token = app.lifetime.token()
	request.offer_id = offer_id
	request.option_id = id
	request.claim_id = StringName(String(offer_id)+"/claim")
	check(app.rewards.claim(request).accepted(),"SETUP original reward transaction owns "+String(id))
func equip(ids: Array[StringName]) -> void:
	var desired: Array[StringName] = []
	for id: StringName in ids:
		var owned: Variant = app.build.inventory.instance_for_definition(id)
		check(owned != null,"actual inventory owns "+String(id))
		if owned != null: desired.append(owned.instance_id)
	app.toggle_pause()
	check(paused and app.menu.visible_panel == &"build","actual pause opens equipment session")
	app._submit_equipment(desired,int(app.build.equipment.snapshot().revision),app._equipment_session)
	check(app.build.equipment.equipped_ids() == desired,"actual equipment command commits fixture selection")
	await frames()
	app.menu.close_panel()
	await ticks()
	for id: StringName in ids: check(app._item_runtime.has(id),"formal runtime observes equipped "+String(id))
func collision_nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if node is CollisionObject2D: result.append(node)
	for child: Node in node.get_children(): result.append_array(collision_nodes(child))
	return result
func floor_at(point: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(point+Vector2(0,-8),point+Vector2(0,160),1,[app.player.get_rid()])
	return app.player.get_world_2d().direct_space_state.intersect_ray(query)
func relocate(point: Vector2, reset_motion := true) -> void:
	# Epoch invalidation suppresses a fictitious contact sweep across relocation.
	app.player.global_position = point
	app.lifetime.invalidate_actor()
	if reset_motion: app.controller.motor.reset_motion()
func observe_player() -> void:
	if not app.controller.actor_resources.health.changed.is_connected(_health_changed): app.controller.actor_resources.health.changed.connect(_health_changed)
	if not app.controller.shoot_ability.shot_fired.is_connected(shot): app.controller.shoot_ability.shot_fired.connect(shot)

func _health_changed(result: Variant) -> void:
	if result.operation == &"damage" and result.amount_applied < 0:
		damage_records.append({"frozen":app._item_runtime.world_is_frozen(),"amount":-result.amount_applied,"event":result.event_id})
func start_freeze(shore: Vector2, expected_frozen := true, flight_extension := 350.0) -> bool:
	aim(false)
	key(KEY_SPACE,false)
	relocate(shore)
	await ticks(5)
	check(app.player.is_on_floor(),"real arena floor supports the player before takeoff")
	key(KEY_SPACE,true)
	await ticks(3)
	check(not app.player.is_on_floor() and app.player.velocity.y < 0,"Space adapter executes a real upward jump")
	# Flight extension is a position-only fixture. Preserve live velocity and
	# spent jump count; do not refill the normal two-second/stamina budgets.
	relocate(app.player.global_position+Vector2(0,-flight_extension),false)
	aim(true)
	await ticks(3)
	check(app.controller.router.aim_engaged,"mouse adapter owns actual air-aim intent")
	check(app.controller.air_focus_ability.active,"actual AirFocus enters on airborne mouse aim")
	check(app._item_runtime.world_is_frozen() == expected_frozen,"actual focus has the expected P06 world-freeze eligibility")
	return app.controller.air_focus_ability.active and app._item_runtime.world_is_frozen() == expected_frozen
func _exercise() -> void:
	app.start_plains("level-design-v2-baseline/08")
	check(await wait_stage(),"formal Plains map one finishes generation")
	check(app.lifetime.active and app.controller.active,"formal run and actual controller are live")
	observe_player()
	for id: StringName in [&"P06",&"N01",&"B06",&"B04"]: reward(id)
	await equip([&"P06",&"N01"])
	var token: Variant = app.lifetime.token()
	check(app.director.complete_stage(token),"SETUP Director completion fixture permits map advance; no Boss kill injected")
	check(app.director.advance_region_map(token,&"boss_time_fixture/map2").accepted(),"original Director enters formal map two")
	check(await wait_stage(),"formal Plains map two finishes generation")
	check(app.director.region_map_index == 2,"actual Director reports map two")
	check(app.stage.boss.get_node("Encounter") is WindkeeperEncounter,"actual formal encounter is Windkeeper")
	var boss: WindkeeperEncounter = app.stage.boss.get_node("Encounter") as WindkeeperEncounter
	if boss == null: return
	var arena: Rect2 = app.stage.boss_arena
	var shape := app.player.get_node("CollisionShape2D") as CollisionShape2D
	var feet: float = shape.position.y+(shape.shape as RectangleShape2D).size.y*.5
	var shore := Vector2(arena.position.x+100,boss._floor_y-feet-.1)
	relocate(shore)
	await ticks(8)
	if not app._boss_started: app._start_generated_boss()
	check(app._boss_started and boss.active,"original DemoApp activation starts real Windkeeper encounter")
	check(boss.continuous_combat(),"real Boss uses formal continuous-combat profile")
	check(app.controller.actor_resources.health.current == app.controller.actor_resources.health.capacity,"P06 starts at naturally full HP without HP injection")
	# Wait for the original timed stomp to emit actual moving ring projectiles.
	for unused: int in 450:
		if boss._projectiles.any(func(p: Variant) -> bool: return is_instance_valid(p) and p is BossProjectile and not p.spent): break
		await ticks(1)
	var projectiles: Array[BossProjectile] = []
	for candidate: Variant in boss._projectiles:
		if is_instance_valid(candidate) and candidate is BossProjectile and not candidate.spent: projectiles.append(candidate)
	check(projectiles.size() >= 2,"original Windkeeper timers create genuine paired attack projectiles")
	check(app.controller.actor_resources.health.current == app.controller.actor_resources.health.capacity,"safe shore waiting preserves real full HP")
	var floor_before := floor_at(shore)
	check(not floor_before.is_empty(),"real arena floor is present in physics before freezing")
	var emitters := nodes_of(app.stage,"DemoContactEmitter")
	check(not emitters.is_empty(),"formal stage contains actual player-contact observers")
	var modules := nodes_of(app.stage,"PlatformingModule")
	check(not modules.is_empty(),"formal stage contains real clock-driven platform modules")
	var body_modes: Array[Dictionary] = []
	for body: Node in collision_nodes(app.stage): body_modes.append({"node":weakref(body),"disable":(body as CollisionObject2D).disable_mode,"process":body.process_mode})
	var before_modes: Dictionary = {}
	for node: Node in emitters: before_modes[node.get_instance_id()] = node.process_mode
	if not await start_freeze(shore): return
	check(app._item_runtime.is_live(),"world freezing preserves native live guard")
	check(Engine.time_scale > 0 and is_equal_approx(Engine.time_scale,1),"P06 keeps the engine/player/UI clock positive at one")
	check(is_zero_approx(app._item_runtime._time.world_scale(.2)),"P06 full-HP world-zero takes priority over equipped N01")
	var stage_clock: float = app.stage.clock
	var boss_clock: float = boss.clock
	var boss_position := boss.motor.global_position
	var mode: StringName = boss.mode
	var module_clocks: Dictionary = {}
	for module: Node in modules: module_clocks[module.get_instance_id()] = module.clock
	var mechanisms: Array[Dictionary] = []
	for kind: String in ["ModuleMovingPlatform","ModuleSawHazard"]:
		var found := nodes_of(app.stage,kind)
		check(not found.is_empty(),"actual stage supplies a real mechanism consumer: "+kind)
		for node: Node in found:
			mechanisms.append({"node":weakref(node),"position":(node as Node2D).global_position,"rotation":(node as Node2D).global_rotation})
	var projectile_samples: Array[Dictionary] = []
	for projectile: BossProjectile in projectiles:
		if is_instance_valid(projectile): projectile_samples.append({"node":weakref(projectile),"position":projectile.global_position,"life":projectile.lifetime,"age":projectile._visual_age})
	var start_stamina: float = app.controller.air_focus_ability.stamina
	var start_used: float = app.controller.air_focus_ability.air_time_used
	var start_point: Vector2 = app.player.global_position
	key(KEY_D,true)
	await ticks(32)
	key(KEY_D,false)
	check(app._item_runtime.world_is_frozen(),"actual P06 remains world-zero for more than half an active second")
	check(is_equal_approx(app.stage.clock,stage_clock),"real stage clock does not advance during P06")
	check(is_equal_approx(boss.clock,boss_clock) and boss.mode == mode,"real Windkeeper attack timer and phase do not advance")
	check(boss.motor.global_position.is_equal_approx(boss_position),"real Windkeeper body retains frozen position")
	for module: Node in modules: check(is_equal_approx(module.clock,float(module_clocks[module.get_instance_id()])),"actual platform module clock remains frozen: "+module.name)
	for sample: Dictionary in projectile_samples:
		var projectile := (sample.node as WeakRef).get_ref() as BossProjectile
		check(is_instance_valid(projectile),"real Boss attack survives the frozen observation interval")
		if is_instance_valid(projectile):
			check(projectile.global_position.is_equal_approx(sample.position),"real Boss projectile position is frozen")
			check(is_equal_approx(projectile.lifetime,float(sample.life)) and is_equal_approx(projectile._visual_age,float(sample.age)),"real Boss projectile lifetime and visual age are frozen")
	for row: Dictionary in mechanisms:
		var mechanism := (row.node as WeakRef).get_ref() as Node2D
		check(is_instance_valid(mechanism) and mechanism.global_position.is_equal_approx(row.position) and is_equal_approx(mechanism.global_rotation,float(row.rotation)),"actual saw/platform transform remains frozen: "+str(mechanism.name))
	for row: Dictionary in body_modes:
		var body := (row.node as WeakRef).get_ref() as CollisionObject2D
		check(is_instance_valid(body) and body.disable_mode == CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE,"frozen real Collider remains active in the physics space")
	check(app.player.global_position.x > start_point.x+30,"actual D input still moves player through frozen world")
	var used: float = app.controller.air_focus_ability.air_time_used-start_used
	check(used >= .5 and used < .65,"focus budget advances by true activity time during 32 physics ticks")
	check(is_equal_approx(start_stamina-app.controller.air_focus_ability.stamina,used*45),"frozen world drains original 45 stamina per real-active second")
	check(app.controller.air_focus_ability.air_time_used <= 2,"P06 does not extend original two-second flight focus budget")
	var floor_frozen := floor_at(shore)
	check(not floor_frozen.is_empty() and floor_frozen.get("rid") == floor_before.get("rid"),"COUNTEREXAMPLE real floor collider remains queryable while world is frozen")
	for emitter: Node in emitters:
		if (emitter as DemoContactEmitter).enabled: check(emitter.can_process(),"COUNTEREXAMPLE frozen world preserves player-contact observation: "+String((emitter as DemoContactEmitter).source_id))
	var used_before_cancel: float = app.controller.air_focus_ability.air_time_used
	var stamina_before_cancel: float = app.controller.air_focus_ability.stamina
	app.controller.router.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not app._item_runtime.world_is_frozen() and not app._item_runtime.is_live(),"application focus-out immediately cancels frozen world and live operations")
	await ticks(2)
	check(is_equal_approx(app.controller.air_focus_ability.air_time_used,used_before_cancel) and is_equal_approx(app.controller.air_focus_ability.stamina,stamina_before_cancel),"unfocused airborne actor gains no free stamina or focus budget")
	for row: Dictionary in body_modes:
		var body := (row.node as WeakRef).get_ref() as CollisionObject2D
		check(is_instance_valid(body) and body.disable_mode == int(row.disable),"focus-out restores each original Collider disable_mode")
	app.controller.router.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	aim(false)
	key(KEY_SPACE,false)
	aim(true)
	await ticks(2)
	check(app._item_runtime.world_is_frozen(),"new deliberate mouse aim re-enters P06 after focus returns")
	var paused_shots := shot_count
	app.toggle_pause()
	check(paused and not app._item_runtime.world_is_frozen(),"real pause opens build page and releases all frozen process flags")
	var paused_clock: float = app.stage.clock
	var paused_used: float = app.controller.air_focus_ability.air_time_used
	var paused_stamina: float = app.controller.air_focus_ability.stamina
	await frames(8)
	check(app.stage.clock == paused_clock and app.controller.air_focus_ability.air_time_used == paused_used and app.controller.air_focus_ability.stamina == paused_stamina,"real pause advances neither world simulation nor player focus resources")
	for row: Dictionary in body_modes:
		var body := (row.node as WeakRef).get_ref() as CollisionObject2D
		check(is_instance_valid(body) and body.disable_mode == int(row.disable),"pause restores every original Collider disable_mode")
	app.menu.close_panel()
	aim(false)
	await ticks(2)
	check(shot_count == paused_shots,"closing paused build and releasing held mouse cannot fire a primary")
	aim(true)
	await ticks(2)
	check(app._item_runtime.world_is_frozen() and app.controller.air_focus_ability.air_time_used >= paused_used,"fresh aim after pause uses the existing flight budget")
	# Genuine enemy-body contact while P06 is active must damage (no free
	# invulnerability). Relocation is explicit only; the real observer/policy
	# must produce the hit without calling a damage callback or submitting HP.
	var contacts := nodes_of(boss.motor,"DemoContactEmitter")
	check(not contacts.is_empty(),"real activated Boss has its original body-contact observer")
	if not contacts.is_empty():
		var hp: float = app.controller.actor_resources.health.current
		var contact: Variant = app._boss_contact
		check(contact in contacts and contact.source_id == &"boss_contact","body-contact fixture selects the actual coordinator observer, not disabled bridge fall plane")
		var point: Vector2 = contact.global_position
		if contact.contact_rect_provider.is_valid(): point = (contact.contact_rect_provider.call() as Rect2).get_center()
		relocate(point)
		await ticks(3)
		print("BOSS FROZEN CONTACT DIAGNOSTIC ",JSON.stringify({"source":contact.source_id,"boss_contact_same":contact == app._boss_contact,"app_process":app.can_process(),"director_state":app.director.state,"boss_started":app._boss_started,"boss_active":boss.active,"boss_enabled":boss.body_contact_enabled(),"stage_pending":app._stage_pending,"point":point,"actual":app.player.global_position,"enabled":contact.enabled,"can_process":contact.can_process(),"touching":contact._was_touching,"pulse":contact._pulse,"in_core":app._in_boss_core(),"protected_until":app.policy._protected_until,"monster_until":app.policy._monster_until,"playerclock":app.policy.player_clock(),"clock":app.policy.clock,"hp":app.controller.actor_resources.health.current,"frozen":app._item_runtime.world_is_frozen(),"mode":boss.mode}))
		check(app.controller.actor_resources.health.current < hp,"COUNTEREXAMPLE entering actual frozen enemy body causes true HP damage")
		check(damage_records.any(func(row: Dictionary) -> bool: return bool(row.frozen)),"COUNTEREXAMPLE true HP damage commits while P06 was world-zero")
	key(KEY_SPACE,false)
	aim(false)
	await ticks(3)
	check(not app._item_runtime.world_is_frozen(),"mouse release restores world after frozen contact")
	check(Engine.time_scale > 0,"release never leaves a zero engine clock")
	for node: Node in emitters: check(node.process_mode == int(before_modes[node.get_instance_id()]),"world release restores original contact process flags")
	for row: Dictionary in body_modes:
		var body := (row.node as WeakRef).get_ref() as CollisionObject2D
		check(is_instance_valid(body) and body.disable_mode == int(row.disable) and body.process_mode == int(row.process),"release restores exact original real Collider process/disable flags")
	var restored_clock: float = app.stage.clock
	await ticks(3)
	check(app.stage.clock > restored_clock,"real stage resumes after release")
	check(not app.controller.actor_resources.health.terminal,"contact counterexample does not create a death fixture")
	await stationary_boss_projectile_case(shore,boss)
	await pendulum_levels(app.stage.spawn)
	await static_hazard_and_scene_case()

func recover_on_real_floor(point: Vector2) -> void:
	# Cancel via the real Router before setup relocation; a release primary
	# must not add recoil to the floor-admission fixture.
	app.controller.router.clear("fixture_ground_recovery")
	aim(false)
	key(KEY_SPACE,false)
	relocate(point)
	await ticks(100)
	check(app.player.is_on_floor(),"explicit safe-ground relocation is supported by the original map floor")
	check(not app.controller.air_focus_ability.active and is_zero_approx(app.controller.air_focus_ability.air_time_used),"actual landing alone rearms the normal focus flight budget")
	if not app.player.is_on_floor(): print("BOSS FLOOR FIXTURE DIAGNOSTIC ",JSON.stringify({"requested":point,"actual":app.player.global_position,"velocity":app.player.velocity,"focus":app.controller.air_focus_ability.active,"hp":app.controller.actor_resources.health.current}))

func pendulum_levels(safe_ground: Vector2) -> void:
	check(app.controller.actor_resources.health.current < app.controller.actor_resources.health.capacity,"N01 fallback uses the actual prior Boss HP injury, without HP injection")
	await equip([&"P06",&"N01",&"B04"])
	check(is_equal_approx(app.controller.motor.tuning.focus_stamina_drain,45*.82),"equipped Lv1 B04 derives original focus drain from the table multiplier")
	for level: int in [1,2,3]:
		if level > 1: reward(&"N01","/level_%s" % level)
		await recover_on_real_floor(safe_ground)
		if not await start_freeze(safe_ground,false): continue
		var expected := [.12,.10,.08][level-1] as float
		check(is_equal_approx(Engine.time_scale,expected) and Engine.time_scale > 0,"real non-full-HP airborne N01 level %s selects positive world slowdown" % level)
		var before: float = app.controller.air_focus_ability.stamina
		var used: float = app.controller.air_focus_ability.air_time_used
		var world_clock: float = app.stage.clock
		await ticks(12)
		var elapsed: float = app.controller.air_focus_ability.air_time_used-used
		check(is_equal_approx(before-app.controller.air_focus_ability.stamina,elapsed*45*.82),"actual B04+N01 stamina cost follows real activity rather than slowed world seconds")
		check(app.stage.clock > world_clock and app.stage.clock-world_clock < elapsed*.2,"N01 actual stage advances slowly instead of entering zero-time freeze")
		aim(false)
		await ticks(2)
		check(is_equal_approx(Engine.time_scale,1) and not app._item_runtime.world_is_frozen(),"N01 input release restores the normal engine clock at every level")
	await recover_on_real_floor(safe_ground)
	if await start_freeze(safe_ground,false):
		await ticks(150)
		check(not app.controller.air_focus_ability.active and is_equal_approx(app.controller.air_focus_ability.air_time_used,2),"actual long N01 air aim exhausts exactly the original two-real-second flight budget")
		check(app.controller.air_focus_ability.stamina > 0 and is_equal_approx(Engine.time_scale,1),"B04 keeps time energy available but cannot extend the two-second flight budget")
		aim(false)

func actual_heart_fixture() -> bool:
	for pickup: Dictionary in app.stage.pickups:
		if pickup.kind != "heart" or bool(pickup.claimed): continue
		var before: float = app.controller.actor_resources.health.current
		# Position-only fixture reaches the existing formal supply heart; original
		# pickup distance admission, action queue, health API and receipt execute.
		relocate(pickup.position)
		await ticks(4)
		check(bool(pickup.claimed) and app.controller.actor_resources.health.current > before,"original formal supply pickup heals true prior injury through its receipt")
		return app.controller.actor_resources.health.current == app.controller.actor_resources.health.capacity
	return false

func stationary_boss_projectile_case(shore: Vector2, boss: WindkeeperEncounter) -> void:
	check(await actual_heart_fixture(),"formal existing supply heart restores full P06 eligibility without injecting HP")
	# The preceding body injury legitimately owns a .65s monster iframe. Wait
	# for that original player-clock deadline; consuming a bullet during its
	# protection would correctly discard damage and cannot prove invulnerability.
	for unused: int in 90:
		if app.policy.player_clock() >= app.policy._monster_until+.05: break
		await ticks(1)
	check(app.policy.player_clock() >= app.policy._monster_until,"prior real Boss injury protection expires before stationary-bullet contact")
	await equip([&"P06",&"N01"])
	# Return to real arena shore. Wait for any genuine next attack produced by
	# original Boss logic; no projectile is manufactured or repositioned.
	relocate(shore)
	await ticks(4)
	var candidate: BossProjectile
	for unused: int in 600:
		for value: Variant in boss._projectiles:
			if is_instance_valid(value) and value is BossProjectile and not value.spent and value._visible_attack() and value.direction.x > 0 and app.stage.boss_arena.has_point(value.global_position):
				candidate = value
				break
		if candidate != null: break
		await ticks(1)
	check(is_instance_valid(candidate),"original live Windkeeper pattern supplies a genuine visible in-arena projectile for stationary contact")
	if not is_instance_valid(candidate): return
	if not await start_freeze(shore): return
	check(is_instance_valid(candidate) and not candidate.spent,"actual hostile projectile remains live at freeze entry")
	if not is_instance_valid(candidate): return
	var point := candidate.global_position
	var life := candidate.lifetime
	var age := candidate._visual_age
	var hp: float = app.controller.actor_resources.health.current
	var records := damage_records.size()
	var collision := app.player.get_node("CollisionShape2D") as CollisionShape2D
	var feet: float = collision.position.y+(collision.shape as RectangleShape2D).size.y*.5
	var contact_samples: Array[Dictionary] = []
	var projectile_ref: WeakRef = weakref(candidate)
	candidate.hit.connect(func(_body: Node2D,_event: StringName,_amount: float) -> void:
		var stopped := projectile_ref.get_ref() as BossProjectile
		if is_instance_valid(stopped): contact_samples.append({"point":stopped.global_position,"life":stopped.lifetime,"age":stopped._visual_age,"frozen":app._item_runtime.world_is_frozen(),"grounded":app.player.is_on_floor()}))
	# Touch the stationary circle's upper face while the actual player feet
	# remain above the floor. Center placement would correctly land first and
	# cancel airborne focus before damage, proving a different normal path.
	relocate(point+Vector2(0,-candidate.radius-feet+1.0))
	await ticks(2)
	check(app.controller.actor_resources.health.current < hp,"entering an actual stationary frozen Boss projectile causes true HP damage")
	check(damage_records.size() > records and bool(damage_records.back().frozen),"stopped hostile bullet HP damage commits while P06 world-zero was active")
	check(not is_instance_valid(candidate) or candidate.spent,"stationary hostile projectile contact consumes its original one-shot event")
	check(contact_samples.size() == 1 and bool(contact_samples[0].frozen) and not bool(contact_samples[0].grounded),"real hostile shape emits its single collision while world-zero and player remains airborne")
	if not contact_samples.is_empty(): check((contact_samples[0].point as Vector2).is_equal_approx(point) and is_equal_approx(float(contact_samples[0].life),life) and is_equal_approx(float(contact_samples[0].age),age),"frozen hostile contact advances neither position nor lifetime/visual age")
	# A surviving spent reference must not have consumed simulation time to hit.
	if is_instance_valid(candidate): check(candidate.global_position.is_equal_approx(point) and candidate.lifetime == life and candidate._visual_age == age,"stationary contact changes no projectile position, lifetime or visual age")
	aim(false)
	key(KEY_SPACE,false)
	await ticks(2)

func static_hazard_and_scene_case() -> void:
	app.abandon_run()
	await frames(3)
	check(not app.lifetime.active and not app._item_runtime.world_is_frozen(),"real run end clears the prior world scope")
	app.start_plains("level-design-v2-baseline/08")
	check(await wait_stage(),"new formal run supplies naturally fresh HP for static-danger case")
	observe_player()
	reward(&"P06")
	await equip([&"P06"])
	var source: DemoContactEmitter
	var static_entry := Vector2.ZERO
	var actor_shape := app.player.get_node("CollisionShape2D") as CollisionShape2D
	var actor_half: Vector2 = (actor_shape.shape as RectangleShape2D).size*.5
	var actor_feet: float = actor_shape.position.y+actor_half.y
	# Find a genuine thorn top-face entry whose whole player rectangle stays
	# outside every moving saw's complete authored travel envelope. Rooted
	# thorns may share a module with a saw; their exposed edge is still a
	# distinct actual static source and must keep its own event identity.
	for node: Node in nodes_of(app.stage,"DemoContactEmitter"):
		var observer := node as DemoContactEmitter
		if observer.kind != DamageRequest.Kind.ENVIRONMENT or observer.fall_plane or not observer.enabled: continue
		for offset: float in [-observer.half_size.x+1.0,observer.half_size.x-1.0,0.0]:
			var entry := observer.global_position+Vector2(offset,-observer.half_size.y-actor_feet+1.0)
			var actor_rect := Rect2(entry-actor_half,actor_half*2)
			var isolated := true
			for saw_node: Node in nodes_of(app.stage,"ModuleSawHazard"):
				var saw := saw_node as ModuleSawHazard
				var envelope: Rect2 = saw.definition.envelope()
				envelope.position = saw.module.to_global(envelope.position)
				if envelope.grow(2).intersects(actor_rect):
					isolated = false
					break
			if isolated:
				source = observer
				static_entry = entry
				break
		if source != null: break
	check(is_instance_valid(source),"real formal stage contains an enabled non-fall static damage source")
	if not is_instance_valid(source): return
	var inventory: Array[StringName] = app.build.inventory.item_ids()
	var capacity: int = int(app.build.equipment.snapshot().capacity)
	await recover_on_real_floor(app.stage.spawn)
	if not await start_freeze(app.stage.spawn,true,100.0): return
	var hp: float = app.controller.actor_resources.health.current
	var records := damage_records.size()
	var point := static_entry
	relocate(point)
	await ticks(3)
	print("FROZEN STATIC CONTACT DIAGNOSTIC ",JSON.stringify({"source":source.source_id,"parent_class":source.get_parent().get_class(),"point":point,"source_half":source.half_size,"hp":app.controller.actor_resources.health.current,"records":damage_records.slice(records),"grounded":app.player.is_on_floor(),"frozen":app._item_runtime.world_is_frozen()}))
	check(app.controller.actor_resources.health.current < hp,"actual frozen static hazard still deals true environment HP damage")
	check(damage_records.size() > records and bool(damage_records.back().frozen),"static-danger injury commits during actual world-zero rather than after a manual release")
	check(damage_records.size() > records and str(damage_records.back().event).begins_with(String(source.source_id)+":"),"true static-danger injury retains the selected generated-spikes source rather than a nearby moving saw")
	check(app.lifetime.active and app.build.inventory.item_ids() == inventory and int(app.build.equipment.snapshot().capacity) == capacity,"surviving actual environment fallback preserves run inventory and gear capacity")
	check(not app._item_runtime.world_is_frozen(),"actual environment return cancels stale world freeze")
	# A separate legitimate run provides naturally full HP for scene teardown;
	# this does not mutate health or reset the preceding run's injury receipts.
	app.abandon_run()
	await frames(3)
	app.start_plains("level-design-v2-baseline/08")
	check(await wait_stage(),"third formal run enters before scene-change cancellation case")
	observe_player()
	reward(&"P06")
	await equip([&"P06"])
	if not await start_freeze(app.stage.spawn,true,100.0): return
	var frozen_stage: WeakRef = weakref(app.stage)
	var captured: int = int(app._item_runtime._time.snapshot().world.frozen_nodes)
	check(captured > 0,"real stage nodes are actually captured before run-end scene replacement")
	app.abandon_run()
	check(not app._item_runtime.world_is_frozen() and int(app._item_runtime._time.snapshot().world.frozen_nodes) == 0,"actual abandon/scene replacement releases every captured process record")
	await frames(4)
	check(frozen_stage.get_ref() == null,"replaced actual frozen stage frees safely with no stale weak-reference processing")
	check(is_equal_approx(Engine.time_scale,1) and not app._item_runtime.is_live(),"Home transition restores normal clock and invalidates all old live item operations")

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	app = load("res://scripts/demo/demo_app.gd").new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(5)
	await _exercise()
	key(KEY_D,false)
	key(KEY_SPACE,false)
	aim(false)
	paused = false
	if is_instance_valid(app.controller): app.controller.air_focus_ability.stop()
	check(await preload("res://tests/audio_teardown.gd").drain_world(app),"actual audio backends drain before strict teardown")
	app.free()
	app = null
	await frames(3)
	print("ITEM V5 BOSS TIME: %s checks, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
