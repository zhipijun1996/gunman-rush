extends SceneTree
## Actual App departures/transitions/transactions. Positioning and quoted-price
## funding are explicit fixtures; this does not claim natural combat completion.
const AUDIO := preload("res://tests/audio_teardown.gd")
const GEAR := preload("res://tests/gear_inventory_support.gd")
var assertions := 0
var failures := 0
var app: DemoApp

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func frames(count: int) -> void:
	for _index: int in count: await physics_frame

func ready_stage() -> bool:
	for _index: int in 90:
		await physics_frame
		if is_instance_valid(app.stage) and not app._stage_pending and is_instance_valid(app.policy): return true
	return false

func owned_services() -> Dictionary:
	return {"player_id":app.player.get_instance_id(), "controller_id":app.controller.get_instance_id(), "health":app.controller.actor_resources.health,
		"build":app.build,"inventory":app.build.inventory,"equipment":app.build.equipment,"wallet":app.wallet,"rewards":app.rewards,"shop":app.shop}

func check_same_services(before: Dictionary, label: String) -> void:
	check(app.player.get_instance_id()==before.player_id and app.controller.get_instance_id()==before.controller_id and app.controller.actor_resources.health==before.health, label+": same live player/controller/health")
	check(app.build==before.build and app.build.inventory==before.inventory and app.build.equipment==before.equipment, label+": same build/inventory/equipment")
	check(app.wallet==before.wallet and app.rewards==before.rewards and app.shop==before.shop, label+": same economy and transaction owners")

func clear_run(label: String) -> void:
	var player_ref: WeakRef = weakref(app.player)
	var stage_ref: WeakRef = weakref(app.stage)
	var policy_ref: WeakRef = weakref(app.policy)
	var old_wallet := app.wallet
	var old_build := app.build
	var old_token := app.lifetime.token()
	app.abandon_run()
	await frames(8)
	check(app.director.state==DemoRunDirector.State.HOME and not app.lifetime.active and not app.lifetime.accepts(old_token), label+": Home rejects ended-run token")
	check(app.player==null and app.controller==null and app.stage==null and app.policy==null and app.segment==null, label+": App releases live scene references")
	check(player_ref.get_ref()==null and stage_ref.get_ref()==null and policy_ref.get_ref()==null, label+": old scene nodes are freed")
	check(app.wallet==old_wallet and old_wallet.balance==0 and app.build==old_build and old_build.inventory.instances().is_empty() and old_build.item_ids().is_empty(), label+": cleared wallet and inventory remain observable")

func flow_reentry_boundary() -> void:
	var owner := DemoRunDirector.new()
	check(owner.start("completion-owner-reentry").accepted(), "flow reentry fixture starts through original flow")
	check(owner.complete_stage(owner.lifetime.token()), "flow reentry fixture completes through original owner")
	var manifest_before := owner.manifest.canonical_json()
	var token := owner.lifetime.token()
	var receipts := owner._receipts.duplicate(true)
	var stage_index := owner.stage_index
	var state := owner.state
	owner.prepare_terminal_stage_reentry()
	check(not owner.stage_complete and owner.state==state and owner.stage_index==stage_index, "terminal reentry operation only reopens the completion flag")
	check(owner.lifetime.accepts(token) and owner.manifest.canonical_json()==manifest_before and owner._receipts==receipts, "terminal reentry does not advance epochs or rewrite Manifest/flow receipts")
	check(owner.complete_stage(token) and owner.stage_complete, "original completion owner can recompute the reopened stage")

