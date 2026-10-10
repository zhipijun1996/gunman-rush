class_name DemoApp
extends Node2D

const EXIT_MODAL := preload("res://scripts/ui/stage_exit_modal.gd")
const PLAYER := preload("res://scenes/player/player.tscn")
const JUMP_ITEM := preload("res://resources/items/jump_blue.tres")
const SHOT_ITEM := preload("res://resources/items/shot_purple.tres")
const COIN_REWARD := preload("res://resources/rewards/demo_coins.tres")
const HEAL_REWARD := preload("res://resources/rewards/demo_heal.tres")
const DAMAGE_ITEM := preload("res://resources/items/damage_blue.tres")
const RECOIL_ITEM := preload("res://resources/items/recoil_purple.tres")
const HEALTH_ITEM := preload("res://resources/items/health_blue.tres")
const GOLD_ITEM := preload("res://resources/items/power_gold.tres")
const MODULE_LAB := preload("res://scenes/demo/module_lab.tscn")
var meta_persistence_enabled := true
var generated_plains := false
var home_scene: HomeScene
var debug_hud := false
var _run_receipt_prefix := ""
var _meta_purchase_sequence := 0
var _run_camera: StageCameraRig
var _lab: ModuleLab
var _preview: RandomStagePreview
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
var _enemy_drops: EnemyDropService
var _gold_claimed := false
var _stage_pending := false
var _sequence := 0
var _input_revision := 0
var _queued_actions: Array[Dictionary] = []
var _hazard_contact: DemoContactEmitter
var _enemy_contacts: Array[DemoContactEmitter] = []
var _enemy_contact: DemoContactEmitter
var _boss_started := false
var _boss_was_in_core := false
var _boss_eligible_shots: Dictionary = {}
var _boss_contact: DemoContactEmitter
var _status := "Choose a route and put your recoil to work."
var _hud_frame: Panel
var _canvas: CanvasLayer
var menu: DemoMenu
var simple_reward: SimpleRoomReward
var catalog := DemoRewardCatalog.new()
var _session_input := InputProfile.load_default().values.duplicate(true)
var _title: Label
var _status_label: Label
var _hud: Label
var _hint: Label
var _resources_hud: ActorResourcesHud
var _actions: HBoxContainer
var _pause_button: Button
var _shown_actions := ""
var exit_modal: EXIT_MODAL
var _offered_exit: StringName = &""
var _exit_prompt_token: DemoToken
var _dismissed_exits: Dictionary = {}
var reward_modal: StageRewardModal
var _pending_exit: StringName = &""
var _reward_token: DemoToken

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 900
	lifetime.end() # TITLE/Home do not own an active Run token.
	var backdrop := PlainsBackground.new()
	backdrop.name = "PlainsBackground"
	add_child(backdrop)
	director.stage_entered.connect(_stage_entered)
	director.run_ended.connect(_run_ended)
	if meta_persistence_enabled:
		meta.configure_persistence("user://plains_meta.json")
	_make_ui()
	_refresh_home_meta()
	_hide_run_hud()
	menu.show_title()

func start_plains(seed_value: String = "plains-run") -> bool:
	return start_demo(seed_value, true, true)

