extends SceneTree
## Actual App/RewardService/Home/UI/departure integration. Notes are an explicit
## fixture; discovery is obtained through a real committed reward transaction.
const DRIVER := preload("res://tests/underworld_plains/home_terrace_driver.gd")
const ITEM_ID := &"B11"
var checks := 0
var failures := 0
var app: DemoApp

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frames(count: int = 3) -> void:
	for unused: int in count: await process_frame

func wait_stage() -> bool:
	for unused: int in 240:
		if is_instance_valid(app.stage) and not app._stage_pending: return true
		await frames(1)
	return false

func button(owner: Node, node_name: String) -> Button:
	return owner.find_child(node_name,true,false) as Button if is_instance_valid(owner) else null

func click_control(control: Button, label: String) -> bool:
	check(control != null and control.is_visible_in_tree() and not control.disabled,"Actual enabled visible pointer target: "+label)
	if control == null or not control.is_visible_in_tree() or control.disabled: return false
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await frames(2)
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)
	return true

func codex_button(node_name: String) -> Button:
	return button(app._home_codex,node_name)

func choose_item() -> bool:
	var tile := codex_button("CodexTile_"+str(ITEM_ID))
	if tile != null:
		app._home_codex._catalog_scroll.ensure_control_visible(tile)
		await frames()
	return await click_control(tile,"discovered B11 tile")

func open_codex() -> bool:
	var home := app.home_scene
	var driver := DRIVER.new(home)
	check(await driver.reach(&"relics"),"Real keyboard/Motor reaches authored relics building")
	driver.release_all()
	home.controller.router.request_action(&"interact")
	await frames(4)
	var opened := is_instance_valid(app._home_codex) and app._home_codex.opened
	check(opened and paused and home.input_blocked and app.menu.visible_panel != &"home_function","Building interaction opens the independent codex and pauses actual Home")
	return opened

func close_codex() -> void:
	var home := app.home_scene
	var shots := home.controller.shoot_ability._shot_serial
	await click_control(codex_button("CodexClose"),"CodexClose")
	await frames()
	check(not paused and not home.input_blocked and not app._home_codex.opened,"CodexClose restores current Home input and simulation")
	check(home.controller.router.axis == 0 and home.controller.shoot_ability._shot_serial == shots,"Closing pointer releases without a queued movement or shot")

func return_home() -> void:
	app.abandon_run()
	await frames(12)
	check(app.director.state == DemoRunDirector.State.HOME and is_instance_valid(app.home_scene) and not app.lifetime.active,"Abandon ends the Run and creates real Home")
	if app.menu.visible_panel == &"run_end":
		var target: Button
		for candidate: Node in app.menu.find_children("*","Button",true,false):
			if (candidate as Button).text.begins_with("ENTER HOME"):
				target = candidate as Button
				break
		await click_control(target,"ENTER HOME after actual settlement")
	await frames()

func carry_contract(expected_count: int, label: String) -> void:
	var instances := app.build.inventory.instances()
	check(instances.size() == expected_count,"Fresh formal Run owns exactly the selected carry count: "+label)
	check(app.build.equipment.equipped_ids().is_empty() and app.build.item_ids().is_empty(),"Home carry starts unequipped with no effect sources: "+label)
	check(app.controller.actor_resources.health.capacity == 5 and app.controller.actor_resources.health.current == 5,"Unequipped maximum-health carry cannot grant HP: "+label)
	if expected_count == 1 and instances.size() == 1:
		var owned := instances[0]
		check(owned.definition_id == ITEM_ID and owned.level == 1 and owned.origin == &"home_carry" and str(owned.source_id).begins_with("home_carry/"),"Departure copies one stable Lv1 instance into the backpack: "+label)

