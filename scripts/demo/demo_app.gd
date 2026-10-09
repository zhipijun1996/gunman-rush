class_name DemoApp
extends Node2D

const PLAYER := preload("res://scenes/player/player.tscn")
const JUMP_ITEM := preload("res://resources/items/jump_blue.tres")
const SHOT_ITEM := preload("res://resources/items/shot_purple.tres")
const GOLD_ITEM := preload("res://resources/items/power_gold.tres")
var lifetime := DemoLifetime.new()
var director := DemoRunDirector.new(lifetime)
var meta := MetaProgression.new()
var build: BuildState
var wallet: RunWallet
var rewards: RewardService
var shop: ShopService
var player: PlayerMotor
var controller: PlayerController
var stage: DemoStage
var policy: FrameDamagePolicy
var segment: SegmentRespawn
var overlay: TouchOverlay
var current_reward: RewardOffer
var _completion_rule: StageCompletionRule
var _completion_target: HealthState
var _gold_claimed := false
var _stage_pending := false
var _sequence := 0
var _queued_actions: Array[Dictionary] = []
var _hazard_contact: DemoContactEmitter
var _enemy_contact: DemoContactEmitter
var _boss_contact: DemoContactEmitter
var _status := "A fixed three-room development demo."
var _canvas: CanvasLayer
var _home: VBoxContainer
var _seed: LineEdit
var _title: Label
var _status_label: Label
var _hud: Label
var _hint: Label
var _resources_hud: ActorResourcesHud
var _actions: HBoxContainer
var _pause_button: Button
var _home_summary: Label
var _shown_actions := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 900
	director.stage_entered.connect(_stage_entered)
	director.run_ended.connect(_run_ended)
	_make_ui()
	_show_home()

func start_demo(seed_value: String = "gunman-demo-1") -> bool:
	if director.state != DemoRunDirector.State.HOME or seed_value.is_empty():
		return false
	get_tree().paused = false
	player = PLAYER.instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.interact_requested.connect(interact)
	overlay = InputSetup.attach(player, controller.router)
	overlay.reset_label = "HOME"
	overlay.pause_requested.connect(toggle_pause)
	overlay.reset_requested.connect(abandon_run)
	var vignette := FocusVignette.new()
	vignette.name = "FocusVignette"
	vignette.ability = controller.air_focus_ability
	player.add_child(vignette)
	var aim_guide := DemoAimGuide.new()
	aim_guide.controller = controller
	player.add_child(aim_guide)
	build = BuildState.new()
	build.configure(controller)
	wallet = RunWallet.new()
	rewards = RewardService.new()
	rewards.configure(lifetime, build)
	shop = ShopService.new()
	shop.configure(lifetime, build, wallet)
	_resources_hud.bind(controller.actor_resources, controller.air_focus_ability)
	_gold_claimed = false
	_sequence = 0
	_home.hide()
	_resources_hud.show()
	_pause_button.show()
	return director.start(seed_value).accepted()

func _stage_entered(_result: DemoRunResult) -> void:
	_stage_pending = true
	controller.router.clear("stage_transition")
	controller.air_focus_ability.stop()
	call_deferred("_load_stage")