func start_demo(seed_value: String = "gunman-demo-1", formal_eight: bool = false, random_plains: bool = false) -> bool:
	if director.state != DemoRunDirector.State.HOME or seed_value.is_empty() or is_instance_valid(_lab) or is_instance_valid(_preview):
		return false
	_remove_home_scene()
	generated_plains = random_plains
	_run_receipt_prefix = meta.new_run_receipt_prefix()
	director.biome_id = &"plains" if generated_plains else &"demo_ruins"
	get_tree().paused = false
	player = PLAYER.instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.interact_requested.connect(interact)
	controller.shoot_ability.shot_fired.connect(_record_boss_shot)
	controller.router.reconfigure(_session_input)
	overlay = InputSetup.attach(player, controller.router)
	overlay.hide_reset_button = true
	overlay.pause_label = "MENU"
	overlay.pause_requested.connect(toggle_pause)
	overlay.reset_requested.connect(toggle_pause)
	var vignette := FocusVignette.new()
	vignette.name = "FocusVignette"
	vignette.ability = controller.air_focus_ability
	player.add_child(vignette)
	var aim_guide := DemoAimGuide.new()
	aim_guide.controller = controller
	player.add_child(aim_guide)
	if generated_plains:
		controller.actor_resources.health_definition = meta.fresh_health_definition(controller.actor_resources.health_definition)
		controller.actor_resources.health.configure(controller.actor_resources.health_definition)
	build = BuildState.new()
	build.configure(controller)
	catalog.configure(build, director.biome_id)
	wallet = RunWallet.new()
	rewards = RewardService.new()
	rewards.configure(lifetime, build)
	shop = ShopService.new()
	shop.configure(lifetime, build, wallet)
	_resources_hud.bind(controller.actor_resources, controller.air_focus_ability)
	_gold_claimed = false
	_sequence = 0
	_input_revision = 0
	menu.hide_home()
	_resources_hud.show()
	_hud_frame.show()
	_pause_button.show()
	return director.start(seed_value, RunProfile.formal() if formal_eight else RunProfile.development()).accepted()

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
	if generated_plains:
		var generated := PlainsStageGenerator.new().generate(director.seed, director.stage_index, director.stage_type_id, controller.motor.tuning)
		if not generated.ok:
			_status = "GENERATION FAILED / " + str(generated.error)
			abandon_run()
			return
		stage = GeneratedDemoStage.new()
		(stage as GeneratedDemoStage).configure_generated(generated, controller.motor.tuning)
	else:
		stage = DemoStage.new()
	stage.configure(director.stage_index, director.stage_type_id, director.offers)
	_completion_rule = StageTypeDefinition.registry()[director.stage_type_id].rule(generated_plains or director.stage_type_id == &"combat")
	_completion_target = null
	_enemy_drops = EnemyDropService.new()
	if not _enemy_drops.configure(director.seed, "stage_%s" % director.stage_index):
		push_error("Invalid enemy drop configuration")
		abandon_run()
		return
	if director.stage_index == 1:
		if generated_plains:
			director.manifest.enable_plains_generation()
		var initial_character := {"id": "prototype_player", "weapon": "release_shot", "max_jumps": controller.motor.tuning.max_jumps, "max_air_shots": controller.motor.tuning.max_air_shots, "input_values": _session_input.duplicate(true)}
		var config_hashes := {"physics": FileAccess.get_sha256("res://config/player_tuning.json"), "input": FileAccess.get_sha256("res://config/input_profile.json"), "health": FileAccess.get_sha256("res://resources/actors/prototype_health.tres")}
		config_hashes.enemy_drops = FileAccess.get_sha256(EnemyDropService.CONFIG_PATH)
		if generated_plains:
			var meta_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/meta_upgrades.json"))
			initial_character.current_health = controller.actor_resources.health.current
			initial_character.maximum_health = controller.actor_resources.health.capacity
			initial_character.permanent_upgrades = meta.snapshot().upgrades.duplicate(true)
			initial_character.meta_content_version = meta_config.version
			initial_character.meta_save_schema_version = MetaSaveService.SCHEMA_VERSION
			config_hashes.meta_upgrades = FileAccess.get_sha256("res://config/meta_upgrades.json")
			config_hashes.branch_profile = FileAccess.get_sha256(PlainsBranchLayout.PROFILE_PATH)
		director.manifest.record_configuration([
			{"id": "plains_generated_layout" if generated_plains else "demo_fixed_layout", "version": 1},
			{"id": String(JUMP_ITEM.stable_id), "version": JUMP_ITEM.definition_version},
			{"id": String(SHOT_ITEM.stable_id), "version": SHOT_ITEM.definition_version},
			{"id": String(GOLD_ITEM.stable_id), "version": GOLD_ITEM.definition_version},
			{"id": String(DAMAGE_ITEM.stable_id), "version": DAMAGE_ITEM.definition_version},
			{"id": String(RECOIL_ITEM.stable_id), "version": RECOIL_ITEM.definition_version},
			{"id": String(HEALTH_ITEM.stable_id), "version": HEALTH_ITEM.definition_version},
			{"id": String(COIN_REWARD.stable_id), "version": COIN_REWARD.definition_version},
			{"id": String(HEAL_REWARD.stable_id), "version": HEAL_REWARD.definition_version}],
			config_hashes, initial_character)
	add_child(stage)
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		if not random_stage.assembly_ok:
			abandon_run()
			return
		if not is_instance_valid(_run_camera):
			_run_camera = StageCameraRig.new()
			add_child(_run_camera)
		_run_camera.configure(player, random_stage.bounds)
	controller.return_to_segment(stage.spawn)
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	policy.player_fatal.connect(_player_fatal)
	policy.environment_return_requested.connect(_environment_return)
	policy.batch_resolved.connect(_damage_resolved.bind(policy, lifetime.stage_epoch, lifetime.epoch))
	segment = SegmentRespawn.new()
	segment.configure(controller, lifetime)
	segment.add_anchor(&"entry", stage.spawn)
	segment.add_anchor(&"midpoint", stage.anchor_position)
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		for index: int in random_stage.anchors.size():
			segment.add_anchor(StringName("generated_%s" % index), random_stage.anchors[index])
		segment.danger_bounds = random_stage.assembler.world_dangers()
		random_stage.assembler.setup_damage(controller, policy, lifetime)
		for index: int in random_stage.assembler.world_static_dangers().size():
			var danger: Rect2 = random_stage.assembler.world_static_dangers()[index]
			var emitter := _contact(stage, StringName("generated_spikes_%s" % index), DamageRequest.Kind.ENVIRONMENT, danger.size / 2)
			emitter.position = danger.get_center()
	else:
		segment.danger_bounds = [Rect2(780, 530, 80, 110)]
	await get_tree().physics_frame
	if not lifetime.accepts(loading_token) or not is_instance_valid(stage):
		return
	if not segment.activate_anchor(&"entry"):
		_status = "CONTENT ERROR / unsafe generated or fixed entry"
		abandon_run()
		return
	_hazard_contact = null
	if not generated_plains:
		_hazard_contact = _contact(stage, &"saw", DamageRequest.Kind.ENVIRONMENT, Vector2(25, 25))
		_hazard_contact.position = stage.hazard_position
	_enemy_contact = null
	_boss_contact = null
	_boss_started = false
	_boss_was_in_core = false
	_boss_eligible_shots.clear()
	policy.protect_player()
	current_reward = null
	simple_reward = null
	_pending_exit = &""
	_reward_token = null
	_offered_exit = &""
	_exit_prompt_token = null
	_dismissed_exits.clear()
	_enemy_contacts.clear()
	if generated_plains:
		var encounter_stage := stage as GeneratedDemoStage
		for index: int in encounter_stage.enemies.size():
			var drone: EnemyMotor = encounter_stage.enemies[index]
			var actor := drone.get_node("Actor") as EnemyActor
			var id := StringName(encounter_stage.enemy_manifest[index].id)
			policy.bind_damageable(id, actor.damageable, actor.health)
			_enemy_contacts.append(_contact(drone, StringName(str(id) + "_contact"), DamageRequest.Kind.MONSTER, Vector2(14, 16)))
		if not encounter_stage.enemies.is_empty():
			_completion_target = (encounter_stage.enemies[0].get_node("Actor") as EnemyActor).health
		director.manifest.record_output(director.stage_index, &"enemy_layout", encounter_stage.encounter_plan)
	elif stage.enemy != null:
		var actor := stage.enemy.get_node("Actor") as EnemyActor
		_completion_target = actor.health
		policy.bind_damageable(&"drone", actor.damageable, actor.health)
		_enemy_contact = _contact(stage.enemy, &"drone_contact", DamageRequest.Kind.MONSTER, Vector2(14, 16))
	if stage.boss != null:
		var encounter := stage.boss.get_node("Encounter")
		_completion_target = encounter.health
		if generated_plains:
			(stage.boss.get_node("Damageable") as Damageable).damage_sink = func(_context: Dictionary) -> bool: return false
		else:
			policy.bind_damageable(&"boss", stage.boss.get_node("Damageable"), encounter.health)
		if generated_plains:
			var arena := (stage as GeneratedDemoStage).boss_arena
			encounter.configure_arena(arena.position.x + 25, arena.end.x - 25, player)
		else:
			encounter.configure_arena(890.0, 1240.0, player)
		encounter.projectile_created.connect(_boss_projectile_created)
		if not generated_plains:
			encounter.activate()
		_boss_contact = _contact(stage.boss, &"boss_contact", DamageRequest.Kind.MONSTER, Vector2(25, 27))
		_boss_contact.enabled = not generated_plains
	if director.stage_type_id == &"item_reward":
		var candidates: Array[ItemDefinition] = []
		if director.profile.development_only:
			candidates.assign([JUMP_ITEM, SHOT_ITEM])
		else:
			candidates = catalog.choose_candidates(director.seed, "stage_%s" % director.stage_index)
		current_reward = rewards.create_offer(_stage_id("items"), candidates, _stage_id("room_reward"))
		if current_reward == null:
			push_error("No two valid distinct item candidates: content pool error")
			abandon_run()
			return
		director.manifest.record_output(director.stage_index, &"reward_catalog", {"version": DemoRewardCatalog.CONTENT_VERSION if not director.profile.development_only else "quick_pair_v1", "pool": DemoRewardCatalog.PLAINS_CONTENT_VERSION if generated_plains else "default"})
	elif director.stage_type_id == &"shop":
		shop.add_offer(_stage_id("shop_jump"), DAMAGE_ITEM if generated_plains else JUMP_ITEM, 5, 1)
	var simple_definitions := {&"coin_reward": COIN_REWARD, &"health_reward": HEAL_REWARD}
	if simple_definitions.has(director.stage_type_id):
		simple_reward = SimpleRoomReward.new()
		simple_reward.configure(simple_definitions[director.stage_type_id], lifetime, controller.actor_resources.health, wallet)
		stage.reward_available = true
		director.manifest.record_output(director.stage_index, &"simple_reward", {"id": String(simple_definitions[director.stage_type_id].stable_id), "kind": simple_definitions[director.stage_type_id].kind, "amount": simple_definitions[director.stage_type_id].amount})
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		var tuning_snapshot: Dictionary = {}
		var tuning_keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
		for key: String in tuning_keys:
			tuning_snapshot[key] = controller.motor.tuning.get(key)
		director.manifest.record_output(director.stage_index, &"stage_tuning", tuning_snapshot)
		director.manifest.record_output(director.stage_index, &"generated_layout", random_stage.generated.manifest)
		director.manifest.record_output(director.stage_index, &"pickups", random_stage.manifest_pickups())
		director.manifest.record_output(director.stage_index, &"stage_generator", {"version": random_stage.generated.stage_generator_version})
	else:
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
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		if not random_stage.bounds.grow(100).has_point(position_now):
			_submit_damage(&"bounds", DamageRequest.Kind.ENVIRONMENT, 1.0)
		if player.is_on_floor():
			for index: int in random_stage.anchors.size():
				if position_now.distance_to(random_stage.anchors[index]) < 38:
					segment.activate_anchor(StringName("generated_%s" % index))
		for index: int in random_stage.pickups.size():
			var pickup: Dictionary = random_stage.pickups[index]
			if not pickup.claimed and position_now.distance_to(pickup.position) < 46:
				_queue_action(_commit_pickup.bind(index))
	else:
		if position_now.y > 690 or position_now.y < -350:
			_submit_damage(&"bounds", DamageRequest.Kind.ENVIRONMENT, 1.0)
	if is_instance_valid(_hazard_contact):
		_hazard_contact.position = stage.hazard_position
	if is_instance_valid(_enemy_contact):
		_enemy_contact.enabled = not stage.enemy.get_node("Actor").health.terminal
	for contact: DemoContactEmitter in _enemy_contacts:
		if is_instance_valid(contact):
			contact.enabled = not (contact.get_parent().get_node("Actor") as EnemyActor).health.terminal
	if is_instance_valid(_boss_contact):
		if generated_plains:
			var in_core := _in_boss_core()
			if _boss_was_in_core and not in_core:
				_boss_eligible_shots.clear()
			_boss_was_in_core = in_core
			if not _boss_started and in_core and not controller.actor_resources.health.terminal:
				_start_generated_boss()
			_boss_contact.enabled = _boss_started and in_core and not stage.boss.get_node("Encounter").health.terminal
		else:
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
		if body == player and lifetime.active and is_instance_valid(policy) and (not generated_plains or (_boss_started and _in_boss_core())):
			_submit_damage(&"boss_projectile", DamageRequest.Kind.MONSTER, amount, event_id)
	)