func run() -> void:
	flow_reentry_boundary()
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(2)
	var flow := app.director
	var lifetime := app.lifetime
	check(flow.state==DemoRunDirector.State.HOME and not lifetime.active and app.player==null, "Home has no active run or run player")
	check(not app.start_demo(""), "empty departure is rejected before creating services")
	check(app.start_demo("session-boundary-fixed"), "first real fixed departure accepted")
	if not await ready_stage():
		check(false,"fixed departure assembles within bounded wait")
		await finish()
		return
	var first := owned_services()
	var first_token := lifetime.token()
	var first_prefix := app._run_receipt_prefix
	check(app.player.get_parent()==app and app.stage.get_parent()==app and app.policy.get_parent()==app, "composition preserves original scene parents")
	check(app._item_runtime==null and app._item_v5_pool==null and app.region_state==null, "fixed departure retains its original non-region service policy")
	check(not app.start_demo("duplicate") and app.wallet==first.wallet and app.player.get_instance_id()==first.player_id, "duplicate departure cannot replace the active run")
	# A real fixed-room exit, without defeating or changing the room's enemy.
	var old_policy: WeakRef = weakref(app.policy)
	var exit: ExitOffer = app.director.offers[0]
	check(exit.next_stage_type_id==&"shop", "existing fixed route supplies the shop consumer")
	app.player.reset_at(app.stage.exit_positions[0])
	check(app.choose_exit(exit.exit_id), "actual exit intent is queued")
	await frames(8)
	check(app.director.stage_index==2 and app.director.stage_type_id==&"shop", "actual exit loads the next room")
	check_same_services(first,"fixed room transition")
	check(old_policy.get_ref()==null and app.policy.lifetime==lifetime, "transition replaces only the stage damage policy")
	check(not lifetime.accepts(first_token), "previous room token is stale")
	var quote := app.shop.quote(app._stage_id("shop_jump"))
	check(quote!=null, "actual shop quote exists")
	if quote==null:
		await finish()
		return
	check(app.wallet.grant(quote.price,&"session-quote-funding"), "explicit quote-priced fixture funds the original wallet")
	var stale_purchase := ShopPurchaseRequest.new()
	stale_purchase.token=first_token
	stale_purchase.shop_id=quote.shop_id
	stale_purchase.offer_id=quote.offer_id
	stale_purchase.quote_version=quote.quote_version
	stale_purchase.transaction_id=&"session-stale-stage-purchase"
	check(app.shop.purchase(stale_purchase).status==EconomyReceipt.Status.STALE and app.wallet.balance==quote.price, "old room token cannot spend current-room money")
	app.player.reset_at(app.stage.reward_position)
	app.purchase_item()
	await frames(3)
	check(app.build.inventory.instances().size()==1 and app.wallet.balance==0, "real App shop intent acquires exactly one item at its quote")
	check(GEAR.equip_all(app.build) and app.build.item_ids().size()==1, "existing paused equipment command equips the purchased instance")
	var first_manifest := flow.manifest
	await clear_run("first departure")
	var archived := first_manifest.canonical_json()
	var first_end_epoch := lifetime.epoch
	check(app.start_plains("level-design-v2-baseline/08"), "second departure uses the real formal plains consumer")
	if not await ready_stage():
		check(false,"formal departure assembles within bounded wait")
		await finish()
		return
	check(app.director==flow and app.lifetime==lifetime and lifetime.epoch>first_end_epoch and not lifetime.accepts(first_token), "successive departures retain one monotonic flow/lifetime authority")
	check(app.wallet!=first.wallet and app.build!=first.build and app.rewards!=first.rewards and app.shop!=first.shop and app.player.get_instance_id()!=first.player_id, "new departure creates fresh run services and player")
	check(app._run_receipt_prefix!=first_prefix and app.wallet.balance==0 and app.build.inventory.instances().is_empty(), "new run has a new receipt scope and no prior money or inventory")
	check(app.shop.purchase(stale_purchase).status==EconomyReceipt.Status.STALE and app.wallet.balance==0, "previous-run transaction cannot enter the new shop ledger")
	check(flow.manifest!=first_manifest and first_manifest.canonical_json()==archived, "new run does not rewrite the ended Manifest")
	check(app._item_runtime!=null and app._item_v5_pool!=null and app.stage is PlainsRegionStage, "formal departure installs its existing V5 services and actual region")
	var formal := owned_services()
	var item_runtime := app._item_runtime
	var state := app.region_state
	var map_hash := state.manifest_hash
	var map_token := lifetime.token()
	var coin_index := next_coin()
	check(coin_index>=0,"formal map supplies a real unclaimed coin")
	if coin_index<0:
		await finish()
		return
	var stage := app.stage as GeneratedDemoStage
	var coin: Dictionary = stage.pickups[coin_index]
	app.player.reset_at(stage.to_global(coin.position))
	check(app._commit_pickup(coin_index),"actual App pickup commits the existing coin source")
	var balance := app.wallet.balance
	var coin_id := str(coin.id)
	paused = true
	old_policy=weakref(app.policy)
	await app._load_stage()
	await frames(3)
	check_same_services(formal,"formal same-map reload")
	check(app._item_runtime==item_runtime and app.region_state==state and state.manifest_hash==map_hash and state.claimed.has(coin_id), "reload preserves V5 runtime and the exact claimed-map ledger")
	check(old_policy.get_ref()==null and not lifetime.accepts(map_token), "reload frees old policy and rejects old actor token")
	check(app.wallet.balance==balance, "restoring claimed pickups does not grant money twice")
	paused = false
	coin_index=next_coin()
	check(coin_index>=0,"formal map supplies a second real coin for the death-order counterexample")
	if coin_index>=0:
		stage=app.stage as GeneratedDemoStage
		coin=stage.pickups[coin_index]
		coin_id=str(coin.id)
		app.player.reset_at(stage.to_global(coin.position))
		check(app._queue_action(app._commit_pickup.bind(coin_index)),"real pickup transaction queues before the fatal damage batch")
		app.policy.spawn_protection=0.0
		app.policy.clock+=1.0
		app._submit_damage(&"session-fatal-fixture",DamageRequest.Kind.ENVIRONMENT,99.0)
		await frames(8)
		check(flow.state==DemoRunDirector.State.HOME and not state.claimed.has(coin_id) and app.wallet.balance==0, "fatal damage wins over queued pickup and clears the ended wallet")
	else:
		await clear_run("second departure")
	# A third real entry checks that fresh forest capabilities use the same
	# composition while preserving the explicit existing debug-entry policy.
	var second_end_epoch := lifetime.epoch
	check(app.start_debug_region(&"thorn_forest",1,"session-boundary-forest"), "existing forest entry accepts a fresh run")
	if await ready_stage():
		check(app.stage is ThornForestRegionStage and app.controller.traversal.hook_enabled and app.campaign.abilities==[&"grapple"], "forest composition retains its actual map and explicit grapple grant")
		check(lifetime.epoch>second_end_epoch and not lifetime.accepts(map_token) and app.region_state!=state, "forest departure cannot reuse prior map token or state")
	else:
		check(false,"forest departure assembles within bounded wait")
	await clear_run("forest departure")
	await finish()

func next_coin() -> int:
	var stage := app.stage as GeneratedDemoStage
	for index: int in stage.pickups.size():
		var pickup: Dictionary=stage.pickups[index]
		if pickup.kind=="coin" and not pickup.claimed and stage.clock>=float(pickup.get("ready_at",0)): return index
	return -1

func finish() -> void:
	paused=false
	if is_instance_valid(app):
		if app.director.state==DemoRunDirector.State.IN_STAGE:
			app.abandon_run()
			await frames(8)
		check(await AUDIO.drain_world(app),"owned App audio releases at test teardown")
		app.free()
		await frames(2)
	print("RUN SESSION TESTS: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