func _load_stage() -> void:
	if not lifetime.active:
		return
	if is_instance_valid(policy):
		remove_child(policy)
		policy.queue_free()
	segment = null
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	var loading_token := lifetime.token()
	stage = DemoStage.new()
	stage.configure(director.stage_index, director.stage_type_id, director.offers)
	_completion_rule = StageTypeDefinition.registry()[director.stage_type_id].rule()
	_completion_target = null
	if director.stage_index == 1:
		director.manifest.record_configuration([
			{"id": "demo_fixed_layout", "version": 1},
			{"id": String(JUMP_ITEM.stable_id), "version": JUMP_ITEM.definition_version},
			{"id": String(SHOT_ITEM.stable_id), "version": SHOT_ITEM.definition_version},
			{"id": String(GOLD_ITEM.stable_id), "version": GOLD_ITEM.definition_version}],
			{"physics": FileAccess.get_sha256("res://config/player_tuning.json"), "input": FileAccess.get_sha256("res://config/input_profile.json"), "health": FileAccess.get_sha256("res://resources/actors/prototype_health.tres")},
			{"id": "prototype_player", "weapon": "release_shot", "max_jumps": controller.motor.tuning.max_jumps, "max_air_shots": controller.motor.tuning.max_air_shots})
	add_child(stage)
	controller.return_to_segment(stage.spawn)
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	policy.player_fatal.connect(_player_fatal)
	policy.environment_return_requested.connect(_environment_return)
	policy.batch_resolved.connect(_damage_resolved)
	segment = SegmentRespawn.new()
	segment.configure(controller, lifetime)
	segment.add_anchor(&"entry", stage.spawn)
	segment.add_anchor(&"midpoint", stage.anchor_position)
	segment.danger_bounds = [Rect2(780, 530, 80, 110)]
	await get_tree().physics_frame
	if not lifetime.accepts(loading_token) or not is_instance_valid(stage):
		return
	segment.activate_anchor(&"entry")
	_hazard_contact = _contact(stage, &"saw", DamageRequest.Kind.ENVIRONMENT, Vector2(25, 25))
	_hazard_contact.position = stage.hazard_position
	_enemy_contact = null
	_boss_contact = null
	policy.protect_player()
	current_reward = null
	if stage.enemy != null:
		var actor := stage.enemy.get_node("Actor") as EnemyActor
		_completion_target = actor.health
		policy.bind_damageable(&"drone", actor.damageable, actor.health)
		_enemy_contact = _contact(stage.enemy, &"drone_contact", DamageRequest.Kind.MONSTER, Vector2(14, 16))
	if stage.boss != null:
		var encounter := stage.boss.get_node("Encounter")
		_completion_target = encounter.health
		policy.bind_damageable(&"boss", stage.boss.get_node("Damageable"), encounter.health)
		encounter.configure_arena(890.0, 1240.0, player)
		encounter.projectile_created.connect(_boss_projectile_created)
		encounter.activate()
		_boss_contact = _contact(stage.boss, &"boss_contact", DamageRequest.Kind.MONSTER, Vector2(25, 27))
	if director.stage_type_id == &"item_reward":
		var candidates: Array[ItemDefinition] = [JUMP_ITEM, SHOT_ITEM]
		current_reward = rewards.create_offer(_stage_id("items"), candidates, _stage_id("room_reward"))
	elif director.stage_type_id == &"shop":
		shop.add_offer(_stage_id("shop_jump"), JUMP_ITEM, 5, 1)
	director.manifest.record_output(director.stage_index, &"fixed_layout", {"version": 1, "layout_id": "demo_fixed_1", "spawn": [100, 580], "anchor": [660, 580], "hazard": "oscillating_saw_1", "enemy": "patrol_drone" if stage.enemy != null else "", "boss": "clockwork_guardian" if stage.boss != null else ""})
	director.manifest.record_output(director.stage_index, &"capability_snapshot", {"max_jumps": controller.motor.tuning.max_jumps, "max_air_shots": controller.motor.tuning.max_air_shots, "items": build.item_ids()})
	if current_reward != null:
		_record_reward()
	if director.stage_type_id == &"shop":
		var initial_quote := shop.quote(_stage_id("shop_jump"))
		director.manifest.record_output(director.stage_index, &"shop_stock", {"offer": String(initial_quote.offer_id), "item": String(initial_quote.item.stable_id), "price": initial_quote.price, "stock": initial_quote.stock, "quote_version": initial_quote.quote_version})
	_status = "Room %s: %s. Reach markers and use Interact." % [director.stage_index, director.stage_type_id]
	_shown_actions = ""
	_stage_pending = false

func _physics_process(_delta: float) -> void:
	if get_tree().paused or _stage_pending or not lifetime.active or not is_instance_valid(stage) or not is_instance_valid(controller):
		return
	if director.state != DemoRunDirector.State.IN_STAGE:
		return
	var position_now := player.global_position
	if is_instance_valid(segment) and position_now.distance_to(stage.anchor_position) < 50:
		segment.activate_anchor(&"midpoint")
	if position_now.y > 690 or position_now.y < -350:
		_submit_damage(&"bounds", DamageRequest.Kind.ENVIRONMENT, 1.0)
	_hazard_contact.position = stage.hazard_position
	if is_instance_valid(_enemy_contact):
		_enemy_contact.enabled = not stage.enemy.get_node("Actor").health.terminal
	if is_instance_valid(_boss_contact):
		_boss_contact.enabled = not stage.boss.get_node("Encounter").health.terminal

