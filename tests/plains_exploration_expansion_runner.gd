extends SceneTree

const GEAR := preload("res://tests/gear_inventory_support.gd")
var assertions:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func frames(n: int=1) -> void:
	for unused: int in n: await physics_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/verification/generated/plains_cohesion")
	var g:=PlainsRegionGenerator.new()
	var summary: Dictionary={"maps":100,"families":{},"actions":{},"pressures":{},"max_same_recipe_fraction":0.0,"max_empty_join":0.0,"fallbacks":0,"resource_modes":{},"shop_items":{}}
	for i: int in 100:
		var r:=g.generate("operation-corpus/%s" % i,PlayerTuning.load_default(),false,"","intro" if i<50 else "advanced")
		check(r.ok,"operation corpus generates")
		if not r.ok: continue
		var m: Dictionary=r.manifest
		if not m.fallback_id.is_empty(): summary.fallbacks+=1
		summary.families[m.family]=true
		var actions: Dictionary={};var pressures: Dictionary={};var recipes: Dictionary={};var total:=0
		for edge: Dictionary in m.connections:
			if edge.kind!="horizontal": continue
			actions[edge.action_signature]=true;pressures[edge.pressure]=true;recipes[edge.recipe]=int(recipes.get(edge.recipe,0))+1;total+=1
			for index: int in edge.modules:
				check(str(m.nodes[index].module_id)!="region_connection","operation signature references playable challenge geometry")
		check(actions.size()>=6 and pressures.size()>=6,"each actual map offers six different input/pressure chains")
		for key: String in recipes:
			var fraction:=float(recipes[key])/total
			summary.max_same_recipe_fraction=maxf(summary.max_same_recipe_fraction,fraction)
			check(fraction<=.35,"no operation chain dominates the generated journey choices")
		for key: String in actions: summary.actions[key]=true
		for key: String in pressures: summary.pressures[key]=true
		for n: Dictionary in m.nodes:
			if n.module_id=="region_connection": summary.max_empty_join=maxf(summary.max_empty_join,float(n.geometry.platforms[0][2]))
		var resource_budget: Dictionary={"coin":0,"heart":0,"note":0}
		for chest: Dictionary in m.rewards:
			for kind: String in resource_budget:
				var max_value: int=0
				for option: Dictionary in chest.resources:
					if option.kind==kind: max_value=maxi(max_value,int(option.amount))
				if kind=="note": max_value=maxi(max_value,1 if chest.tier=="medium" else 2 if chest.tier=="high" else 4)
				resource_budget[kind]+=max_value
			summary.resource_modes[chest.reward_mode]=true
			check(chest.resources.size()==2 and chest.resources.any(func(c: Dictionary): return c.kind=="coin" and int(c.amount)>=16),"cache records stable tier-valued real resource alternatives")
		check(resource_budget.coin<=m.budget.cache_coin_limit and resource_budget.heart<=m.budget.cache_heart_limit and resource_budget.note<=m.budget.cache_note_limit,"all cache resource values including full-health alternatives stay within recorded region budget")
		summary.shop_items[m.shop.item]=true
		if m.family=="linked_rings": check(m.connections.any(func(e: Dictionary): return e.kind=="drop" and e.a.begins_with("area_")),"well-rings have real one-way descent and distinct climb return")
	check(summary.families.size()==3 and summary.actions.size()==PlainsRouteRecipes.RECIPES.size(),"families and every authored control sequence enter actual formal maps")
	check(summary.shop_items.size()==7 and summary.resource_modes.size()==2,"shops and cache types vary independently")
	var file:=FileAccess.open("res://build/verification/generated/plains_cohesion/operation_corpus.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"  ",true));file.close()
	await item_effects()
	await current_focus_items()
	for kind: String in ["coin","heart","note"]: await resource_cache(kind)
	await save_failure_cache()
	await eligible_item_cache()
	await death_cache()
	await mini_rays()
	await enemy_behaviors()
	await formal_consumers()
	print("PLAINS EXPLORATION EXPANSION: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
func item_effects() -> void:
	# Explicit D079 item-policy fixture; preserve its original numerical checks.
	# Current one-round/AirFocus items are exercised separately below.
	var player:=preload("res://game/player/player.tscn").instantiate() as PlayerMotor
	root.add_child(player)
	var actor:=player.get_node("Controller") as PlayerController;actor.set_physics_process(false);actor.enable_shot_energy(preload("res://game/player/resources/plains_shot_energy.tres"))
	var build:=BuildState.new();build.configure(actor)
	var base_recoil:=player.tuning.ground_recoil_multiplier
	var base_burst:=player.tuning.shot_burst_speed
	check(GEAR.add_and_equip(build, &"stability",preload("res://resources/items/stability_blue.tres")),"stability installs a real modifier")
	check(is_equal_approx(player.tuning.ground_recoil_multiplier,base_recoil*.5) and player.tuning.shot_burst_speed==base_burst,"stability reduces ground recoil while preserving airborne burst")
	check(GEAR.unequip_source(build, &"stability") and player.tuning.ground_recoil_multiplier==base_recoil,"stability removal recomputes the exact baseline")
	check(GEAR.add_and_equip(build, &"braid",preload("res://tests/fixtures/demo_ui_01_r3/braided_cord_d079.tres")),"ground recovery modifier accepted")
	actor.shot_energy.consume(1001);actor.shot_energy.advance(1.35,true)
	check(is_equal_approx(actor.actor_resources.stamina.current,100),"braid's actual policy recovers 40.5 energy per grounded second, capped at capacity")
	actor.shot_energy.consume(1002);actor.shot_energy.advance(1.35,false)
	check(is_equal_approx(actor.actor_resources.stamina.current,80),"braid never recovers energy in air")
	check(GEAR.add_and_equip(build, &"cooling",preload("res://tests/fixtures/demo_ui_01_r3/cooling_fin_d079.tres")),"cooling accepts actual recovery delay modifier")
	actor.shot_energy.consume(1003);actor.shot_energy.advance(.25,true)
	check(actor.actor_resources.stamina.current>60,"cooling allows ground recovery after shorter delay")
	var cooldown:=player.tuning.shot_cooldown
	var braking:=player.tuning.ground_deceleration
	check(GEAR.add_and_equip(build, &"hammer",preload("res://resources/items/quick_hammer.tres")) and is_equal_approx(player.tuning.shot_cooldown,cooldown*.85),"hammer changes real shoot cooldown")
	check(GEAR.add_and_equip(build, &"brakes",preload("res://resources/items/brake_boots.tres")) and is_equal_approx(player.tuning.ground_deceleration,braking*1.3),"boots change real ground braking")
	var resource:=ResourceRewardChoice.make(&"test/coins","coin",16,ItemDefinition.Rarity.BLUE)
	check(resource.is_valid() and not build.can_add(resource) and ItemPresentation.icon(resource.icon_key)!=null,"resource card renders real AI icon but cannot become a fake item")
	player.free()
func current_focus_items() -> void:
	# Current defaults: real Controller, Router, Motor floor contact and AirFocus.
	# The exhausted-resource boundary below is explicit; no shadow policy/state.
	for cooling_enabled: bool in [false,true]:
		var world:=Node2D.new();root.add_child(world)
		var player:=preload("res://game/player/player.tscn").instantiate() as PlayerMotor
		player.position=Vector2(200,-1000);world.add_child(player)
		var actor:=player.get_node("Controller") as PlayerController
		actor.set_physics_process(false)
		player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
		var gamepad:=player.get_node_or_null("GamepadAdapter")
		if gamepad!=null: gamepad.set_physics_process(false)
		check(actor.enable_shot_energy() and not actor.shot_energy.definition.shooting_consumes_energy,"current item fixture keeps formal v2 shot/time separation")
		check(player.tuning.max_air_shots==1 and actor.action_resources.shot_charges==1,"current item fixture preserves default one airborne round")
		var state:=actor.actor_resources.stamina
		var focus:=actor.air_focus_ability
		check(focus.stamina_state==state,"current items use the actual shared AirFocus resource")
		var base_rate:=player.tuning.focus_stamina_recovery
		var base_rearm:=player.tuning.focus_rearm_stamina
		var build:=BuildState.new();build.configure(actor)
		check(GEAR.add_and_equip(build, &"current_braid",preload("res://resources/items/braided_cord.tres")),"current braid installs its formal focus recovery effect")
		if cooling_enabled: check(GEAR.add_and_equip(build, &"current_cooling",preload("res://resources/items/cooling_fin.tres")),"current cooling installs its formal focus rearm effect")
		var no_op_before:=state.current
		actor.shot_energy.consume(1002)
		var no_op_after_shot:=state.current
		actor.shot_energy.advance(1.35,false)
		check(state.current==no_op_before and no_op_after_shot==no_op_before,"formal shot consume/air advance leave time energy unchanged")
		print("R3_ITEM_AIR_NOOP cooling=",cooling_enabled," before=",no_op_before," after_shot=",no_op_after_shot," after_air=",state.current)
		actor.router.set_aim(&"keyboard_mouse",Vector2.RIGHT,true)
		actor._physics_process(.1*Engine.time_scale)
		check(focus.active and is_equal_approx(state.current,no_op_before-player.tuning.focus_stamina_drain*.1),"current held airborne aim consumes actual time energy once")
		actor.router.set_aim(&"keyboard_mouse",Vector2.RIGHT,false)
		var airborne_before:=state.current
		await physics_frame
		actor._physics_process(.2*Engine.time_scale)
		check(not focus.active and state.current==airborne_before and Engine.time_scale==1.0,"current braid/cooling never passively recover time energy in air")
		# Explicit near-empty resource fixture, then real held aim exhausts it.
		state.consume_continuous(state.current-player.tuning.focus_stamina_drain*.05,state.epoch)
		actor.router.set_aim(&"keyboard_mouse",Vector2.RIGHT,true)
		await physics_frame
		actor._physics_process(.1*Engine.time_scale)
		check(state.current==0 and focus.exhausted,"real AirFocus consumption reaches exhausted gate")
		actor.router.clear("current_item_landing")
		var floor_body:=StaticBody2D.new();floor_body.position=player.position+Vector2(0,100)
		var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(900,24);shape.shape=rect;floor_body.add_child(shape);world.add_child(floor_body)
		await physics_frame;await physics_frame
		for frame: int in 60:
			actor._physics_process((1.0/60)*Engine.time_scale)
			if actor._was_grounded: break
			await physics_frame
		check(player.is_on_floor() and actor._was_grounded,"current item fixture lands through real Motor collision")
		# Compare both actual policies at identical energy between old/new gates.
		state.consume_continuous(state.current,state.epoch)
		var between_gates:=base_rearm*(1.0+.65)*.5
		var seconds:=between_gates/(base_rate*1.35)
		await physics_frame
		actor._physics_process(seconds*Engine.time_scale)
		check(is_equal_approx(state.current,base_rate*1.35*seconds),"current braid actually restores 40.5 time energy per grounded second")
		check(focus.exhausted!=cooling_enabled,"current cooling rearms at its lower gate while no-cooling control stays exhausted")
		print("R3_ITEM_GROUND cooling=",cooling_enabled," energy=",state.current," rate=",player.tuning.focus_stamina_recovery," rearm=",player.tuning.focus_rearm_stamina," exhausted=",focus.exhausted)
		actor.router.set_jump_held(&"current_cooling_jump",true)
		actor.router.set_aim(&"keyboard_mouse",Vector2.RIGHT,true)
		var before_jump:=state.current
		await physics_frame
		actor._physics_process((1.0/60)*Engine.time_scale)
		check(not actor._was_grounded and focus.active==cooling_enabled,"actual Router jump re-enters slow aim only after the current cooling gate rearmed")
		check(state.current<before_jump if cooling_enabled else state.current==before_jump,"rearmed actual aim consumes energy; exhausted control neither consumes nor recovers")
		actor.router.clear("current_item_cleanup")
		check(await load("res://tests/audio_teardown.gd").drain_world(world),"current item fixture observes bounded actual audio release")
		world.free();await physics_frame
func cache_app(kind: String):
	var app=load("res://game/application/demo_app.gd").new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_plains("cache-kind-"+kind),"formal cache fixture starts")
	# Let actual spawn protection expire before damage-race fixtures.
	await frames(64)
	# Isolate chest transaction from unrelated nearby automatic pickups/contacts.
	# Policy batches, player health, reward services and saves remain real.
	app.set_physics_process(false)
	for contact: DemoContactEmitter in app.stage.find_children("*","DemoContactEmitter",true,false): contact.enabled=false
	for module: PlatformingModule in app.stage.assembler.modules:
		for hazard: ModuleSawHazard in module.hazards: hazard.enabled=false
	var stage:=app.stage as PlainsRegionStage
	var chest: Dictionary=stage.chests.filter(func(c: Dictionary): return c.tier=="medium")[0]
	# Explicit selection fixture, not claimed as GUI walking/exploration evidence.
	chest.reward_mode="resources";chest.resources=[{"kind":"coin","amount":16},{"kind":kind,"amount":2}]
	if kind=="coin": chest.resources[1]={"kind":"note","amount":1}
	if kind=="heart":
		var state: HealthState=app.controller.actor_resources.health
		state.apply_damage(ActorResourceRequest.new(&"cache_fixture_hurt",state.epoch,2,state.get_instance_id()))
	app.player.position=chest.position
	app._region_interact()
	return app
func resource_cache(kind: String) -> void:
	var app=await cache_app(kind)
	check(app.reward_modal.opened and paused,"map cache presents resource choices before claiming")
	var before_coins: int=app.wallet.balance;var before_hp: float=app.controller.actor_resources.health.current;var before_notes: int=app.meta.snapshot().notes
	var id:=StringName((app.stage as PlainsRegionStage).chests[app._region_chest].id+"/resource/"+kind)
	check(app._claim_modal_item(id),"resource click queues transaction after damage batch")
	check(not app._claim_modal_item(id),"double click cannot queue duplicate choice")
	await frames(3)
	check(not app.reward_modal.opened and not paused,"successful resource claim closes and resumes")
	if kind=="coin":
		print("CACHE COIN SAMPLE before=",before_coins," after=",app.wallet.balance," grants=",app.wallet._grants)
		check(app.wallet.balance==before_coins+16,"coins go only to real run wallet, without duplicate item bonus")
	elif kind=="heart":
		print("CACHE HP SAMPLE before=",before_hp," after=",app.controller.actor_resources.health.current)
		check(app.controller.actor_resources.health.current==before_hp+2,"resource chest heals real current HP")
	else: check(app.meta.snapshot().notes==before_notes+2,"notes go to actual permanent progression account")
	check(not app._claim_modal_item(id),"claimed resource cannot be claimed again")
	app._region_interact();check(not app.reward_modal.opened,"re-entering claimed cache does not redraw rewards")
	app.abandon_run()
	if not await load("res://tests/audio_teardown.gd").drain_world(app):
		failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
	app.free();await frames(2)
func save_failure_cache() -> void:
	var app=await cache_app("note")
	var notes: int=app.meta.snapshot().notes
	var chest_id: String=(app.stage as PlainsRegionStage).chests[app._region_chest].id
	var path: String="user://d080_cache_retry_%s.json" % app.get_instance_id()
	app.meta._save=MetaSaveService.new();app.meta._save.configure(path,false);app.meta._save.blocked=true
	check(app._claim_modal_item(StringName(chest_id+"/resource/note")),"note cache selection uses queued save transaction")
	await frames(3)
	check(app.reward_modal.opened and paused and not app.region_state.claimed.has(chest_id) and app.meta.snapshot().notes==notes,"save failure preserves unclaimed cache, original balance and modal")
	check(app.reward_modal._footer.text.contains("SAVE FAILED") and app.reward_modal._footer.text.contains("RETRY"),"save failure is readable inside current modal")
	app.meta._save.blocked=false
	check(app._claim_modal_item(StringName(chest_id+"/resource/note")),"same fixed note option can retry after write recovery")
	await frames(3)
	check(app.meta.snapshot().notes==notes+2 and app.region_state.claimed.has(chest_id),"successful retry commits once and marks stable cache ID")
	app.abandon_run()
	if not await load("res://tests/audio_teardown.gd").drain_world(app):
		failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
	app.free();await frames(2)
	for suffix: String in ["",".backup",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
func eligible_item_cache() -> void:
	var app=load("res://game/application/demo_app.gd").new();app.meta_persistence_enabled=false;root.add_child(app);app.start_plains("one-eligible-cache");await frames(4)
	var chest: Dictionary=(app.stage as PlainsRegionStage).chests.filter(func(c: Dictionary): return c.tier=="medium")[0]
	# Explicit two-definition fixture through the existing V5 provider seam.
	# Generate the actual frozen cache first, then advance one owned item to its
	# real maximum level; re-entering filters that frozen result without rerolls.
	var damage:=ItemCatalogV5.get_item(&"B03")
	var health_item:=ItemCatalogV5.get_item(&"B11")
	app._item_v5_pool.configure(app.build,func() -> Array[ItemDefinition]: return [damage,health_item])
	var initial: Array[ItemDefinition]=app._v5_cache_items(chest)
	check(initial.size()==2,"controlled actual V5 cache freezes both initially eligible definitions")
	var cache_key:=StringName(app._run_receipt_prefix+"/"+str(chest.id))
	var manifest: Dictionary=app._item_v5_pool.manifest_for(cache_key)
	for i: int in damage.max_level: check(app.build.add_item(StringName("owned/%s" % i),damage),"real V5 ownership advances excluded item to its level cap")
	check(ItemV5Eligibility.offer_reason(damage,app.build)==&"maximum_level" and ItemV5Eligibility.offer_reason(health_item,app.build).is_empty(),"actual V5 level cap leaves exactly one eligible cache item")
	chest.reward_mode="item_resource";chest.resources=[{"kind":"coin","amount":16},{"kind":"note","amount":1}]
	var health: HealthState=app.controller.actor_resources.health
	var before_capacity: float=health.capacity;var before_hp: float=health.current
	app.player.position=chest.position;app._region_interact()
	check(app.reward_modal.opened and app._region_offer!=null and app._region_offer.candidates.size()==2 and app._region_offer.candidates[0].stable_id==&"B11","one eligible V5 item stays available beside a real resource")
	if app._region_offer!=null and app._region_offer.candidates.size()==2:
		var resource:=app._region_offer.candidates[1] as ResourceRewardChoice
		check(resource!=null and resource.resource_kind=="coin" and resource.amount==16,"single eligible item retains the original real coin alternative")
	check(app._item_v5_pool.manifest_for(cache_key)==manifest,"ownership filtering preserves the original cache Manifest and RNG draw")
	check(app._claim_modal_item(&"B11"),"one-item cache selects through actual reward service")
	await frames(3)
	var owned: RunItemInstance=app.build.inventory.instance_for_definition(&"B11")
	check(owned!=null and app.build.count_item(&"B11")==1 and chest.claimed and app.region_state.claimed.has(chest.id),"retained eligible item commits once to inventory and actual claimed ledger")
	check(health.capacity==before_capacity and health.current==before_hp and app.build.item_ids().is_empty(),"owned cache item has no effect until explicitly equipped")
	if owned!=null:
		var capacity_add: float=float(health_item.effect_parameters.max_hp_add_by_level[0])
		check(GEAR.equip_ids(app.build,[owned.instance_id]) and health.capacity==before_capacity+capacity_add and health.current==before_hp,"retained eligible item applies its actual configured effect only after equipment")
		check(GEAR.equip_ids(app.build,[]) and health.capacity==before_capacity and health.current==before_hp,"unequipping the claimed item removes its actual effect without free healing")
	check(not app._claim_modal_item(&"B11") and app.build.count_item(&"B11")==1,"late repeated selection cannot grant the retained item twice")
	app.abandon_run()
	if not await load("res://tests/audio_teardown.gd").drain_world(app):
		failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
	app.free();await frames(2)

func death_cache() -> void:
	var app=await cache_app("coin")
	var coins: int=app.wallet.balance
	var id:=StringName((app.stage as PlainsRegionStage).chests[app._region_chest].id+"/resource/coin")
	check(app._claim_modal_item(id),"fatal batch has a queued chest selection")
	app.policy.set_physics_process(false)
	app._submit_damage(&"cache_fatal",DamageRequest.Kind.MONSTER,100,&"cache_fatal")
	app.policy.resolve_batch()
	check(app.wallet.balance==coins and not app.lifetime.active,"real same damage batch ends run before queued chest coins")
	paused=false;app.abandon_run()
	if not await load("res://tests/audio_teardown.gd").drain_world(app):
		failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
	app.free();await frames(2)
func mini_rays() -> void:
	for source: Vector2 in [Vector2(350,452),Vector2(770,452),Vector2(450,400),Vector2(670,400),Vector2(440,530),Vector2(680,530),Vector2(540,570),Vector2(580,570)]:
		var world:=Node2D.new();root.add_child(world)
		var module:=PlatformingModule.new();module.definition=preload("res://resources/generation/modules/plains_bellstrider_arena.tres");world.add_child(module)
		var player:=preload("res://game/player/player.tscn").instantiate() as PlayerMotor;player.position=source;world.add_child(player)
		var actor:=player.get_node("Controller") as PlayerController;actor.set_physics_process(false);actor.enable_shot_energy()
		var boss:=load("res://scenes/bosses/bellstrider.tscn").instantiate() as BossMotor;boss.position=Vector2(560,535);world.add_child(boss)
		var encounter=boss.get_node("Encounter");encounter.set_physics_process(false);encounter.configure_arena(300,1220,player);encounter.activate();encounter._enter(&"neck",10)
		encounter.physics_tick(.001)
		var life:=DemoLifetime.new();var policy:=FrameDamagePolicy.new();policy.lifetime=life;world.add_child(policy);policy.register_target(&"player",actor.actor_resources.health,true);policy.bind_damageable(&"mini",boss.get_node("Damageable"),encounter.health)
		await frames(2)
		var core: Vector2=encounter.motor.global_position+encounter.core_offset()
		check(encounter.definition.resource_path=="res://resources/bosses/bellstrider.tres" and encounter.health.capacity==40 and encounter.health.capacity==encounter.definition.health_definition.max_health,"mini ray fixture uses the current authoritative forty-HP Boss")
		# Fixed current-contract counterexamples: these original bottom sources
		# start inside the low hull (Boss-local +/-20,35), below the sole bell.
		# Expected routing is declared before observing any hit or HP result.
		var armour_expected := source in [Vector2(540,570),Vector2(580,570)]
		var armour_contacts: Array[Vector2] = []
		var committed: Array[Dictionary] = []
		encounter.armour_hit.connect(func(point: Vector2) -> void: armour_contacts.append(point))
		var primary := boss.get_node("Damageable") as Damageable
		var upper := encounter._core.get_node("Damageable") as Damageable
		check(encounter.weakpoint_only() and upper.can_receive_effects() and not primary.can_receive_effects() and upper.damage_policy_owner()==primary,"current upper bell is the sole spatial damage receiver with the original shared HP owner")
		primary.damaged.connect(func(context: Dictionary) -> void: committed.append(context.duplicate()))
		var ray := PhysicsRayQueryParameters2D.create(player.global_position,core,4,[player.get_rid()])
		ray.collide_with_areas=true
		ray.hit_from_inside=true
		var first: Dictionary=player.get_world_2d().direct_space_state.intersect_ray(ray)
		check(not first.is_empty() and first.collider==(boss if armour_expected else encounter._core),"original source has its declared physical armour/upper-bell first contact "+str(source))
		if armour_expected:
			var point_query:=PhysicsPointQueryParameters2D.new()
			point_query.position=player.global_position
			point_query.collision_mask=4
			point_query.collide_with_areas=false
			var overlaps:=player.get_world_2d().direct_space_state.intersect_point(point_query)
			check(overlaps.any(func(row: Dictionary) -> bool: return row.collider==boss),"bottom source starts inside actual installed armour, not a clear upper-bell route "+str(source))
		var before_hp: float=encounter.health.current
		var shot_damage: float=actor.motor.tuning.projectile_damage
		check(actor.shoot_ability.try_fire((core-player.global_position).normalized(),false),"real projectile launched at open mini core")
		await frames(45)
		if armour_expected:
			check(shot_damage==1.0 and encounter.health.current==before_hp and armour_contacts.size()==1 and committed.is_empty(),"actual bottom projectile is intercepted once by armour with zero HP loss and no damage receipt "+str(source))
			check(armour_contacts[0].is_finite() if armour_contacts.size()==1 else false,"actual armour contact reports a finite physical impact point "+str(source))
		else:
			check(shot_damage==1.0 and encounter.health.current==before_hp-shot_damage,"mini core accepts exactly one real current projectile from "+str(source))
			check(committed.size()==1 and armour_contacts.is_empty(),"clear upper-bell route commits once through the primary without an armour hit "+str(source))
			if committed.size()==1:
				check(committed[0].damage_type==&"projectile" and committed[0].source_actor_id==player.get_instance_id() and is_equal_approx(float(committed[0].amount),shot_damage),"upper-bell HP receipt belongs to the actual player's unchanged projectile "+str(source))
		check(actor.shoot_ability.get_projectiles().is_empty(),"actual collided projectile is consumed instead of silently flying past "+str(source))
		world.free()
	# Names use actual definition, including in the development encounter.
	var lab=load("res://experiments/generation/module_lab.gd").new();root.add_child(lab);lab.request_module(&"bellstrider_trial");await frames(7)
	check(lab.module.definition.module_id==&"plains_bellstrider_arena","mini practice consumes its independent arena")
	var intro=lab.boss_trial.encounter;intro.activate()
	var hud: Array[Node]=lab.boss_trial.find_children("*","WindkeeperHud",true,false)
	check(hud.size()==1,"mini practice has readable named intro HUD")
	if not hud.is_empty():
		hud[0]._process(.5)
		check(hud[0]._intro_name.text.contains("BELLSTRIDER") and hud[0]._intro_name.visible,"intro shows mini's own name")
	lab.free();await frames(2)
func enemy_behaviors() -> void:
	for id: String in ["fan_sentry","hopper"]:
		var world:=Node2D.new();root.add_child(world)
		var floor_body:=StaticBody2D.new();var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(1000,32);shape.shape=rect;floor_body.position=Vector2(300,618);floor_body.add_child(shape);world.add_child(floor_body)
		var player:=preload("res://game/player/player.tscn").instantiate() as PlayerMotor;player.position=Vector2(350,582);world.add_child(player)
		var actor:=player.get_node("Controller") as PlayerController;actor.set_physics_process(false)
		var enemy:=preload("res://game/enemies/scenes/patrol_drone.tscn").instantiate() as EnemyMotor
		(enemy.get_node("Actor") as EnemyActor).definition=PlainsEncounterPlanner.definition_for_behavior(id);enemy.position=Vector2(200,470 if id=="fan_sentry" else 582);world.add_child(enemy)
		var owner:=enemy.get_node("Actor") as EnemyActor;owner.set_physics_process(false)
		var life:=DemoLifetime.new();var policy:=FrameDamagePolicy.new();policy.lifetime=life;world.add_child(policy);policy.register_target(&"player",actor.actor_resources.health,true)
		owner.bind_encounter(actor,policy,life,StringName(id),[]);var behavior:=owner.attack_behavior;behavior.cooldown=0
		await frames(2);behavior.advance(.01);check(behavior.state==&"telegraph","new behavior warns before pressure: "+id)
		var locked:=behavior.locked_direction
		behavior.advance(owner.definition.telegraph_duration+.01)
		if id=="fan_sentry":
			check(behavior._projectiles.size()==3,"fan sentry fires three independent real projectiles")
			check(is_equal_approx(behavior._projectiles[0].direction.angle_to(locked),.18) and behavior._projectiles[1].direction==locked,"spread follows frozen telegraph aim")
		else:
			behavior.advance(owner.definition.attack_duration*.5)
			check(enemy.position.y<500 and enemy.position.x>200,"hopper moves through collision into a genuine airborne landing arc")
			behavior.advance(owner.definition.attack_duration*.5)
			check(enemy.position.y>570,"hopper lands rather than floating permanently")
		behavior.cancel();check(behavior._projectiles.is_empty() and behavior.state==&"recovery","cancelled attacks retain recovery and dispose shots")
		world.free();await frames(2)

func formal_consumers() -> void:
	var seen: Dictionary={};var hopper_checked:=false;var fan_checked:=false
	for i: int in 12:
		var app=load("res://game/application/demo_app.gd").new();app.meta_persistence_enabled=false;root.add_child(app);app.start_plains("formal-consumer/%s" % i);await frames(5)
		app.set_physics_process(false);app.controller.set_physics_process(false)
		for contact: DemoContactEmitter in app._enemy_contacts: contact.enabled=false
		for enemy: EnemyMotor in app.stage.enemies: (enemy.get_node("Actor") as EnemyActor).set_physics_process(false)
		var health: HealthState=app.controller.actor_resources.health
		health.apply_damage(ActorResourceRequest.new(&"resource_preview_fixture",health.epoch,2,health.get_instance_id()))
		for chest: Dictionary in (app.stage as PlainsRegionStage).chests:
			if chest.tier not in ["high","region_top"]: continue
			app.player.position=chest.position;app._region_interact()
			check(app.reward_modal.opened,"actual generated high/top cache opens normal presentation")
			if app._region_offer!=null:
				for option: ItemDefinition in app._region_offer.candidates:
					if option is ResourceRewardChoice:
						seen[(option as ResourceRewardChoice).resource_kind]=true
						check(option.rarity==ItemDefinition.Rarity.PURPLE if chest.tier=="high" else option.rarity==ItemDefinition.Rarity.GOLD,"actual resource card uses its challenge tier")
			app.reward_modal.close();paused=false;app._region_chest=-1
		for enemy: EnemyMotor in app.stage.enemies:
			var actor:=enemy.get_node("Actor") as EnemyActor
			if actor.definition.behavior_id==&"fan_sentry":
				fan_checked=true;check(actor.definition.aerial and actor.definition.activation_range==330,"formal generated ferry side-fire consumes actual fan definition")
			if hopper_checked or actor.definition.behavior_id!=&"hopper": continue
			var behavior:=actor.attack_behavior
			app.player.position=behavior.home+Vector2(60,-80)
			await frames(2);behavior.cooldown=0;behavior.advance(.01)
			check(actor.definition.patrol_half_width==35 and behavior.state==&"telegraph","actual generated hopper retains nonzero movement radius and warns")
			var target: Vector2=behavior.attack_goal;var origin: Vector2=enemy.position
			check(is_equal_approx(target.y,behavior.home.y),"formal hopper preview points to actual floor landing")
			behavior.advance(actor.definition.telegraph_duration+.01);behavior.advance(actor.definition.attack_duration*.5)
			check(behavior.attack_goal==target and enemy.position.y<origin.y-60 and absf(enemy.position.x-origin.x)>5,"formal generated hopper follows its frozen preview through a real moving arc")
			behavior.advance(actor.definition.attack_duration*.5)
			check(enemy.position.distance_to(target)<3,"formal hopper reaches advertised landing through collision")
			hopper_checked=true
		app.abandon_run()
		if not await load("res://tests/audio_teardown.gd").drain_world(app):
			failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
		app.free();await frames(2)
	check(seen.has("coin") and seen.has("heart") and seen.has("note"),"normal generated high/top cards actually offer all three resource categories")
	check(hopper_checked and fan_checked,"new enemy roles exist in formal randomized instances")
	var proof:=FileAccess.open("res://build/verification/generated/plains_cohesion/formal_consumers.json",FileAccess.WRITE);proof.store_string(JSON.stringify({"seeds":12,"resources":seen.keys(),"hopper_checked":hopper_checked,"fan_checked":fan_checked},"  ",true));proof.close()
