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
	if is_instance_valid(app):
		if not await load("res://tests/audio_teardown.gd").drain_world(app):
			failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
		app.free()
	paused=false
	app=DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	check(app.start_plains(seed_value),"actual formal consumer starts")
	await frames(8)
func inventory_state() -> Dictionary:
	var result: Dictionary={}
	for owned: RunItemInstance in app.build.inventory.instances():
		result[String(owned.instance_id)]={"definition_id":String(owned.definition_id),"level":owned.level,"source_id":String(owned.source_id)}
	return result
func buy_v5_slot(funding: StringName) -> Dictionary:
	app._open_region_shop()
	var presenter:=app._v5_shop_presenter
	check(presenter.is_open() and app.shop_modal.opened and paused,"actual formal merchant opens its V5 catalog")
	if not presenter.is_open(): return {}
	var shop_id: StringName=presenter._shop_id
	var map_key: StringName=app._item_runtime.map_key()
	var snapshot: Dictionary=app.shop.catalog_shop_snapshot(shop_id,map_key)
	check(snapshot.get("offers",[]).size()==3,"formal V5 merchant has three finite catalog slots")
	var quote: ShopOffer
	for row: Dictionary in snapshot.get("offers",[]):
		var candidate: ShopOffer=app.shop.quote(StringName(row.offer_id))
		if candidate!=null and candidate.stock==1 and ItemV5Eligibility.offer_reason(candidate.item,app.build,true).is_empty(): quote=candidate;break
	check(quote!=null,"original catalog contains an eligible slot after cache ownership")
	if quote==null: app._close_region_shop();return {}
	# Explicit fixture income follows the actual quote, never an old fixed price.
	check(app.wallet.grant(quote.price,funding),"quoted-price fixture income uses the real run-wallet ledger")
	presenter.refresh()
	var buy:=app.shop_modal.find_child("CatalogBuy_"+String(quote.offer_id).validate_node_name(),true,false) as Button
	check(buy!=null and not buy.disabled,"real quoted slot exposes an affordable V5 purchase control")
	if buy==null or buy.disabled: app._close_region_shop();return {}
	var before_balance: int=app.wallet.balance
	var before_build: Array[StringName]=app.build.item_ids()
	var before_owned: RunItemInstance=app.build.inventory.instance_for_definition(quote.item.stable_id)
	var before_level: int=before_owned.level if before_owned!=null else 0
	var before_count: int=app.build.inventory.instances().size()
	var receipts: Array[EconomyReceipt]=[]
	var observe: Callable=func(receipt: EconomyReceipt) -> void: receipts.append(receipt)
	app.shop.purchased.connect(observe)
	# Original presenter constructs ShopPurchaseRequest from this immutable slot.
	buy.pressed.emit()
	app.shop.purchased.disconnect(observe)
	check(receipts.size()==1 and receipts[0].accepted(),"actual merchant purchase succeeds")
	if receipts.is_empty(): app._close_region_shop();return {}
	var receipt: EconomyReceipt=receipts[0]
	var owned: RunItemInstance=app.build.inventory.get_instance(receipt.instance_id)
	check(app.wallet.balance==before_balance-quote.price and receipt.coins==-quote.price,"original wallet debits the exact slot quote once")
	check(owned!=null and owned.definition_id==quote.item.stable_id and owned.level==before_level+1 and app.build.inventory.instances().size()==before_count+(1 if before_owned==null else 0),"V5 purchase commits backpack ownership or same-instance growth")
	check(app.build.item_ids()==before_build,"merchant acquisition never automatically equips the item")
	var after_balance: int=app.wallet.balance
	buy.pressed.emit()
	check(app.wallet.balance==after_balance and app.shop.quote(quote.offer_id).stock==0,"finite stock cannot be refreshed by another interaction")
	check(app.shop.get_receipt(receipt.event_id)!=null and app.shop.get_receipt(receipt.event_id).instance_id==receipt.instance_id,"original purchase receipt binds the stable backpack instance")
	var after: Dictionary=app.shop.catalog_shop_snapshot(shop_id,map_key)
	check(after.offers.all(func(row: Dictionary) -> bool: return int(row.stock)==(0 if StringName(row.offer_id)==quote.offer_id else 1)),"only the purchased slot is exhausted; other original slots remain unchanged")
	app._close_region_shop()
	return {"shop_id":shop_id,"map_key":map_key,"offer_id":quote.offer_id,"receipt_id":receipt.event_id,"instance_id":receipt.instance_id,"snapshot":after}

func run() -> void:
	await fixture("region-lifecycle")
	var rs:=app.stage as PlainsRegionStage
	var hash_value: String=rs.generated.manifest.manifest_hash
	# Explicit consumer fixtures position the actor; itinerary proof is separate.
	var cache_index: int=0
	for i: int in rs.chests.size():
		if rs.chests[i].tier=="medium": cache_index=i;break
	var cache: Dictionary=rs.chests[cache_index]
	cache.reward_mode="item_resource" # Explicit item-path ledger fixture; resources tested separately.
	app.player.reset_at(cache.position)
	await frames(2)
	app._commit_interact()
	check(app.reward_modal.opened and paused,"real position cache opens item choice")
	var choice: StringName=app._region_offer.candidates[0].stable_id
	var before_coins:=app.wallet.balance
	check(app._claim_modal_item(choice),"cache accepts one legal choice")
	await frames(3) # Damage batch owns the commit; click is only a queued intent.
	var coins:=app.wallet.balance
	check(coins==before_coins+int(cache.coins) and app.build.count_item(choice)==1 and cache.claimed,"medium challenge pays item plus fixed substantial coins")
	check(not app._claim_modal_item(choice),"repeat cache claim rejected")
	var old_jump:=app.controller.motor.tuning.max_jumps
	var old_shots:=app.controller.motor.tuning.max_air_shots
	app.player.reset_at(rs.merchant_position)
	await frames(2)
	var purchase: Dictionary=buy_v5_slot(&"explicit_merchant_fixture")
	if purchase.is_empty():
		app.abandon_run();check(await load("res://tests/audio_teardown.gd").drain_world(app),"failed catalog fixture drains audio");app.free();quit(1);return
	var quote:=app.shop.quote(StringName(purchase.offer_id))
	check(quote!=null and quote.stock==0,"real shop ledger has exhausted stock")
	var inventory_before:=inventory_state()
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
	var wallet_before: int=app.wallet.balance
	var grants_before: Dictionary=app.wallet._grants.duplicate(true)
	app.region_state=restored
	app._load_stage()
	await frames(8)
	rs=app.stage as PlainsRegionStage
	check(rs.generated.manifest.manifest_hash==hash_value and rs.chests[cache_index].claimed,"reload does not reroll map/reward or reopen claimed cache")
	check(rs.assembler.modules[0].clock>old_clock,"reload retains module clock")
	check(app.shop.quote(StringName(purchase.offer_id)).stock==0 and app.shop.catalog_shop_snapshot(StringName(purchase.shop_id),StringName(purchase.map_key))==purchase.snapshot,"reload does not refresh merchant stock")
	check(inventory_state()==inventory_before and app.shop.get_receipt(StringName(purchase.receipt_id))!=null and app.shop.get_receipt(StringName(purchase.receipt_id)).instance_id==purchase.instance_id,"reload retains actual backpack instances, levels and committed purchase receipt")
	check(app.wallet.balance==wallet_before and app.wallet._grants==grants_before,"reload preserves the actual run-wallet balance and grant ledger")
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
	if not await load("res://tests/audio_teardown.gd").drain_world(app):
		failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
	app.free()
	await process_frame
	print("REGION LIFECYCLE: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)