func _submit_damage(source: StringName, kind: DamageRequest.Kind, amount: float, event: StringName = &"") -> void:
	var request := DamageRequest.new()
	request.token = lifetime.token()
	request.event_id = _next_id(str(source)) if event.is_empty() else event
	request.source_id = source
	request.target_id = &"player"
	request.kind = kind
	request.amount = amount
	request.health_epoch = controller.actor_resources.health.epoch
	request.actor_epoch = lifetime.actor_epoch
	policy.submit(request)

func _boss_projectile_created(projectile: Node) -> void:
	projectile.hit.connect(func(body: Node, event_id: StringName, amount: float) -> void:
		if body == player and lifetime.active and is_instance_valid(policy):
			_submit_damage(&"boss_projectile", DamageRequest.Kind.MONSTER, amount, event_id)
	)

func _damage_resolved(_results: Array[DamageResult]) -> void:
	if not lifetime.active:
		_queued_actions.clear()
		return
	var was_complete := director.stage_complete
	var claimed := current_reward != null and rewards.get_offer(current_reward.offer_id).claimed
	if _completion_rule.evaluate(player.global_position, _completion_target, claimed):
		_complete_room()
	if not was_complete and director.stage_complete:
		if stage.enemy != null:
			wallet.grant(10, _stage_id("combat_coins"))
		elif stage.boss != null:
			current_reward = rewards.create_gold_offer(_stage_id("gold"), GOLD_ITEM, _stage_id("boss_defeat"))
			stage.reward_position = stage.boss.global_position
			stage.reward_available = true
			_record_reward()
			_status = "Boss defeated. Claim the guaranteed GOLD item to finish."
	_flush_actions()

func _complete_room() -> void:
	if not director.stage_complete and director.complete_stage(lifetime.token()):
		stage.set_completed(true)
		_status = "Room complete. Choose an exit to continue."

func _environment_return() -> void:
	if is_instance_valid(segment) and segment.return_to_anchor():
		policy.protect_player()
		_status = "Environment damage: returned to this segment; rewards and enemies persist."

func _player_fatal() -> void:
	controller.die()
	director.end_failure(_next_id("death"))

func _commit_interact() -> void:
	if not _can_interact():
		return
	if not stage.supply_claimed and player.global_position.distance_to(stage.supply_position) < 80:
		var result := SupplyHealEffect.apply(controller.actor_resources.health, 2.0, _stage_id("supply"))
		if result.accepted():
			stage.mark_supply_used()
			_status = "Supply used once. +%.0f HP" % result.amount_applied
		return
	var index := stage.nearby_exit(player.global_position)
	if index >= 0:
		_commit_exit(stage.exits[index].exit_id)

func _commit_exit(id: StringName) -> bool:
	if not _can_interact():
		return false
	var index := stage.nearby_exit(player.global_position)
	if index < 0 or stage.exits[index].exit_id != id:
		return false
	return director.select_exit(lifetime.token(), id, _next_id("exit")).accepted()

func _commit_claim(option_id: StringName) -> bool:
	if not _can_interact() or current_reward == null or player.global_position.distance_to(stage.reward_position) > 130:
		return false
	var request := RewardClaimRequest.new()
	request.token = lifetime.token()
	request.offer_id = current_reward.offer_id
	request.option_id = option_id
	request.claim_id = _next_id("claim")
	var receipt := rewards.claim(request)
	if not receipt.accepted():
		return false
	director.manifest.record_output(director.stage_index, &"reward_claim", {"offer": String(current_reward.offer_id), "item": String(receipt.item_id)})
	_status = "Acquired %s. Build modifiers are reversible." % option_id
	if current_reward.gold:
		_gold_claimed = true
		director.finish_success(lifetime.token(), _next_id("success"), _gold_claimed)
	_shown_actions = ""
	return true

func _commit_purchase() -> bool:
	if not _can_interact() or director.stage_type_id != &"shop" or player.global_position.distance_to(stage.reward_position) > 130:
		return false
	var quote := shop.quote(_stage_id("shop_jump"))
	var request := ShopPurchaseRequest.new()
	request.token = lifetime.token()
	request.shop_id = quote.shop_id
	request.offer_id = quote.offer_id
	request.quote_version = quote.quote_version
	request.transaction_id = _next_id("purchase")
	var receipt := shop.purchase(request)
	if receipt.accepted():
		director.manifest.record_output(director.stage_index, &"shop_purchase", {"offer": String(quote.offer_id), "item": String(receipt.item_id), "coins": receipt.coins})
	_status = "Purchased EXTRA JUMP." if receipt.accepted() else "Purchase unavailable (coins, stock or item limit)."
	_shown_actions = ""
	return receipt.accepted()