func _damage_resolved(_results: Array[DamageResult], batch_policy: FrameDamagePolicy = null, batch_stage_epoch: int = -1, batch_run_epoch: int = -1) -> void:
	if not lifetime.active:
		_queued_actions.clear()
		return
	# Director advances synchronously; the old stage can emit an empty batch
	# before deferred loading, or while the next stage waits for its first frame.
	if _stage_pending or director.state != DemoRunDirector.State.IN_STAGE:
		return
	if batch_policy != null and (batch_policy != policy or batch_stage_epoch != lifetime.stage_epoch or batch_run_epoch != lifetime.epoch):
		return
	var was_complete := director.stage_complete
	var claimed := (current_reward != null and rewards.get_offer(current_reward.offer_id).claimed) or (simple_reward != null and simple_reward.claimed)
	var completed_now := _completion_rule.evaluate(player.global_position, _completion_target, claimed)
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		# Ordinary rooms allow leaving living enemies behind; Boss remains terminal-only.
		match _completion_rule.goal:
			StageCompletionRule.Goal.REACH_FINISH:
				completed_now = random_stage.reached_finish(player.global_position)
			StageCompletionRule.Goal.CLAIM_AND_REACH:
				completed_now = random_stage.reached_finish(player.global_position)
			StageCompletionRule.Goal.CLAIM:
				completed_now = random_stage.reached_finish(player.global_position)
	if completed_now:
		_complete_room()
	if not was_complete and director.stage_complete:
		if stage.boss != null:
			current_reward = rewards.create_gold_offer(_stage_id("gold"), GOLD_ITEM, _stage_id("boss_defeat"))
			stage.reward_position = stage.boss.global_position
			stage.reward_available = true
			_record_reward()
			if generated_plains:
				(stage as GeneratedDemoStage).show_boss_reward_portal()
			_status = "Boss defeated. Approach the GOLD gate and confirm to claim." if generated_plains else "Boss defeated. Claim the guaranteed GOLD item to finish."
	# Fixed demo reward remains a defeat fixture, independent of the newly-open
	# door policy. Opening an ordinary room must not grant entry-time money.
	if not generated_plains and stage.enemy != null and (stage.enemy.get_node("Actor") as EnemyActor).health.terminal:
		wallet.grant(10, _stage_id("combat_coins"))
	_settle_enemy_drops()
	_flush_actions()
	# Contact is observed only after this frame's damage batch and queued intents.
	if generated_plains and _can_interact() and director.stage_complete:
		var exit_index := stage.nearby_exit(player.global_position)
		if exit_index >= 0:
			_commit_exit(stage.exits[exit_index].exit_id)
		elif current_reward != null and current_reward.gold and player.global_position.distance_to(stage.reward_position) < 100:
			_offer_generated_exit(&"boss_home")
		_rearm_exit_prompts()

