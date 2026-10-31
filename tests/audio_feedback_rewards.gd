extends SceneTree
## AUDIO-FEEDBACK-05: real App/transactions with explicit relocation, wallet and
## menu-state fixtures. No natural route, boss kill or aesthetic approval claim.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var checks := 0
var failures: Array[String] = []
var serial := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)
		push_error(reason)

func frames(count: int = 3) -> void:
	for unused: int in count:
		await physics_frame
		await process_frame

func owned_audio(app: DemoApp) -> Variant:
	# Avoid the independently reproduced test-only GameAudio member-type cycle.
	for child: Node in app.get_children():
		var script := child.get_script() as Script
		while script != null:
			if script.resource_path == "res://scripts/audio/game_audio.gd": return child
			script = script.get_base_script()
	return null

func event_ids(audio: Variant, begin: int) -> Array[String]:
	var result: Array[String] = []
	for row: Dictionary in audio.director_events.slice(begin): result.append(str(row.id))
	return result

func reset_audio(audio: Variant) -> void:
	audio.stop_director_cues()
	await frames(8)

func reward_request(app: DemoApp, tag: String) -> RewardClaimRequest:
	serial += 1
	var item: ItemDefinition
	for item_id: StringName in [&"B03", &"B04", &"B05", &"B06", &"B07", &"B08"]:
		var candidate := ItemCatalogV5.get_item(item_id)
		if candidate != null and app.build.can_add(candidate):
			item = candidate
			break
	check(item != null, "SETUP known-item fixture has an actual eligible definition")
	if item == null: return null
	var id := StringName("audio-feedback/reward/%s/%s" % [tag, serial])
	var items: Array[ItemDefinition] = [item]
	var offer := app.rewards.create_cache_offer(id, items, StringName(str(id) + "/source"))
	check(offer != null, "Real RewardService creates the explicit fixture offer")
	if offer == null: return null
	var request := RewardClaimRequest.new()
	request.token = app.lifetime.token()
	request.offer_id = offer.offer_id
	request.option_id = item.stable_id
	request.claim_id = StringName(str(id) + "/claim")
	return request

func cache_flow(app: DemoApp, audio: Variant, resource_choice: bool, label: String) -> void:
	await reset_audio(audio)
	var stage := app.stage as PlainsRegionStage
	var index := -1
	for candidate_index: int in stage.chests.size():
		var row: Dictionary = stage.chests[candidate_index]
		if not bool(row.claimed) and (resource_choice or str(row.reward_mode) != "resources"):
			index = candidate_index
			break
	check(index >= 0, label + " actual generated stage contains the needed unclaimed cache")
	if index < 0: return
	var chest: Dictionary = stage.chests[index]
	# Explicit proximity fixture. All offer validation/grants/claimed state are real.
	app.player.global_position = chest.position
	app.controller.motor.reset_motion()
	var before: int = audio.director_events.size()
	app._region_interact()
	check(paused and app.reward_modal.opened and not bool(chest.claimed), label + " viewing the real offer does not open the cache or grant anything")
	check(event_ids(audio, before).is_empty(), label + " offer view adds no opening/obtain sound")
	var option: ItemDefinition
	for candidate: ItemDefinition in app._region_offer.candidates:
		if (candidate is ResourceRewardChoice) == resource_choice:
			option = candidate
			break
	check(option != null, label + " actual offer exposes the requested item/resource role")
	if option == null:
		app._cancel_exit_ui("audio-feedback-fixture")
		paused = false
		return
	check(not app._claim_region_chest(&"audio-feedback/invalid-option") and not bool(chest.claimed), label + " rejected option cannot open cache")
	check(event_ids(audio, before).is_empty(), label + " rejected option has no success sound")
	var inventory_before: int = app.build.inventory.instances().size()
	check(app._claim_modal_item(option.stable_id), label + " real modal submits through the damage-first action queue")
	await frames(6)
	check(bool(chest.claimed) and bool(app.region_state.claimed.get(chest.id, false)) and not app.reward_modal.opened and not paused, label + " actual committed choice opens once and closes modal")
	var heard := event_ids(audio, before)
	check(heard.count("chest_open") == 1, label + " actual claimed transition emits one selected opening")
	check(heard.count("item_get") == (0 if resource_choice else 1), label + " only a real inventory acquisition emits the long obtain sound")
	check(not heard.has("confirm"), label + " successful reward does not also play generic confirmation")
	if resource_choice: check(app.build.inventory.instances().size() == inventory_before, label + " resource choice never becomes an inventory item")
	else: check(heard.find("chest_open") < heard.find("item_get"), label + " opening is submitted before the obtain layer")
	var after: int = audio.director_events.size()
	check(not app._claim_modal_item(option.stable_id), label + " stale late choice is rejected")
	check(audio.director_events.size() == after, label + " rejected duplicate cannot emit another opening or obtain")

