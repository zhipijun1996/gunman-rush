extends RefCounted
## Position changes below are encounter-state fixtures, not reachability proof.
const DEMO := preload("res://scenes/demo/demo.tscn")
var tree: SceneTree
var check: Callable
func run(scene_tree: SceneTree, assertion: Callable) -> void:
	tree = scene_tree
	check = assertion
	var app: DemoApp = DEMO.instantiate()
	app.meta_persistence_enabled = false
	tree.root.add_child(app)
	await frames(2)
	var meta_before := app.meta.snapshot().duplicate(true)
	app._open_module_lab()
	await frames(6)
	var lab := app._lab
	check.call(lab.request_module(&"square_loop"), "lab exposes square-loop module selection")
	await frames(6)
	check.call(lab.ready_for_play and lab.boss_trial == null, "square-loop practice uses ordinary safe module gameplay without a boss")
	lab.request_module(&"boss_approach")
	await frames(6)
	var trial := lab.boss_trial
	check.call(trial != null and lab.ready_for_play, "boss-approach practice loads the real independent boss encounter")
	if trial == null:
		app.queue_free()
		await frames(2)
		return
	var encounter := trial.encounter
	var initial_health := encounter.health.current
	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = (trial.boss.get_node("CollisionShape2D") as CollisionShape2D).shape
	shape_query.transform = trial.boss.global_transform
	shape_query.collision_mask = 1
	shape_query.exclude = [trial.boss.get_rid()]
	check.call(trial.boss.get_world_2d().direct_space_state.intersect_shape(shape_query, 8).is_empty(), "actual full guardian collision shape spawns clear of fixed core floor and overhead platform")
	await frames(35)
	check.call(not trial.started and not encounter.active and encounter._attack_serial == 0, "waiting in preparation never activates a boss attack or projectile")
	lab.player.global_position = Vector2(840, 582)
	lab.player.reset_motion()
	await frames(3)
	check.call(not lab.finished, "pre-battle exit proximity cannot clear a boss practice module")
	lab.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	await frames(25)
	check.call(lab.controller.shoot_ability._shot_serial == 1 and encounter.health.current == initial_health, "real release-fired projectile from preparation cannot damage inactive boss")
	# Real collision and grounded gate condition, with no automatic clear at exit.
	lab.player.global_position = Vector2(910, 582)
	lab.player.reset_motion()
	await frames(3)
	check.call(trial.started and encounter.active and lab.player.is_on_floor(), "grounded entry to core activates the existing real BossEncounter once")
	lab.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	await frames(10)
	check.call(encounter.health.current < initial_health, "actual InputRouter release shot collides with boss and resolves through FrameDamagePolicy")
	var hurt_health := encounter.health.current
	check.call(lab.player.global_position.x < 890.0, "core-origin projectile remains valid through actual recoil moving shooter back into buffer")
	lab.player.global_position = Vector2(720, 582)
	lab.player.reset_motion()
	await frames(3)
	check.call(trial.started and encounter.health.current == hurt_health, "retreat to buffer keeps boss activation and depleted HP instead of resetting encounter")
	await frames(20)
	lab.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	await frames(20)
	check.call(encounter.health.current == hurt_health, "real new release shot from buffer cannot damage already activated boss")
	lab.policy.clock += 2.0
	lab.controller.actor_resources.stamina.consume_continuous(8.0, lab.controller.actor_resources.stamina.epoch)
	var focus_before := lab.controller.actor_resources.stamina.current
	lab.controller.shoot_ability.cooldown_remaining = 0.4
	var phase_before := encounter.phases.phase
	var same_boss := trial.boss
	check.call(submit(lab, &"player", &"practice_environment_fixture", 1.0, true), "boss practice environmental damage enters the real deterministic policy")
	lab.policy.resolve_batch()
	check.call(trial.boss == same_boss and encounter.health.current == hurt_health and encounter.phases.phase == phase_before and trial.started, "segment return preserves boss instance HP phase and activation")
	check.call(lab.controller.actor_resources.stamina.current == focus_before and lab.controller.shoot_ability.cooldown_remaining == 0.4, "boss segment return preserves independent focus and weapon cooldown")
	# Pause must freeze both attack pattern and pending reward interactions.
	lab.toggle_pause()
	var clock_before := lab.elapsed
	var attack_before := encounter._attack_serial
	await frames(4)
	check.call(tree.paused and lab.elapsed == clock_before and encounter._attack_serial == attack_before, "practice pause freezes clock and real boss attacks")
	lab.menu.close_panel()
	await frames(2)
	# Negative fixture defeats the existing health owner through the same batch.
	check.call(submit(lab, &"practice_boss", &"fixture_boss_defeat", 999.0), "boss defeat fixture submits through the shared damage batch")
	lab.policy.resolve_batch()
	check.call(trial.offer != null and trial.offer.gold and trial.offer.candidates.size() == 1 and trial.offer.candidates[0].rarity == ItemDefinition.Rarity.GOLD, "live post-batch boss defeat creates exactly one guaranteed GOLD practice offer")
	var offer_id := trial.offer.offer_id
	lab.policy.resolve_batch()
	check.call(trial.offer.offer_id == offer_id and not trial.claimed, "repeated resolution cannot generate or automatically claim another gold reward")
	lab.player.global_position = trial.reward_position + Vector2(0, 9)
	lab.player.reset_motion()
	await frames(3)
	trial.queue_claim()
	await frames(2)
	check.call(trial.claimed and trial.build.count_item(trial.GOLD.stable_id) == 1, "nearby practice gold claim uses the real RewardService and local BuildState once")
	trial.queue_claim()
	await frames(2)
	check.call(trial.build.count_item(trial.GOLD.stable_id) == 1 and app.meta.snapshot() == meta_before and app.director.state == DemoRunDirector.State.HOME, "duplicate gold input neither stacks another reward nor changes run or permanent progress")
	lab.policy.clock += 2.0
	check.call(submit(lab, &"player", &"post_gold_environment", 1.0, true), "post-claim environmental return remains supported")
	lab.policy.resolve_batch()
	check.call(trial.claimed and trial.build.count_item(trial.GOLD.stable_id) == 1 and trial.rewards.get_offer(offer_id).claimed, "environmental return preserves claimed gold ledger rather than enabling farming")
	var old_token := lab.lifetime.token()
	lab.restart_module()
	await frames(6)
	trial = lab.boss_trial
	check.call(not lab.lifetime.accepts(old_token) and not trial.started and trial.offer == null and trial.build.item_ids().is_empty(), "explicit practice Retry resets local build and encounter while invalidating old reward tokens")
	# Same-frame deaths use player-fatal priority regardless of target sorting.
	lab.player.global_position = Vector2(910, 582)
	lab.player.reset_motion()
	await frames(3)
	lab.policy.clock += 2.0
	check.call(submit(lab, &"practice_boss", &"simultaneous_boss", 999.0) and submit(lab, &"player", &"simultaneous_player", 999.0), "same-frame player and boss fatal requests both enter the common batch")
	lab.policy.resolve_batch()
	check.call(trial.encounter.health.terminal and not lab.lifetime.active and trial.offer == null, "same-frame player death ends lifetime before any gold offer is created")
	await frames(4)
	check.call(app._lab == null and is_instance_valid(app.home_scene) and app.menu.visible_panel.is_empty() and app.meta.snapshot() == meta_before, "fatal boss practice returns Home without granting any run or permanent outcome")
	app.queue_free()
	await frames(2)

func frames(count: int) -> void:
	for _index: int in count:
		await tree.physics_frame

func submit(lab: ModuleLab, target: StringName, id: StringName, amount: float, environmental: bool = false) -> bool:
	var request := DamageRequest.new()
	request.token = lab.lifetime.token()
	request.actor_epoch = lab.lifetime.actor_epoch
	request.health_epoch = lab.controller.actor_resources.health.epoch if target == &"player" else lab.boss_trial.encounter.health.epoch
	request.target_id = target
	request.source_id = id
	request.event_id = id
	request.amount = amount
	request.kind = DamageRequest.Kind.ENVIRONMENT if environmental else DamageRequest.Kind.MONSTER
	return lab.policy.submit(request)