func _settle_enemy_drops() -> void:
	if not _can_interact() or not stage is GeneratedDemoStage or _enemy_drops == null:
		return
	var random_stage := stage as GeneratedDemoStage
	for index: int in random_stage.enemies.size():
		var enemy_motor: EnemyMotor = random_stage.enemies[index]
		var actor := enemy_motor.get_node("Actor") as EnemyActor
		if not actor.health.terminal:
			continue
		var enemy_id := StringName(random_stage.enemy_manifest[index].id)
		var output := _enemy_drops.settle(enemy_id)
		if output.is_empty():
			continue
		var location := random_stage.safe_drop_position(enemy_motor.global_position)
		output.position = [location.x, location.y]
		if output.kind != "none":
			random_stage.pickups.append({"id": "drop_" + String(enemy_id), "kind": output.kind, "amount": output.amount, "position": location, "claimed": false, "source": String(enemy_id)})
		director.manifest.record_output(director.stage_index, StringName("enemy_drop_" + String(enemy_id)), output)
		random_stage.queue_redraw()

func _complete_room() -> void:
	if not director.stage_complete and director.complete_stage(lifetime.token()):
		stage.set_completed(true)
		_status = "Room complete. Choose an exit to continue."

func _environment_return() -> void:
	_cancel_exit_ui("environment_return")
	if is_instance_valid(segment) and segment.return_to_anchor():
		policy.protect_player()
		_status = "Environment damage: returned to this segment; rewards and enemies persist."

func _player_fatal() -> void:
	controller.die()
	director.end_failure(_next_id("death"))

func _commit_interact() -> void:
	if not _can_interact():
		return
	if not generated_plains and simple_reward != null and not simple_reward.claimed and player.global_position.distance_to(stage.reward_position) < 130:
		_commit_room_reward()
		return
	if not generated_plains and not stage.supply_claimed and player.global_position.distance_to(stage.supply_position) < 80:
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
	if generated_plains:
		return _offer_generated_exit(id)
	return director.select_exit(lifetime.token(), id, _next_id("exit")).accepted()

func _commit_claim(option_id: StringName) -> bool:
	if generated_plains or not _can_interact() or current_reward == null or player.global_position.distance_to(stage.reward_position) > 130:
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
		if director.profile.development_only:
			director.finish_success(lifetime.token(), _next_id("success"), _gold_claimed)
		else:
			director.finish_biome(lifetime.token(), _next_id("biome_complete"), _gold_claimed)
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
	_status = "Purchased %s." % quote.item.display_name if receipt.accepted() else "Purchase unavailable (coins, stock or item limit)."
	_shown_actions = ""
	return receipt.accepted()

func _can_interact() -> bool:
	return lifetime.active and not _stage_pending and director.state == DemoRunDirector.State.IN_STAGE and is_instance_valid(stage) and is_instance_valid(controller) and not controller.actor_resources.health.terminal and not get_tree().paused

func toggle_pause() -> void:
	if director.state != DemoRunDirector.State.IN_STAGE or (is_instance_valid(reward_modal) and reward_modal.opened) or (is_instance_valid(exit_modal) and exit_modal.opened):
		return
	if get_tree().paused:
		menu.close_panel()
	else:
		menu.show_pause(_build_description())

func _pause_for_menu() -> void:
	if is_instance_valid(controller):
		controller.router.clear("menu")
		controller.air_focus_ability.stop()
	_queued_actions.clear()
	get_tree().paused = true
	_clear_actions()
	_shown_actions = ""

func _resume_from_menu() -> void:
	if director.state != DemoRunDirector.State.IN_STAGE or not is_instance_valid(controller):
		return
	controller.router.clear("menu_resume")
	get_tree().paused = false
	_shown_actions = ""

