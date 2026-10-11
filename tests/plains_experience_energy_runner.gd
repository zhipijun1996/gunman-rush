extends SceneTree
## Fixture placement only; damage, projectiles, refunds and locomotion are real.
var assertions:=0
var failures:=0
var world: Node2D
var player: PlayerMotor
var actor: PlayerController
var life: DemoLifetime
var policy: FrameDamagePolicy
var target: StaticBody2D
var receiver: Damageable
var target_health: HealthState
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func frames(n: int) -> void:
	for i: int in n: await physics_frame
func fixture(automatic: bool=false) -> void:
	if is_instance_valid(world): world.free()
	world=Node2D.new();root.add_child(world)
	player=preload("res://scenes/player/player.tscn").instantiate();player.position=Vector2(200,100);world.add_child(player)
	actor=player.get_node("Controller");actor.set_physics_process(automatic)
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	check(actor.enable_shot_energy(),"formal shot policy configures")
	life=DemoLifetime.new();policy=FrameDamagePolicy.new();policy.lifetime=life;world.add_child(policy)
	policy.register_target(&"player",actor.actor_resources.health,true)
	target=StaticBody2D.new();target.position=Vector2(200,550);target.collision_layer=4;world.add_child(target)
	var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=40;shape.shape=circle;target.add_child(shape)
	receiver=Damageable.new();receiver.name="Damageable";receiver.actor_id=target.get_instance_id();target.add_child(receiver)
	target_health=HealthState.new();var def:=HealthDefinition.new();def.resource_id=&"energy_target";def.max_health=100;def.initial_current=100;target_health.configure(def);receiver.bind_health(target_health)
	policy.bind_damageable(&"target",receiver,target_health)
	await frames(2)
func shot() -> bool:
	actor.shoot_ability.advance(1)
	return actor.shoot_ability.try_fire(target.position-player.position,false)
func request(id: StringName,target_id: StringName,amount: float,callback: Callable=Callable()) -> DamageRequest:
	var r:=DamageRequest.new();r.token=life.token();r.actor_epoch=life.actor_epoch;r.event_id=id;r.source_id=id;r.target_id=target_id;r.amount=amount
	r.health_epoch=actor.actor_resources.health.epoch if target_id==&"player" else target_health.epoch;r.on_committed=callback;return r