func shop_flow(app: DemoApp, audio: Variant) -> void:
	await reset_audio(audio)
	check(app.wallet.grant(500, &"audio-feedback/shop-funds"), "SETUP wallet fixture grants real ledger-backed purchase funds")
	app.player.global_position = (app.stage as PlainsRegionStage).merchant_position
	app.controller.motor.reset_motion()
	app._open_region_shop()
	check(app.shop_modal.opened and paused and app._v5_shop_presenter.is_open(), "Actual V5 merchant opens its paused transaction context")
	if not app._v5_shop_presenter.is_open(): return
	var snapshot: Dictionary = app.shop.catalog_shop_snapshot(app._v5_shop_presenter._shop_id, app._item_runtime.map_key())
	var id: StringName = &""
	for row: Dictionary in snapshot.offers:
		var offer := app.shop.quote(StringName(row.offer_id))
		if offer != null and ItemV5Eligibility.offer_reason(offer.item, app.build, true).is_empty():
			id = offer.offer_id
			break
	check(not id.is_empty(), "Actual frozen catalog has an eligible item offer")
	if not id.is_empty():
		var before: int = audio.director_events.size()
		var coins_before: int = app.wallet.balance
		app._v5_shop_presenter._catalog_purchase(id)
		var heard := event_ids(audio, before)
		check(app.wallet.balance < coins_before, "Original shop transaction really commits payment")
		check(heard.count("item_get") == 1 and not heard.has("confirm"), "COMMITTED V5 item purchase emits only one selected obtain event despite menu pause")
		var voices: Array = audio._voices.filter(func(voice: AudioStreamPlayer) -> bool: return voice.playing and voice.get_meta("director_event", &"") == &"item_get")
		check(voices.size() == 1 and (voices[0] as Node).process_mode == Node.PROCESS_MODE_ALWAYS, "Actual paused-menu reward owns a real always-playing shared voice")
		before = audio.director_events.size()
		app._v5_shop_presenter._catalog_purchase(id)
		check(audio.director_events.size() == before, "Consumed/stale catalog row cannot repeat purchase success audio")
	app._close_region_shop()
	await frames(3)
	check(not paused, "Original merchant close resumes the game")

func run() -> void:
	await exercise()
	await frames(4)
	print("AUDIO_FEEDBACK_REWARDS checks=%d failures=%d" % [checks, failures.size()])
	quit.call_deferred(0 if failures.is_empty() else 1)

func exercise() -> void:
	root.size = Vector2i(1280, 720)
	var app := (load("res://scenes/demo/demo.tscn") as PackedScene).instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(6)
	var audio: Variant = owned_audio(app)
	check(audio != null and audio.audio_profile == "selected", "Actual formal scene enables the retained selected SFX bank")
	check(app.start_plains("audio-feedback-rewards-05"), "Real formal plains consumer starts")
	await frames(6)
	app._cancel_enemy_attacks()
	# This audio transaction fixture suppresses actor movement only. It does
	# not change transaction eligibility, health, RNG, damage or reward content.
	app.controller.set_physics_process(false)
	await cache_flow(app, audio, false, "plains item cache")
	await cache_flow(app, audio, true, "plains resource cache")
	await shop_flow(app, audio)
	await reset_audio(audio)
	var request := reward_request(app, "receipt")
	if request != null:
		var before: int = audio.director_events.size()
		var receipt := app.rewards.claim(request)
		check(receipt.status == EconomyReceipt.Status.COMMITTED and event_ids(audio, before) == ["item_get"], "New committed ownership receipt emits one obtain without requiring an extra UI confirm")
		before = audio.director_events.size()
		var replay := app.rewards.claim(request)
		check(replay.status == EconomyReceipt.Status.REPLAY and audio.director_events.size() == before, "Original replay receipt grants no item and emits no new obtain")
		check(audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and bool(voice.get_meta("committed_reward", false))), "Applied reward has an actual committed voice for lifecycle checks")
		audio.stop_regional_cues()
		check(audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and bool(voice.get_meta("committed_reward", false))), "Ordinary regional cleanup preserves the actual accepted reward tail")
		# Explicit menu-state boundary fixture; this is not natural run progress.
		app.menu.show_title()
		await frames(2)
		check(not audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and bool(voice.get_meta("committed_reward", false))), "Real title presentation boundary clears committed reward tails")
		app.menu.hide_home()
		await frames(2)
	await reset_audio(audio)
	check(audio.set_audio_profile("original"), "Explicit original-profile comparison is available")
	request = reward_request(app, "fallback")
	if request != null:
		var notes: int = int(audio.played.get(&"note", 0))
		paused = true
		var receipt := app.rewards.claim(request)
		check(receipt.status == EconomyReceipt.Status.COMMITTED and int(audio.played.get(&"note", 0)) == notes + 1, "Original-profile committed obtain uses its reasonable legacy note fallback while paused")
		paused = false
	check(audio.set_audio_profile("selected"), "Actual selected preferences resume unchanged")
	await reset_audio(audio)
	request = reward_request(app, "run-end")
	if request != null: app.rewards.claim(request)
	check(audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and bool(voice.get_meta("committed_reward", false))), "Real new ownership supplies the run-end tail fixture")
	app.abandon_run()
	check(not audio._voices.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing and bool(voice.get_meta("committed_reward", false))), "Actual run end clears accepted reward audio")
	await frames(8)
	check(app.start_debug_region(&"thorn_forest", 1, "audio-feedback-rewards-05"), "Existing explicit debug entry provides a real forest consumer")
	await frames(6)
	app._cancel_enemy_attacks()
	app.controller.set_physics_process(false)
	await cache_flow(app, audio, false, "forest item cache")
	app.abandon_run()
	await frames(8)
	check(await TEARDOWN.drain_world(app), "All actual audio playback releases within the original bounded teardown")
	app.free()