func apply_input_settings(patch: Dictionary) -> bool:
	var profile := InputProfile.load_default()
	if not profile.configure(_session_input) or not profile.configure(patch):
		return false
	if is_instance_valid(controller) and not controller.router.reconfigure(profile.values):
		return false
	_session_input = profile.values.duplicate(true)
	if director.state == DemoRunDirector.State.IN_STAGE and lifetime.active:
		_input_revision += 1
		director.manifest.record_output(director.stage_index, StringName("input_settings_%s" % _input_revision), {"values": _session_input.duplicate(true), "game_clock": policy.clock if is_instance_valid(policy) else 0.0})
	menu.set_input_values(_session_input)
	if is_instance_valid(home_scene):
		home_scene.controller.router.reconfigure(_session_input)
	if is_instance_valid(overlay):
		overlay.update_layout()
	return true

func _build_description() -> String:
	if build == null or not is_instance_valid(controller):
		return "No items yet."
	var items := build.item_ids()
	return "Items: %s\nJumps: %s  •  Air shots: %s\nShot damage: %.1f  •  Recoil burst: %.0f\nRun seed: %s" % [", ".join(items) if not items.is_empty() else "None", controller.motor.tuning.max_jumps, controller.motor.tuning.max_air_shots, controller.motor.tuning.projectile_damage, controller.motor.tuning.shot_burst_speed, director.seed]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		debug_hud = not debug_hud
	if director.state == DemoRunDirector.State.IN_STAGE and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and menu.visible_panel.is_empty():
		toggle_pause()
		get_viewport().set_input_as_handled()

func _open_module_lab() -> void:
	if director.state != DemoRunDirector.State.HOME or is_instance_valid(_lab) or is_instance_valid(_preview):
		return
	_remove_home_scene()
	menu.hide_home()
	_lab = MODULE_LAB.instantiate() as ModuleLab
	_lab.configure(_session_input)
	_lab.home_requested.connect(_close_module_lab)
	add_child(_lab)

func _close_module_lab() -> void:
	if not is_instance_valid(_lab):
		return
	_session_input = _lab.input_values.duplicate(true)
	menu.set_input_values(_session_input)
	_lab.queue_free()
	_lab = null
	get_tree().paused = false
	_show_home()

func _open_random_preview(seed_text: String) -> void:
	if director.state != DemoRunDirector.State.HOME or is_instance_valid(_lab) or is_instance_valid(_preview):
		return
	_remove_home_scene()
	menu.hide_home()
	_preview = RandomStagePreview.new()
	_preview.configure(_session_input, seed_text)
	_preview.home_requested.connect(_close_random_preview)
	add_child(_preview)
	queue_redraw()

func _close_random_preview() -> void:
	if not is_instance_valid(_preview):
		return
	_session_input = _preview.input_values.duplicate(true)
	menu.set_input_values(_session_input)
	_preview.queue_free()
	_preview = null
	queue_redraw()
	get_tree().paused = false
	_show_home()

func abandon_run() -> void:
	if director.state == DemoRunDirector.State.IN_STAGE:
		controller.router.clear("abandon")
		controller.air_focus_ability.stop()
		get_tree().paused = false
		director.end_failure(_next_id("abandon"))

func _run_ended(result: DemoRunResult) -> void:
	var generation_failure := _status if _status.begins_with("GENERATION FAILED") else ""
	_cancel_exit_ui("run_end")
	_pending_exit = &""
	_reward_token = null
	if is_instance_valid(reward_modal):
		reward_modal.close()
	_queued_actions.clear()
	var summary := {"stage": director.stage_index, "items": build.item_ids(), "run_coins_discarded": wallet.balance, "seed": director.seed}
	var settlement_id := StringName("%s/run_%s_%s" % [_run_receipt_prefix, result.run_epoch, result.event_id])
	var settled := meta.settle_biome(settlement_id, summary) if result.reason == &"biome_complete" else meta.settle(settlement_id, result.reason == &"success", summary)
	_status = "BIOME COMPLETE / GOLD CLAIMED" if result.reason == &"biome_complete" else ("VICTORY / GOLD CLAIMED" if result.reason == &"success" else "RUN ENDED / RETURNED HOME")
	if not generation_failure.is_empty():
		_status += " / " + generation_failure
	if not settled:
		_status += " / HOME SUMMARY SAVE FAILED (banked notes unchanged)"
	controller.router.clear("run_end")
	controller.air_focus_ability.stop()
	controller.active = false
	call_deferred("_cleanup_run")

func _cleanup_run() -> void:
	get_tree().paused = false
	_resources_hud.unbind()
	build.clear()
	wallet.balance = 0
	for object: Node in [stage, policy, player, _run_camera]:
		if is_instance_valid(object):
			if object.get_parent() == self:
				remove_child(object)
			object.queue_free()
	_run_camera = null
	stage = null
	player = null
	controller = null
	policy = null
	segment = null
	director.return_home()
	_show_home()

func _hide_run_hud() -> void:
	_hud_frame.hide()
	_resources_hud.hide()
	_pause_button.hide()
	_hud.text = ""
	_hint.text = ""
	_title.text = ""
	_status_label.text = ""
	_clear_actions()

func _refresh_home_meta() -> void:
	var snapshot := meta.snapshot()
	snapshot.upgrade_quote = meta.upgrade_quote()
	menu.set_meta_state(snapshot)
	if is_instance_valid(home_scene):
		home_scene.set_meta_state(snapshot)