func _can_interact() -> bool:
	return lifetime.active and not _stage_pending and director.state == DemoRunDirector.State.IN_STAGE and is_instance_valid(stage) and not get_tree().paused

func toggle_pause() -> void:
	if director.state != DemoRunDirector.State.IN_STAGE:
		return
	controller.router.clear("pause")
	controller.air_focus_ability.stop()
	get_tree().paused = not get_tree().paused
	_pause_button.text = "RESUME" if get_tree().paused else "PAUSE"
	_shown_actions = ""

func abandon_run() -> void:
	if director.state == DemoRunDirector.State.IN_STAGE:
		controller.router.clear("abandon")
		controller.air_focus_ability.stop()
		get_tree().paused = false
		director.end_failure(_next_id("abandon"))

func _run_ended(result: DemoRunResult) -> void:
	_queued_actions.clear()
	var summary := {"stage": director.stage_index, "items": build.item_ids(), "run_coins_discarded": wallet.balance, "seed": director.seed}
	meta.settle(StringName("run_%s_%s" % [result.run_epoch, result.event_id]), result.reason == &"success", summary)
	_status = "VICTORY / GOLD CLAIMED" if result.reason == &"success" else "RUN ENDED / RETURNED HOME"
	controller.router.clear("run_end")
	controller.air_focus_ability.stop()
	controller.active = false
	call_deferred("_cleanup_run")

func _cleanup_run() -> void:
	get_tree().paused = false
	_resources_hud.unbind()
	build.clear()
	wallet.balance = 0
	for object: Node in [stage, policy, player]:
		if is_instance_valid(object):
			remove_child(object)
			object.queue_free()
	stage = null
	player = null
	controller = null
	policy = null
	segment = null
	director.return_home()
	_show_home()

func _show_home() -> void:
	_home.show()
	_resources_hud.hide()
	_pause_button.hide()
	_hud.text = ""
	_hint.text = ""
	_title.text = "GUNMAN RUSH / HOME"
	var snapshot := meta.snapshot()
	_home_summary.text = "%s\nCompleted: %s   Failed: %s\nSession-only home summary; permanent saves are a later task." % [_status, snapshot.completed_runs, snapshot.failed_runs]
	_clear_actions()
	queue_redraw()

func _process(_delta: float) -> void:
	_status_label.text = _status
	if director.state != DemoRunDirector.State.IN_STAGE or not is_instance_valid(controller) or _stage_pending:
		return
	_title.text = "GUNMAN RUSH / ROOM %s OF 3 / %s" % [director.stage_index, String(director.stage_type_id).to_upper()]
	_hud.text = "COINS %s | JUMPS %s | AIR SHOTS %s | BUILD %s" % [wallet.balance, controller.motor.tuning.max_jumps, controller.action_resources.shot_charges, build.item_ids().size()]
	_hint.text = _device_hint()
	_pause_button.visible = not overlay.enabled
	_update_actions()

func _device_hint() -> String:
	if controller.router.current_device == &"touch":
		return "Left stick: move / up: interact | JUMP: tap or hold | Right stick: aim, RELEASE to fire"
	if controller.router.current_device == &"gamepad":
		return "Left stick: move | Jump button: tap / hold | Right stick: aim, return to center to fire"
	return "A/D: move | Space: tap / hold jump | Mouse: aim, RELEASE left button to fire | E: interact"

func _update_actions() -> void:
	var key := ""
	if get_tree().paused:
		key = "paused"
	elif current_reward != null and not rewards.get_offer(current_reward.offer_id).claimed and player.global_position.distance_to(stage.reward_position) < 130:
		key = "reward:" + str(current_reward.offer_id)
	elif director.stage_type_id == &"shop" and player.global_position.distance_to(stage.reward_position) < 130:
		key = "shop"
	elif not stage.supply_claimed and player.global_position.distance_to(stage.supply_position) < 80:
		key = "supply"
	elif stage.nearby_exit(player.global_position) >= 0:
		key = "exit:" + str(stage.nearby_exit(player.global_position))
	if key == _shown_actions:
		return
	_shown_actions = key
	_clear_actions()
	if key == "paused":
		_button(_actions, "RESUME", toggle_pause)
		_button(_actions, "END RUN / HOME", abandon_run)
	elif key.begins_with("reward:"):
		for item: ItemDefinition in current_reward.candidates:
			var selected_id := item.stable_id
			_button(_actions, item.display_name, func() -> void: claim_item(selected_id))
	elif key == "shop":
		var quote := shop.quote(_stage_id("shop_jump"))
		_button(_actions, "%s / %s coins / stock %s" % [quote.item.display_name, quote.price, quote.stock], purchase_item)
	elif key == "supply":
		_button(_actions, "USE SUPPLY / +2 HP", interact)
	elif key.begins_with("exit:"):
		var index := stage.nearby_exit(player.global_position)
		var exit_id: StringName = stage.exits[index].exit_id
		var button := _button(_actions, "ENTER " + stage.exits[index].label, func() -> void: choose_exit(exit_id))
		button.disabled = not stage.completed

