extends SceneTree
var assertions:=0
var failures:=0
var app: DemoApp
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok:
		failures+=1
		printerr("FAIL: "+message)
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i: int in n: await physics_frame
func fixture(seed_value: String) -> void:
	if is_instance_valid(app): app.free()
	paused=false
	app=DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	check(app.start_plains(seed_value),"actual formal consumer starts")
	await frames(8)
func run() -> void:
	await fixture("region-lifecycle")
	var rs:=app.stage as PlainsRegionStage
	var hash_value: String=rs.generated.manifest.manifest_hash
	# Explicit consumer fixtures position the actor; itinerary proof is separate.
	app.player.reset_at(rs.chests[0].position)
	await frames(2)
	app._commit_interact()
	check(app.reward_modal.opened and paused,"real position cache opens item choice")
	var choice: StringName=app._region_offer.candidates[0].stable_id
	check(app._claim_modal_item(choice),"cache accepts one legal choice")
	var coins:=app.wallet.balance
	check(coins>=8 and rs.chests[0].claimed,"medium challenge pays item plus fixed substantial coins")
	check(not app._claim_modal_item(choice),"repeat cache claim rejected")
	var old_jump:=app.controller.motor.tuning.max_jumps
	var old_shots:=app.controller.motor.tuning.max_air_shots
	app.wallet.grant(10,&"explicit_merchant_fixture")
	app.player.reset_at(rs.merchant_position)
	await frames(2)
	check(app._region_purchase(),"actual merchant purchase succeeds")
	check(not app._region_purchase(),"finite stock cannot be refreshed by another interaction")
	var quote:=app.shop.quote(app._region_shop_id())
	check(quote.stock==0,"real shop ledger has exhausted stock")
	var enemy:=rs.enemies[0].get_node("Actor") as EnemyActor
	enemy.health.apply_damage(ActorResourceRequest.new(&"enemy_fixture",enemy.health.epoch,enemy.health.current,enemy.health.get_instance_id()))
	app._settle_enemy_drops()
	var drop_count:=rs.pickups.filter(func(p: Dictionary): return p.has("source")).size()
	app._settle_enemy_drops()
	check(rs.pickups.filter(func(p: Dictionary): return p.has("source")).size()==drop_count,"dead enemy settles only one recorded drop")
	# Open from wrong side is refused; real upper-side control persists.
	var shortcut: Dictionary={}
	for e: Dictionary in rs.generated.manifest.connections:
		if e.condition=="backside": shortcut=e; break
	var control:=Vector2(shortcut.control[0],shortcut.control[1])
	check(not (rs.assembler as PlainsRegionAssembler).open_shortcut(shortcut.id,control+Vector2(0,400)),"shortcut refuses lower-side opening")
	check((rs.assembler as PlainsRegionAssembler).open_shortcut(shortcut.id,control),"upper-side shortcut opens real collision")
	await frames(2)
	var old_clock:=rs.assembler.modules[0].clock
	rs.capture_state()
	var data: Dictionary=JSON.parse_string(JSON.stringify(app.region_state.snapshot()))
	var restored:=PlainsRegionState.new()
	check(restored.restore(data,hash_value),"JSON instance snapshot accepted for same map")
	check(not PlainsRegionState.new().restore(data,"another-map"),"snapshot rejected for another map")
	# Real production stage unload/rebuild, preserving services and region ledger.
	app.region_state=restored
	app._load_stage()
	await frames(8)
	rs=app.stage as PlainsRegionStage
	check(rs.generated.manifest.manifest_hash==hash_value and rs.chests[0].claimed,"reload does not reroll map/reward or reopen claimed cache")
	check(rs.assembler.modules[0].clock>old_clock,"reload retains module clock")
	check(app.shop.quote(app._region_shop_id()).stock==0,"reload does not refresh merchant stock")
	check((rs.enemies[0].get_node("Actor") as EnemyActor).health.terminal,"reload does not revive dead enemy")
	check(rs.pickups.filter(func(p: Dictionary): return p.has("source")).size()==drop_count,"reload restores drop without duplication")
	check((rs.assembler as PlainsRegionAssembler).shortcut_shapes[shortcut.id].disabled,"reload keeps actual shortcut open")
	check(app.controller.motor.tuning.max_jumps==old_jump and app.controller.motor.tuning.max_air_shots==old_shots,"rewards/reloads do not secretly increase action resources")
	# Death wins a real same-frame Boss/reward/interaction batch.
	app.abandon_run()
	await frames(4)
	await fixture("region-fatal")
	rs=app.stage as PlainsRegionStage
	app.player.reset_at(rs.boss_arena.position+Vector2(540,202))
	await frames(50)
	var boss:=rs.boss.get_node("Encounter") as WindkeeperEncounter
	check(app._boss_started,"Boss can be activated in first region without old seven-room progression")
	var health:=app.controller.actor_resources.health
	for pair: Array in [[&"boss",boss.health],[&"player",health]]:
		var h: HealthState=pair[1]
		var request:=DamageRequest.new()
		request.token=app.lifetime.token()
		request.actor_epoch=app.lifetime.actor_epoch
		request.health_epoch=h.epoch
		request.source_id=&"explicit_same_frame_fixture"
		request.target_id=pair[0]
		request.event_id=StringName("same_frame/"+String(pair[0]))
		request.amount=h.current
		check(app.policy.submit(request),"simultaneous lethal fixture is accepted by real policy")
	await frames(8)
	check(app.director.state==DemoRunDirector.State.HOME and app.meta.snapshot().completed_biomes==0,"death wins Boss reward and region completion in same frame")
	check(app.current_reward==null,"fatal Boss tie produces no reward")
	check(app.director.stage_index==1 and not app.director.manifest.snapshot().stages[0].outputs.has("mini_boss_reward"),"mini Boss death tie cannot pay or enter map 2")
	app.free()
	await process_frame
	print("REGION LIFECYCLE: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)