func run() -> void:
	await fixture()
	check(shot(),"air shot allowed")
	check(actor.actor_resources.stamina.current==80 and actor.action_resources.shot_charges==1,"shot spends exactly twenty energy and one air round")
	await frames(35)
	check(target_health.current==99 and actor.actor_resources.stamina.current==100,"swept projectile commits real target damage then refunds twenty")
	check(actor.received_resource_grants.size()==1,"committed airborne hit queues exactly one round")
	actor.physics_tick(1.0/60)
	check(actor.action_resources.shot_charges==2,"next real actor frame applies hit round within unchanged cap")
	actor.on_projectile_hit(actor.session_id,1,true)
	check(actor.received_resource_grants.is_empty(),"repeated hit callback never duplicates refund")
	await fixture()
	target.remove_child(receiver);receiver.free()
	check(shot(),"geometry blocker receives real swept shot")
	await frames(35)
	check(actor.actor_resources.stamina.current==80 and actor.received_resource_grants.is_empty() and actor.shoot_ability.get_projectiles().is_empty(),"wall contact grants neither energy nor an air round")
	await fixture()
	target.free()
	var armour_boss:=load("res://scenes/bosses/bellstrider.tscn").instantiate() as BossMotor
	armour_boss.position=Vector2(200,550);world.add_child(armour_boss)
	var encounter:=armour_boss.get_node("Encounter") as BellstriderEncounter
	encounter.configure_arena(0,800,player);encounter.activate();encounter._enter(&"observe",5);encounter.set_physics_process(false)
	var armour_contacts: Array[int]=[0]
	encounter.armour_hit.connect(func(_point: Vector2): armour_contacts[0]+=1)
	policy.bind_damageable(&"armoured_boss",armour_boss.get_node("Damageable"),encounter.health)
	check(actor.shoot_ability.try_fire(Vector2.DOWN,false),"actual shot travels to closed mini armour")
	await frames(35)
	check(armour_contacts[0]>0 and encounter.health.current==16 and actor.actor_resources.stamina.current==80 and actor.received_resource_grants.is_empty(),"actual closed Boss armour never refunds energy or a round")
	await fixture()
	check(shot(),"miss fixture first shot")
	actor.shoot_ability.clear_projectiles()
	check(shot(),"miss fixture second shot")
	actor.shoot_ability.clear_projectiles()
	check(not shot() and actor.actor_resources.stamina.current==60,"two misses exhaust air rounds without refund")
	var jumps:=actor.jump_ability.used_jumps
	actor.shot_energy.advance(2,false)
	check(actor.actor_resources.stamina.current==60,"no passive airborne energy recovery")
	actor.shot_energy.advance(.5,true)
	check(is_equal_approx(actor.actor_resources.stamina.current,75),"after air delay elapsed, grounded recovery uses game delta only")
	check(actor.jump_ability.used_jumps==jumps and player.tuning.max_jumps==1,"energy never gives a jump")
	await fixture()
	for i: int in 5:
		actor.shoot_ability.advance(1)
		check(actor.shoot_ability.try_fire(Vector2.UP,true),"ground shot spends finite energy")
		actor.shoot_ability.clear_projectiles()
	actor.shoot_ability.advance(1)
	var serial:=actor.shoot_ability._shot_serial
	var velocity:=player.velocity
	check(not actor.shoot_ability.try_fire(Vector2.UP,true),"empty energy rejects a shot")
	check(actor.shoot_ability._shot_serial==serial and actor.shoot_ability.cooldown_remaining==0 and player.velocity==velocity,"rejection changes no serial, cooldown or recoil")
	actor.shot_energy.advance(.2,true);check(actor.actor_resources.stamina.current==0,"recovery delay prevents immediate regeneration")
	actor.shot_energy.advance(.25,true);check(is_equal_approx(actor.actor_resources.stamina.current,3),"only delta after remaining delay regenerates")
	actor.air_focus_ability.reset();check(is_equal_approx(actor.actor_resources.stamina.current,3),"focus reset cannot refill shot energy")
	paused=true
	actor.physics_tick(.5)
	check(is_equal_approx(actor.actor_resources.stamina.current,3),"paused actor never regenerates")
	paused=false
	await fixture()
	check(shot(),"fatal frame starts with a spent shot")
	actor.shoot_ability.clear_projectiles()
	policy.set_physics_process(false)
	var cb:=actor.on_projectile_hit.bind(actor.session_id,1,true)
	check(policy.submit(request(&"target_hit",&"target",1,cb)),"target damage queues")
	check(policy.submit(request(&"fatal",&"player",100)),"player fatal damage queues in same batch")
	policy.resolve_batch()
	check(target_health.current==99 and actor.actor_resources.health.terminal and actor.actor_resources.stamina.current==80 and actor.received_resource_grants.is_empty(),"death priority cancels hit refund even after target HP commit")
	await fixture()
	check(shot(),"selection fixture spends energy")
	actor.shoot_ability.clear_projectiles();policy.set_physics_process(false)
	check(policy.submit(request(&"weak",&"target",1,actor.on_projectile_hit.bind(actor.session_id,1,true))),"weak callback submitted")
	check(policy.submit(request(&"strong",&"target",2)),"strong hit submitted")
	policy.resolve_batch()
	check(target_health.current==98 and actor.actor_resources.stamina.current==80,"unselected hit cannot refund")
	var old_session:=actor.session_id
	actor.return_to_segment(player.position)
	actor.on_projectile_hit(old_session,1,true)
	check(actor.actor_resources.stamina.current==80 and actor.received_resource_grants.is_empty(),"old actor epoch cannot refund after segment return")
	await fixture()
	var build:=BuildState.new();build.configure(actor)
	var grip:=preload("res://resources/items/efficient_grip.tres")
	check(build.add_item(&"grip",grip) and is_equal_approx(actor.shot_energy.shot_energy_cost,16),"grip actually reduces energy cost from base")
	check(build.add_item(&"grip",grip) and is_equal_approx(actor.shot_energy.shot_energy_cost,16),"same source is idempotent")
	check(build.remove_source(&"grip") and actor.shot_energy.shot_energy_cost==20,"removing source restores base cost")
	check(build.add_item(&"echo",preload("res://resources/items/echo_magazine.tres")) and actor.shot_energy.hit_energy_recovery==25,"echo item actually increases committed-hit recovery")
	check(build.add_item(&"hp",preload("res://resources/items/region_health_purple.tres")) and actor.actor_resources.health.capacity==6.5 and actor.actor_resources.health.current==5,"HP item changes capacity without fake healing")
	check(player.tuning.max_jumps==1 and player.tuning.max_air_shots==2,"new energy items preserve baseline action caps")
	var menu:=DemoMenu.new();world.add_child(menu)
	menu.show_pause("Fixture build",build.owned_items());menu.show_build("Fixture build");menu._back();menu.show_build("Fixture build")
	check(menu._build_items.size()==2,"back and reopen keeps owned item cards")
	var shop:=ItemShopModal.new();world.add_child(shop)
	var offer:=ShopOffer.new();offer.item=grip;offer.price=10;offer.stock=1
	shop.show_offer(offer,0,true);check(shop.opened,"shop previews real icon and item")
	var buttons:=shop.find_children("*","Button",true,false)
	check(buttons.size()==2 and buttons[0].disabled,"insufficient coins disable purchase before mutation")
	shop.close();check(not shop.opened,"preview closes safely")
	var toast:=ItemAcquiredToast.new();world.add_child(toast);toast.show_item(grip);check(is_instance_valid(toast._root),"actual acquisition UI renders");toast.clear()
	var broken:=ItemDefinition.new();broken.stable_id=&"overcost";broken.display_name="Invalid overcost"
	var mod:=BuildModifier.new();mod.stat_id=&"shot_energy_cost";mod.operation=BuildModifier.Operation.ADD;mod.value=200;broken.modifiers=[mod]
	check(not build.can_add(broken),"invalid cost above energy capacity cannot soft-lock shooting")
	var supported:=preload("res://assets/fonts/windkeeper_ui.ttf").get_supported_chars()
	var dir:=DirAccess.open("res://resources/items")
	for file: String in dir.get_files():
		if not file.ends_with(".tres"): continue
		var item:=load("res://resources/items/"+file) as ItemDefinition
		check(item!=null and item.is_valid() and not item.description.is_empty() and ItemPresentation.icon(item.icon_key)!=null,"item valid icon, explanation, effects: "+file)
		var covered:=true
		for c: String in item.display_name+item.description+ItemPresentation.effects(item):
			if c.unicode_at(0)>=128 and not supported.contains(c): covered=false
		check(covered,"actual subset covers all Chinese card glyphs: "+file)
		check(not ItemPresentation.effects(item).contains("max_") and not ItemPresentation.effects(item).is_empty(),"effect text shows player meaning: "+file)
	var generator:=PlainsRegionGenerator.new();var pair_set: Dictionary={}
	for i: int in 30:
		var result:=generator.generate("energy-items-%s" % i,PlayerTuning.load_default())
		check(result.ok,"new item stream generates")
		if not result.ok: continue
		for reward: Dictionary in result.manifest.rewards:
			var items: Array=reward.items
			check(items.size()==2 and items[0]!=items[1],"choice has two distinct actual items")
			pair_set[JSON.stringify(items)]=true
			for id: String in items:
				var item:=load("res://resources/items/"+id+".tres") as ItemDefinition
				check(item!=null and item.is_valid() and id!="jump_blue","formal pool excludes big ability and resolves real items")
	check(pair_set.size()>=8,"independent item stream changes meaningful choice combinations")
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_plains("energy-formal-preview"),"default formal consumer starts with new resource")
	await frames(4)
	check(app.controller.shot_energy!=null and app.controller.actor_resources.stamina.current<=100,"actual App owns formal energy")
	# Explicit shop interaction fixture, not a claim of GUI exploration.
	app.player.position=(app.stage as PlainsRegionStage).merchant_position
	var coins_before:=app.wallet.balance
	app._open_region_shop()
	check(app.shop_modal.opened and app.wallet.balance==coins_before,"formal shop preview never spends coins")
	app.toggle_pause();check(app.shop_modal.opened and app.menu.visible_panel.is_empty(),"shop blocks a second pause overlay")
	app._close_region_shop();check(not paused and app.wallet.balance==coins_before,"closing formal preview resumes without purchase")
	app.abandon_run();app.free()
	var lab:=ModuleLab.new();root.add_child(lab);lab.request_module(&"energy_trial");await frames(8)
	check(lab.module_id==&"energy_trial" and lab.controller.shot_energy!=null and is_instance_valid(lab.energy_trial),"explicit development practice uses real shot economy")
	lab.energy_trial.show_choice();check(paused and lab.energy_trial.modal.opened,"real practice reward opens shared item cards")
	lab.energy_trial._choose(&"efficient_grip")
	check(not paused and lab.energy_trial.claimed and lab.controller.shot_energy.shot_energy_cost==16,"shared reward service commits actual displayed item effect")
	lab.energy_trial._choose(&"efficient_grip")
	check(lab.controller.shot_energy.shot_energy_cost==16,"duplicate practice claim never reapplies effect")
	lab.restart_module();await frames(8)
	check(lab.controller.shot_energy.shot_energy_cost==20 and lab.energy_trial.build.item_ids().is_empty(),"new practice attempt discards local fixture reward")
	lab.free()
	# Continuous locomotion: no resetting rounds, energy or position between shots.
	await fixture(true)
	var hit_count:=0
	var continuous_samples: Array=[]
	for i: int in 8:
		check(not player.is_on_floor(),"continuous hit loop stays airborne before shot")
		actor.router.request_action(&"shoot_release",target.position-player.position)
		var before:=target_health.current
		for tick: int in 100:
			await frames(1)
			if target_health.current<before: break
		if target_health.current<before: hit_count+=1
		else: break
		await frames(2)
		continuous_samples.append({"hit":hit_count,"position":[player.position.x,player.position.y],"energy":actor.actor_resources.stamina.current,"rounds":actor.action_resources.shot_charges,"grounded":player.is_on_floor()})
	var proof:=FileAccess.open("res://docs/evidence/plains_experience_energy/air_hit_loop.json",FileAccess.WRITE)
	proof.store_string(JSON.stringify({"fixture":"real projectiles/damage/input/locomotion; initial placement only","samples":continuous_samples},"\t")+"\n")
	proof.close()
	check(hit_count==8 and target_health.current==92,"eight real midair hits sustain beyond baseline two shots")
	check(player.tuning.max_jumps==1 and player.tuning.max_air_shots==2,"sustained recoil uses hit-return economy, not expanded caps")
	world.free()
	print("PLAINS EXPERIENCE ENERGY: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)