func _make_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 2
	add_child(_canvas)
	_title = _label(Vector2(22, 14), 22)
	_hud = _label(Vector2(22, 42), 15)
	_hint = _label(Vector2(22, 108), 14)
	_status_label = _label(Vector2(22, 134), 15)
	_resources_hud = ActorResourcesHud.new()
	_canvas.add_child(_resources_hud)
	_pause_button = Button.new()
	_pause_button.text = "PAUSE"
	_pause_button.position = Vector2(1150, 75)
	_pause_button.size = Vector2(108, 45)
	_pause_button.pressed.connect(toggle_pause)
	_canvas.add_child(_pause_button)
	_actions = HBoxContainer.new()
	_actions.position = Vector2(360, 178)
	_actions.add_theme_constant_override("separation", 16)
	_canvas.add_child(_actions)
	_home = VBoxContainer.new()
	_home.position = Vector2(300, 260)
	_home.custom_minimum_size = Vector2(700, 300)
	_home.add_theme_constant_override("separation", 20)
	_canvas.add_child(_home)
	var intro := Label.new()
	intro.text = "Precision platforming + recoil shooting\nCombat > choose SHOP or ITEM room > Boss > GOLD > Home\nJump: short tap / long hold. Air aiming slows time.\nFixed graybox demo, original placeholder art."
	intro.add_theme_font_size_override("font_size", 20)
	_home.add_child(intro)
	_seed = LineEdit.new()
	_seed.text = "gunman-demo-1"
	_seed.placeholder_text = "Run seed"
	_home.add_child(_seed)
	_button(_home, "BEGIN RUN", func() -> void: start_demo(_seed.text))
	_home_summary = Label.new()
	_home.add_child(_home_summary)

func _label(location: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = location
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	_canvas.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 52)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _clear_actions() -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()

func _stage_id(prefix: String) -> StringName:
	return StringName("%s_stage_%s" % [prefix, director.stage_index])

func _next_id(prefix: String) -> StringName:
	_sequence += 1
	return StringName("%s_%s_%s" % [prefix, lifetime.epoch, _sequence])

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.045, 0.06, 0.085))

func _contact(parent: Node2D, id: StringName, kind: DamageRequest.Kind, size: Vector2) -> DemoContactEmitter:
	var emitter := DemoContactEmitter.new()
	emitter.policy = policy
	emitter.controller = controller
	emitter.source_id = id
	emitter.kind = kind
	emitter.half_size = size
	emitter.interval = 0.7
	parent.add_child(emitter)
	return emitter

# Physical damage resolves first. UI and interaction intents cannot win a race
# against a lethal contact/Boss projectile in the same physics frame.
func interact() -> void:
	_queue_action(_commit_interact)

func choose_exit(id: StringName) -> bool:
	return _queue_action(_commit_exit.bind(id))

func claim_item(option_id: StringName) -> bool:
	return _queue_action(_commit_claim.bind(option_id))

func purchase_item() -> bool:
	return _queue_action(_commit_purchase)

func _queue_action(action: Callable) -> bool:
	if not _can_interact():
		return false
	_queued_actions.append({"token": lifetime.token(), "action": action})
	return true

func _flush_actions() -> void:
	var pending := _queued_actions
	_queued_actions = []
	for entry: Dictionary in pending:
		if lifetime.accepts(entry.token) and _can_interact():
			entry.action.call()

func _record_reward() -> void:
	var ids: Array[String] = []
	for item: ItemDefinition in current_reward.candidates:
		ids.append(String(item.stable_id))
	director.manifest.record_output(director.stage_index, &"reward_candidates", {"offer": String(current_reward.offer_id), "gold": current_reward.gold, "items": ids})