func write_fixture_policy(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK

func review_regressions() -> void:
	# Explicit policy/profile/failure-queue fixtures, not naturally occurring
	# discoveries or real production-file edits. The original 63 App checks above
	# retain their actual committed-acquisition and departure path unchanged.
	var original_meta := app.meta
	var fixture_root := "user://home_codex_app_review_%s" % Time.get_ticks_usec()
	var policy_path := fixture_root+"_policy.json"
	var profile_path := fixture_root+"_slot_b.json"
	var policy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HomeItemCatalog.CONFIG_PATH))
	policy.items["B03"] = {"unlock_notes":7}
	check(write_fixture_policy(policy_path,policy),"Review fixture writes isolated policy without changing production config")
	var fixture_meta := MetaProgression.new(policy_path)
	check(fixture_meta.grant_notes(100,&"review_notes_a").accepted and fixture_meta.discover_item(&"B03",&"review_discovery_a").accepted,"Explicit memory-only profile fixture has notes and one discovered locked item")
	app.meta = fixture_meta
	app._refresh_home_meta()
	app._open_home_function(&"relics")
	await frames(4)
	var tile := codex_button("CodexTile_B03")
	if tile != null:
		app._home_codex._catalog_scroll.ensure_control_visible(tile)
		await frames()
	if not await click_control(tile,"isolated policy item B03"): return
	var before := fixture_meta.snapshot()
	check(int(app._home_codex._rows[&"B03"].price) == 7,"Displayed real codex binds original seven-note quote")
	policy.items["B03"]["unlock_notes"] = 15
	check(write_fixture_policy(policy_path,policy),"Review fixture hot-edits isolated policy only")
	check(int(fixture_meta.home_item_quote(&"B03").price) == 15 and fixture_meta.snapshot().profile_revision == before.profile_revision,"Policy changed to fifteen notes without changing profile revision")
	await click_control(codex_button("CodexUnlock"),"stale displayed quote")
	check(fixture_meta.snapshot() == before,"Actual old-price UI click rejects stale quote without notes debit or unlock")
	var status := app._home_codex.find_child("CodexStatus",true,false) as Label
	check(status != null and status.text.contains("未扣款"),"Actual App presents stale-quote refusal and refreshes current view")
	# Arrange a real selectable old view at revision4. No stale quote can explain
	# rejecting this selection: selection only validates revision/profile owner.
	check(fixture_meta.unlock_home_item(&"B03",&"review_unlock_a").accepted and fixture_meta.grant_notes(1,&"review_extra_a").accepted,"Explicit profileA fixture prepares unlocked unselected item")
	app._refresh_home_codex()
	await frames(3)
	var old_select := codex_button("CodexSelect")
	check(old_select != null and not old_select.disabled,"Old profileA view exposes real selectable action")
	var old_context := fixture_meta.profile_context_id()
	var old_revision := int(fixture_meta.snapshot().profile_revision)
	# A failed-save queue fixture models an existing pending record. The queue is
	# deliberately not described as a newly committed natural acquisition.
	var pending_key := "review/context-bound-pending"
	app._pending_item_discoveries[pending_key] = {"id":ITEM_ID,"profile_context":old_context}
	check(fixture_meta.configure_persistence(profile_path,false,"review_slot_b").accepted,"Actual Meta owner switches to isolated profileB")
	check(fixture_meta.grant_notes(100,&"review_notes_b").accepted and fixture_meta.discover_item(&"B03",&"review_discovery_b").accepted and fixture_meta.unlock_home_item(&"B03",&"review_unlock_b").accepted and fixture_meta.grant_notes(1,&"review_extra_b").accepted,"Explicit profileB fixture reaches same revision with a selectable item")
	var switched := fixture_meta.snapshot()
	check(int(switched.profile_revision) == old_revision and fixture_meta.profile_context_id() != old_context and switched.selected_home_item.is_empty(),"Same revision across slots does not identify the same profile context")
	app._flush_item_discoveries()
	check(fixture_meta.snapshot() == switched and str(ITEM_ID) not in fixture_meta.snapshot().discovered_items and not app._pending_item_discoveries.has(pending_key),"Pending profileA discovery never writes into profileB after actual configure_persistence")
	if old_select != null: old_select.pressed.emit()
	app._select_home_item(&"B03",old_revision)
	check(fixture_meta.snapshot() == switched,"Same-revision old UI and direct stale-owner intent cannot select an eligible profileB item")
	await close_codex()
	# Configurable unseen unlock stays hidden until an actual successful carry.
	policy.requires_discovered = false
	check(write_fixture_policy(policy_path,policy),"Isolated policy permits unseen permanent unlock")
	var unseen_meta := MetaProgression.new(policy_path)
	check(unseen_meta.grant_notes(100,&"unseen_notes_fixture").accepted and unseen_meta.unlock_home_item(&"B03",&"unseen_unlock_fixture").accepted and unseen_meta.select_home_item(&"B03",&"unseen_selection_fixture").accepted,"Explicit unseen unlock fixture selects one still-hidden definition")
	check(unseen_meta.snapshot().discovered_items.is_empty(),"Unlocking and selecting an unseen item cannot fabricate discovery")
	app.meta = unseen_meta
	check(app.start_plains("home-codex-unseen-carry"),"Formal departure accepts configured unseen carry")
	check(await wait_stage(),"Unseen carry actual stage finishes loading")
	check(app.build.inventory.instances().size() == 1 and app.build.inventory.instances()[0].definition_id == &"B03" and app.build.inventory.instances()[0].level == 1 and app.build.item_ids().is_empty(),"Actual unseen carry grants exactly one inactive Lv1 item")
	check(unseen_meta.snapshot().discovered_items == ["B03"],"Successful actual inventory carry reveals the previously unseen definition")
	await return_home()
	app.meta = original_meta
	app._refresh_home_meta()
	for path: String in [policy_path,profile_path,profile_path+".backup",profile_path+".tmp",profile_path+".corrupt"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _exercise() -> void:
	app = preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	app.meta.grant_notes(1000,&"home_codex_app_notes_fixture")
	root.add_child(app)
	await frames(5)
	app.menu.requested_enter_home.emit()
	await frames(6)
	check(app.meta.snapshot().discovered_items.is_empty(),"Fresh explicit memory-only profile has no fabricated discovery")
	check(app.start_plains("home-codex-natural-acquisition"),"Actual formal departure starts discovery run")
	check(await wait_stage(),"Real Plains stage finishes loading before reward")
	var definitions: Array[ItemDefinition] = [ItemCatalogV5.get_item(ITEM_ID)]
	var offer := app.rewards.create_cache_offer(&"home_codex_reward",definitions,&"home_codex_source")
	check(offer != null,"Known-item fixture is admitted by actual RewardService")
	if offer == null: return
	var claim := RewardClaimRequest.new()
	claim.token = app.lifetime.token()
	claim.offer_id = offer.offer_id
	claim.option_id = ITEM_ID
	claim.claim_id = &"home_codex_reward_claim"
	var receipt := app.rewards.claim(claim)
	check(receipt.status == EconomyReceipt.Status.COMMITTED and receipt.instance_id == app.build.inventory.instance_for_definition(ITEM_ID).instance_id,"Real COMMITTED acquisition owns the actual reward instance")
	check(str(ITEM_ID) in app.meta.snapshot().discovered_items,"Committed reward signal discovers the actual owned V5 definition")
	var discovered := app.meta.snapshot()
	check(app.rewards.claim(claim).status == EconomyReceipt.Status.REPLAY and app.meta.snapshot() == discovered,"Replayed acquisition cannot rediscover or mutate permanent profile")
	app.rewards.claimed.emit(EconomyReceipt.rejected(EconomyReceipt.Status.INVALID))
	check(app.meta.snapshot() == discovered,"Rejected economy signal cannot fabricate discovery")
	await return_home()
	if not await open_codex(): return
	check(bool(app._home_codex._rows[ITEM_ID].discovered) and not bool(app._home_codex._rows[ITEM_ID].unlocked),"Home shows naturally discovered item with its locked state")
	if not await choose_item(): return
	var card := app._home_codex.find_child("CodexDetailCard",true,false) as ItemCard
	check(card != null and card.item.stable_id == ITEM_ID and card.level == 1,"Actual Home detail resolves the discovered Lv1 item card")
	var quote := app.meta.home_item_quote(ITEM_ID)
	var notes_before := int(app.meta.snapshot().notes)
	await click_control(codex_button("CodexUnlock"),"permanent notes unlock")
	check(app.meta.snapshot().notes == notes_before-int(quote.price) and str(ITEM_ID) in app.meta.snapshot().unlocked_home_items,"Actual UI unlock debits the configured notes price and records permanent ownership")
	await click_control(codex_button("CodexSelect"),"choose next departure carry")
	check(app.meta.snapshot().selected_home_item == str(ITEM_ID),"Actual UI selects one unlocked item for departure")
	check(not app.start_plains("must-not-start-under-codex"),"Open paused codex cannot start a stale formal departure")
	# Same-view stale profile revision is rejected by the App owner.
	var stale_revision := int(app.meta.snapshot().profile_revision)
	var stale_callback := codex_button("CodexSelect")
	app.meta.grant_notes(1,&"home_codex_revision_fixture")
	var revised := app.meta.snapshot()
	stale_callback.pressed.emit()
	app._select_home_item(&"",stale_revision)
	check(app.meta.snapshot() == revised,"Detached quote and explicit stale revision cannot mutate carry selection")
	app._refresh_home_codex()
	# Focus rejection is independent of UI generation and permanent revision.
	var focus_router := app.home_scene.controller.router
	focus_router.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var unfocused := app.meta.snapshot()
	app._select_home_item(&"",int(unfocused.profile_revision))
	check(app.meta.snapshot() == unfocused,"Unfocused owner rejects a current-revision carry request")
	focus_router.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	var old_action := codex_button("CodexSelect")
	app.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	old_action.pressed.emit()
	check(not paused and not app._home_codex.opened and app.meta.snapshot() == unfocused,"Application focus loss closes codex and invalidates old UI callbacks")
	if not await open_codex(): return
	await choose_item()
	await close_codex()
	check(app.start_plains("home-codex-carry-one"),"First selected formal departure starts")
	check(await wait_stage(),"First carry stage finishes loading")
	carry_contract(1,"first departure")
	var owned_before := app.build.inventory.instances()[0].instance_id
	app._load_stage()
	check(await wait_stage(),"Actual stage reload completes")
	check(app.build.inventory.instances().size() == 1 and app.build.inventory.instances()[0].instance_id == owned_before,"Stage reload preserves one original carry instance without regrant")
	await return_home()
	check(app.meta.snapshot().selected_home_item == str(ITEM_ID) and str(ITEM_ID) in app.meta.snapshot().unlocked_home_items,"Abandon retains permanent unlock and selected carry")
	check(app.start_plains("home-codex-carry-again"),"Second fresh formal Run accepts the permanent carry")
	check(await wait_stage(),"Second carry stage finishes loading")
	carry_contract(1,"second departure")
	await return_home()
	if not await open_codex(): return
	await choose_item()
	await click_control(codex_button("CodexSelect"),"cancel selected carry")
	check(app.meta.snapshot().selected_home_item.is_empty() and str(ITEM_ID) in app.meta.snapshot().unlocked_home_items,"Cancel clears only selection and preserves permanent item unlock")
	await close_codex()
	check(app.start_plains("home-codex-cancelled-carry"),"Formal departure after cancellation starts")
	check(await wait_stage(),"Cancelled-carry stage finishes loading")
	carry_contract(0,"cancelled departure")
	await return_home()
	await review_regressions()

func _run() -> void:
	root.size = Vector2i(1280,720)
	await _exercise()
	paused = false
	if is_instance_valid(app):
		app._close_home_codex()
		if not await load("res://tests/audio_teardown.gd").drain_world(app): check(false,"Actual App audio releases before teardown")
		app.queue_free()
	await frames(8)
	print("HOME CODEX APP: %s assertions, %s failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