func _show_home() -> void:
	if director.state != DemoRunDirector.State.HOME or is_instance_valid(_lab) or is_instance_valid(_preview):
		return
	get_tree().paused = false
	_hide_run_hud()
	menu.hide_home()
	if not is_instance_valid(home_scene):
		home_scene = HomeScene.new()
		home_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(home_scene)
		home_scene.controller.router.reconfigure(_session_input)
		home_scene.controller.actor_resources.health_definition = meta.fresh_health_definition(home_scene.controller.actor_resources.health_definition)
		home_scene.controller.actor_resources.health.configure(home_scene.controller.actor_resources.health_definition)
		home_scene.requested_interaction.connect(_open_home_function)
		home_scene.requested_navigation.connect(_open_home_navigation)
	_refresh_home_meta()
	home_scene.set_input_blocked(false)
	queue_redraw()

func _remove_home_scene() -> void:
	if is_instance_valid(home_scene):
		home_scene.set_input_blocked(true)
		remove_child(home_scene)
		home_scene.queue_free()
		home_scene = null

func _open_home_function(id: StringName) -> void:
	if not is_instance_valid(home_scene) or director.state != DemoRunDirector.State.HOME:
		return
	home_scene.set_input_blocked(true)
	_refresh_home_meta()
	menu.show_home_panel(id)

func _open_home_navigation() -> void:
	if not is_instance_valid(home_scene) or director.state != DemoRunDirector.State.HOME:
		return
	home_scene.set_input_blocked(true)
	_refresh_home_meta()
	var snapshot := meta.snapshot()
	menu.show_home_navigation("%s\nBiomes cleared %s / Runs ended %s" % [_status, snapshot.completed_biomes, snapshot.failed_runs])

func _close_home_panel() -> void:
	if is_instance_valid(home_scene) and director.state == DemoRunDirector.State.HOME:
		get_tree().paused = false
		home_scene.set_input_blocked(false)

func _process(_delta: float) -> void:
	_status_label.text = _status if director.state == DemoRunDirector.State.IN_STAGE else ""
	if director.state != DemoRunDirector.State.IN_STAGE or not is_instance_valid(controller) or _stage_pending:
		return
	_title.text = "GUNMAN RUSH / ROOM %s OF %s / %s" % [director.stage_index, director.profile.stages_per_biome, String(director.stage_type_id).to_upper()]
	_hud.text = "COINS %s | NOTES %s | JUMPS %s | AIR SHOTS %s | BUILD %s" % [wallet.balance, meta.snapshot().get("notes", 0), controller.motor.tuning.max_jumps, controller.action_resources.shot_charges, build.item_ids().size()]
	_hint.text = _device_hint()
	if generated_plains:
		var random_stage := stage as GeneratedDemoStage
		var route_index := random_stage.assembler.module_index_at(player.global_position) + 1
		var flow := "LEFT" if random_stage.generated.manifest.nodes[0].mirrored else "RIGHT"
		_status_label.text += "\nROUTE %s / %s | WORLD X %.0f | CAMERA X %.0f | FLOW %s" % [route_index, random_stage.assembler.modules.size(), player.global_position.x, _run_camera.global_position.x, flow]
	_hint.visible = debug_hud
	_status_label.visible = debug_hud or "FAILED" in _status
	_hud_frame.size.y = 180 if debug_hud else 112
	_actions.position.y = 196 if debug_hud else 126
	_pause_button.visible = not overlay.enabled
	_update_actions()

func _device_hint() -> String:
	if controller.router.current_device == &"touch":
		return "Left stick: move / up: interact | JUMP: tap or hold | Right stick: aim, RELEASE to fire"
	if controller.router.current_device == &"gamepad":
		return "Left stick: move | Jump button: tap / hold | Right stick: aim, return to center to fire"
	return "A/D: move | Space: tap / hold jump | Mouse: aim, RELEASE left button to fire | W: interact"

func _update_actions() -> void:
	var key := ""
	if get_tree().paused:
		return
	elif not generated_plains and current_reward != null and not rewards.get_offer(current_reward.offer_id).claimed and player.global_position.distance_to(stage.reward_position) < 130:
		key = "reward:" + str(current_reward.offer_id)
	elif not generated_plains and simple_reward != null and not simple_reward.claimed and player.global_position.distance_to(stage.reward_position) < 130:
		key = "simple_reward"
	elif director.stage_type_id == &"shop" and player.global_position.distance_to(stage.reward_position) < 130:
		key = "shop"
	elif not generated_plains and not stage.supply_claimed and player.global_position.distance_to(stage.supply_position) < 80:
		key = "supply"
	elif not generated_plains and stage.nearby_exit(player.global_position) >= 0:
		key = "exit:" + str(stage.nearby_exit(player.global_position))
	if key == _shown_actions:
		return
	_shown_actions = key
	_clear_actions()
	if key.begins_with("reward:"):
		for item: ItemDefinition in current_reward.candidates:
			var selected_id := item.stable_id
			_button(_actions, item.display_name, func() -> void: claim_item(selected_id))
	elif key == "simple_reward":
		_button(_actions, "CLAIM COINS" if director.stage_type_id == &"coin_reward" else "RESTORE HEALTH", claim_room_reward)
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
	exit_modal = EXIT_MODAL.new()
	add_child(exit_modal)
	exit_modal.entered.connect(_confirm_generated_exit)
	exit_modal.stayed.connect(_stay_generated_exit)
	reward_modal = StageRewardModal.new()
	add_child(reward_modal)
	reward_modal.item_selected.connect(_claim_modal_item)
	_canvas = CanvasLayer.new()
	_canvas.layer = 2
	add_child(_canvas)
	_hud_frame = Panel.new()
	_hud_frame.position = Vector2(12, 8)
	_hud_frame.size = Vector2(670, 112)
	_hud_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.045, 0.09, 0.13, 0.9)
	frame_style.border_color = Color(0.2, 0.45, 0.49, 0.65)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(8)
	_hud_frame.add_theme_stylebox_override("panel", frame_style)
	_canvas.add_child(_hud_frame)
	_title = _label(Vector2(22, 14), 18)
	_hud = _label(Vector2(22, 42), 15)
	_hint = _label(Vector2(22, 108), 14)
	_status_label = _label(Vector2(22, 134), 15)
	_resources_hud = ActorResourcesHud.new()
	_canvas.add_child(_resources_hud)
	_pause_button = Button.new()
	_pause_button.text = "MENU"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.position = Vector2(1150, 75)
	_pause_button.size = Vector2(108, 45)
	_pause_button.pressed.connect(toggle_pause)
	_canvas.add_child(_pause_button)
	var debug_button := Button.new()
	debug_button.text = "INFO"
	debug_button.position = Vector2(600, 12)
	debug_button.size = Vector2(66, 32)
	debug_button.theme = DemoMenu.create_theme()
	debug_button.pressed.connect(func() -> void: debug_hud = not debug_hud)
	_hud_frame.add_child(debug_button)
	_actions = HBoxContainer.new()
	_actions.position = Vector2(360, 178)
	_actions.add_theme_constant_override("separation", 16)
	_canvas.add_child(_actions)
	menu = DemoMenu.new()
	add_child(menu)
	menu.set_input_values(_session_input)
	menu.requested_enter_home.connect(_show_home)
	menu.home_panel_closed.connect(_close_home_panel)
	menu.requested_start.connect(start_demo)
	menu.requested_plains.connect(start_plains)
	menu.requested_upgrade.connect(_purchase_meta_upgrade)
	menu.requested_lab.connect(_open_module_lab)
	menu.requested_random.connect(_open_random_preview)
	menu.requested_resume.connect(_resume_from_menu)
	menu.requested_home.connect(abandon_run)
	menu.settings_changed.connect(apply_input_settings)
	menu.menu_opened.connect(_pause_for_menu)

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
	# The viewport backdrop is shared by Home, fixed rooms and module practice.
	# No world-sized opaque rectangle may cover it when the camera moves.
	pass

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

func claim_room_reward() -> bool:
	return _queue_action(_commit_room_reward)

func _commit_room_reward() -> bool:
	if generated_plains or not _can_interact() or simple_reward == null or player.global_position.distance_to(stage.reward_position) > 130:
		return false
	var result := simple_reward.claim(lifetime.token(), _next_id("room_reward"))
	if not result.accepted():
		return false
	stage.reward_available = false
	director.manifest.record_output(director.stage_index, &"simple_reward_claim", {"amount_applied": result.amount_applied, "coins": result.coins, "health": result.current_health, "max_health": result.maximum_health})
	_status = "Reward claimed. Choose your next exit."
	_shown_actions = ""
	return true

func _commit_pickup(index: int) -> bool:
	if not _can_interact() or not stage is GeneratedDemoStage:
		return false
	var random_stage := stage as GeneratedDemoStage
	if index < 0 or index >= random_stage.pickups.size():
		return false
	var pickup: Dictionary = random_stage.pickups[index]
	if pickup.claimed or player.global_position.distance_to(pickup.position) >= 46:
		return false
	var receipt_id := StringName("%s/stage_%s/%s" % [_run_receipt_prefix, director.stage_index, pickup.id])
	if pickup.kind == "coin":
		if not wallet.grant(pickup.amount, receipt_id):
			return false
		random_stage.coins_collected += pickup.amount
	elif pickup.kind == "heart":
		if controller.actor_resources.health.current >= controller.actor_resources.health.capacity:
			return false
		var healed := SupplyHealEffect.apply(controller.actor_resources.health, float(pickup.amount), receipt_id)
		if not healed.accepted():
			return false
		if pickup.id == "supply_heart":
			random_stage.mark_supply_used()
	elif pickup.kind == "note":
		var receipt := meta.grant_notes(pickup.amount, receipt_id)
		if not receipt.accepted:
			_status = "NOTES SAVE FAILED / " + str(receipt.reason)
			return false
	else:
		return false
	pickup.claimed = true
	var feedback := player.get_node_or_null("PlayerFeedback") as PlayerFeedback
	if feedback != null:
		feedback.reward_received(pickup.position, pickup.kind == "note")
	director.manifest.record_output(director.stage_index, StringName("pickup_claim_" + str(pickup.id)), {"id": pickup.id, "kind": pickup.kind, "amount": pickup.amount})
	return true

func _purchase_meta_upgrade() -> void:
	if director.state != DemoRunDirector.State.HOME:
		return
	_meta_purchase_sequence += 1
	var result := meta.purchase_upgrade("vitality", StringName("%s/upgrade_%s" % [meta.new_run_receipt_prefix(), _meta_purchase_sequence]))
	_status = "Permanent vitality improved. Next run begins with more health." if result.accepted else "Upgrade unavailable: " + str(result.reason)
	if is_instance_valid(home_scene):
		_refresh_home_meta()
		menu.show_home_panel(&"upgrade")
	else:
		_show_home()

func _in_boss_core() -> bool:
	return generated_plains and is_instance_valid(stage) and stage is GeneratedDemoStage and is_instance_valid(player) and (stage as GeneratedDemoStage).boss_arena.has_point(player.global_position)

func _record_boss_shot(_direction: Vector2, shot_id: int) -> void:
	if generated_plains and _boss_started and _in_boss_core() and lifetime.active:
		_boss_eligible_shots["%s:%s" % [controller.session_id, shot_id]] = lifetime.actor_epoch

func _start_generated_boss() -> void:
	var encounter := stage.boss.get_node("Encounter") as BossEncounter
	var receiver := stage.boss.get_node("Damageable") as Damageable
	if not policy.bind_damageable(&"boss", receiver, encounter.health):
		return
	var sink := receiver.damage_sink
	receiver.damage_sink = func(context: Dictionary) -> bool:
		var key := "%s:%s" % [context.get("session_id", -1), context.get("shot_id", -1)]
		return _boss_started and _in_boss_core() and lifetime.active and _boss_eligible_shots.get(key, -1) == lifetime.actor_epoch and sink.call(context) == true
	_boss_started = encounter.activate()
	if _boss_started:
		_status = "BOSS ACTIVE / Core entered. Retreat into the entrance is safe; Boss health persists."


func _exit_location(id: StringName) -> Vector2:
	if id == &"boss_home":
		return stage.reward_position
	for index: int in stage.exits.size():
		if stage.exits[index].exit_id == id:
			return stage.exit_positions[index]
	return Vector2.INF

func _rearm_exit_prompts() -> void:
	for id: StringName in _dismissed_exits.keys():
		if player.global_position.distance_to(_exit_location(id)) > 145:
			_dismissed_exits.erase(id)

func _offer_generated_exit(id: StringName) -> bool:
	if not _can_interact() or not director.stage_complete or not _pending_exit.is_empty() or _dismissed_exits.has(id):
		return false
	var next_label := "HOME / BIOME COMPLETE" if id == &"boss_home" else ""
	for exit: ExitOffer in stage.exits:
		if exit.exit_id == id:
			next_label = exit.label
	if next_label.is_empty() or player.global_position.distance_to(_exit_location(id)) > 100:
		return false
	_offered_exit = id
	_exit_prompt_token = lifetime.token()
	controller.router.clear("exit_confirmation")
	controller.air_focus_ability.stop()
	_queued_actions.clear()
	_clear_actions()
	var summary := "Reward: exploration pickups already collected"
	if current_reward != null:
		summary = "Reward: guaranteed GOLD item" if current_reward.gold else "Reward: choose ONE of TWO items"
	elif simple_reward != null:
		summary = "Reward: +%s COINS" % COIN_REWARD.amount if director.stage_type_id == &"coin_reward" else "Reward: restore current health (+%s HP)" % HEAL_REWARD.amount
	elif stage.stage_type == &"combat":
		summary = "Reward: +10 COINS"
	get_tree().paused = true
	exit_modal.show_exit(next_label, summary)
	return true

func _confirm_generated_exit() -> bool:
	if not exit_modal.opened:
		return false
	if not lifetime.accepts(_exit_prompt_token) or controller.actor_resources.health.terminal:
		_cancel_exit_ui("stale_exit")
		return false
	var chosen := _offered_exit
	exit_modal.close()
	_offered_exit = &""
	_exit_prompt_token = null
	controller.router.clear("exit_confirmed")
	get_tree().paused = false
	_resume_exit_input()
	return _enter_generated_exit(chosen)

func _resume_exit_input() -> void:
	if is_instance_valid(player):
		var keyboard := player.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
		keyboard.observe_current_key_neutral()

func _stay_generated_exit() -> void:
	if not _offered_exit.is_empty():
		_dismissed_exits[_offered_exit] = true
	_cancel_exit_ui("exit_stay")

func _cancel_exit_ui(reason: String) -> void:
	_offered_exit = &""
	_exit_prompt_token = null
	_pending_exit = &""
	_reward_token = null
	if is_instance_valid(exit_modal):
		exit_modal.close()
	if is_instance_valid(reward_modal):
		reward_modal.close()
	if is_instance_valid(controller):
		controller.router.clear(reason)
		controller.air_focus_ability.stop()
	get_tree().paused = false
	_resume_exit_input()

func _enter_generated_exit(id: StringName) -> bool:
	if not director.stage_complete or not _pending_exit.is_empty() or controller.actor_resources.health.terminal:
		return false
	_pending_exit = id
	_reward_token = lifetime.token()
	# Non-choice rewards settle at the selected exit, never at a pre-exit marker.
	if simple_reward != null and not simple_reward.claimed:
		var result := simple_reward.claim(_reward_token, _next_id("exit_reward"))
		if not result.accepted():
			_pending_exit = &""
			return false
		stage.reward_available = false
		director.manifest.record_output(director.stage_index, &"simple_reward_claim", {"amount_applied": result.amount_applied, "coins": result.coins, "health": result.current_health, "max_health": result.maximum_health})
	if stage.stage_type == &"combat":
		wallet.grant(10, _stage_id("combat_coins"))
	if current_reward != null and not rewards.get_offer(current_reward.offer_id).claimed:
		controller.router.clear("exit_reward")
		controller.air_focus_ability.stop()
		_queued_actions.clear()
		_clear_actions()
		get_tree().paused = true
		var next_label := "Home" if current_reward.gold else "next room"
		for exit: ExitOffer in stage.exits:
			if exit.exit_id == id:
				next_label = "Home" if current_reward.gold else exit.label
		reward_modal.show_offer(current_reward, next_label)
		return true
	return _finish_generated_exit()

func _claim_modal_item(option_id: StringName) -> bool:
	if not generated_plains or not reward_modal.opened or not lifetime.accepts(_reward_token) or controller.actor_resources.health.terminal:
		return false
	var request := RewardClaimRequest.new()
	request.token = _reward_token
	request.offer_id = current_reward.offer_id
	request.option_id = option_id
	request.claim_id = _next_id("exit_claim")
	var receipt := rewards.claim(request)
	if not receipt.accepted():
		return false
	director.manifest.record_output(director.stage_index, &"reward_claim", {"offer": String(current_reward.offer_id), "item": String(receipt.item_id), "at_exit": String(_pending_exit)})
	reward_modal.close()
	controller.router.clear("exit_reward_complete")
	get_tree().paused = false
	if current_reward.gold:
		_gold_claimed = true
		return director.finish_biome(_reward_token, _next_id("biome_complete"), true).accepted()
	return _finish_generated_exit()

func _finish_generated_exit() -> bool:
	if _pending_exit.is_empty() or not lifetime.accepts(_reward_token) or controller.actor_resources.health.terminal:
		return false
	var id := _pending_exit
	return director.select_exit(_reward_token, id, _next_id("exit")).accepted()
