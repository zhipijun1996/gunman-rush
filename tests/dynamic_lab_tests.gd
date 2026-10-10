extends RefCounted
## Dynamic module consumer regressions, not platforming reachability evidence.
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
	var lab: ModuleLab = app._lab
	check.call(lab != null and lab.ready_for_play, "dynamic tests enter the real Module Lab from Home")
	if lab == null or not lab.ready_for_play:
		await cleanup(app)
		return
	for id: StringName in [&"timed_gallery", &"moving_transfer"]:
		check.call(lab.request_module(id), "Lab accepts the dynamic module " + str(id))
		await frames(6)
		check.call(lab.ready_for_play and lab.module_id == id and lab.player.is_on_floor(), "dynamic Lab entry settles safely for " + str(id))
		if not lab.ready_for_play:
			continue
		var instance := lab.module
		var attempt := lab.attempt
		var clock_before := instance.clock
		await frames(12)
		check.call(instance.clock > clock_before, "dynamic module world clock advances through real physics frames")
		lab.take_supply()
		await frames(2)
		check.call(lab.supply_claimed, "dynamic Lab entry supply is claimed once through its real interaction")
		var hp_before := lab.controller.actor_resources.health.current
		lab.policy.clock += 2.0
		clock_before = instance.clock
		var actor_before := lab.lifetime.actor_epoch
		check.call(submit_damage(lab, &"dynamic_return", 1.0), "dynamic environmental fixture enters the real frame damage policy")
		lab.policy.resolve_batch()
		check.call(lab.module == instance and lab.attempt == attempt and instance.clock == clock_before, "selective return retains the dynamic instance and exact phase without resetting its clock")
		check.call(lab.controller.actor_resources.health.current == hp_before - 1.0 and lab.lifetime.actor_epoch == actor_before + 1 and lab.supply_claimed, "dynamic return spends HP and preserves the used supply ledger")
		await frames(10)
		check.call(instance.clock > clock_before, "moving world resumes its preserved phase after selective return")
		lab.take_supply()
		await frames(2)
		check.call(lab.controller.actor_resources.health.current == hp_before - 1.0, "dynamic selective return cannot duplicate the entry supply heal")
		# Pass the authored platform endpoint dwell before checking movement.
		await frames(65)
		var advancing_positions := dynamic_positions(instance)
		await frames(12)
		check.call(not advancing_positions.is_empty() and dynamic_positions(instance) != advancing_positions, "real dynamic hazard or carrying platform advances its physical position before Pause")
		lab.toggle_pause()
		clock_before = instance.clock
		var position_before := lab.player.global_position
		var phase_positions := dynamic_positions(instance)
		lab.controller.shoot_ability.cooldown_remaining = 0.4
		await frames(10)
		check.call(tree.paused and instance.clock == clock_before and lab.player.global_position == position_before, "Pause freezes dynamic world clock and player together")
		check.call(dynamic_positions(instance) == phase_positions and lab.controller.shoot_ability.cooldown_remaining == 0.4, "Pause freezes physical mover positions and player shot cooldown together")
		lab.menu.close_panel()
		await frames(4)
		check.call(not tree.paused and instance.clock > clock_before, "Resume continues the existing dynamic phase")
		# A shared engine scale is the AirFocus world-time mechanism. Compare
		# actual clocks over equal physics ticks; do not call module tick manually.
		clock_before = instance.clock
		var policy_before := lab.policy.clock
		await frames(12)
		var normal_delta := instance.clock - clock_before
		Engine.time_scale = 0.25
		# physics_frame is emitted before node ticks; settle the new engine
		# scale before measuring an equal window of completed ticks.
		await frames(2)
		clock_before = instance.clock
		policy_before = lab.policy.clock
		await frames(12)
		var slowed_delta := instance.clock - clock_before
		var slowed_policy := lab.policy.clock - policy_before
		Engine.time_scale = 1.0
		check.call(normal_delta > 0.0 and absf(slowed_delta / normal_delta - 0.25) < 0.04, "global slow time reduces actual dynamic world phase advance by the same scale")
		check.call(absf(slowed_delta - slowed_policy) < 0.01, "hazard world clock and damage protection clock share scaled gameplay time")
		if id == &"timed_gallery":
			check.call(not instance.hazards.is_empty(), "timed gallery instantiates real damaging hazard consumers")
			if not instance.hazards.is_empty():
				# Negative collision fixture only: teleport into the real saw's
				# body to test damage routing, never call its damage method.
				var hazard: ModuleSawHazard = instance.hazards[0]
				lab.policy.clock += 2.0
				var contact_hp := lab.controller.actor_resources.health.current
				var contact_epoch := lab.lifetime.actor_epoch
				lab.player.global_position = hazard.global_position
				lab.player.reset_motion()
				hazard._actor_epoch = -1
				await frames(3)
				check.call(lab.controller.actor_resources.health.current == contact_hp - hazard.definition.damage and lab.lifetime.actor_epoch == contact_epoch + 1, "actual saw overlap deducts HP and triggers selective segment return")
				check.call(lab.module == instance and lab.supply_claimed and lab.player.global_position.distance_to(instance.world_entry()) < 2.0, "actual saw return preserves world instance and used supply at its safe start")
		var old_token := lab.lifetime.token()
		var old_instance_id := instance.get_instance_id()
		lab.restart_module()
		await frames(6)
		check.call(lab.ready_for_play and lab.module.get_instance_id() != old_instance_id and lab.attempt == attempt + 1 and not lab.lifetime.accepts(old_token), "explicit Retry replaces the dynamic module and invalidates old attempt callbacks")
		check.call(lab.module.clock < 0.15 and not lab.supply_claimed and lab.controller.actor_resources.health.current == 5.0, "explicit Retry starts initial phase and fresh resources unlike selective return")
	# Death wins over a queued supply and cancels all old dynamic actor tokens.
	var fatal_life := lab.lifetime
	var fatal_token := fatal_life.token()
	lab.take_supply()
	lab.policy.clock += 2.0
	check.call(submit_damage(lab, &"dynamic_fatal", 99.0), "fatal dynamic damage submits through the real policy")
	lab.policy.resolve_batch()
	await frames(4)
	check.call(app._lab == null and is_instance_valid(app.home_scene) and app.menu.visible_panel.is_empty() and not fatal_life.accepts(fatal_token), "dynamic death returns Home and invalidates old delayed callback tokens")
	check.call(app.meta.snapshot() == meta_before, "dynamic practice neither grants nor removes permanent run progress")
	await cleanup(app)

func dynamic_positions(module: PlatformingModule) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for node: Node2D in module.moving_platforms:
		result.append(node.global_position)
	for node: Node2D in module.hazards:
		result.append(node.global_position)
	return result

func submit_damage(lab: ModuleLab, event_id: StringName, amount: float) -> bool:
	var request := DamageRequest.new()
	request.token = lab.lifetime.token()
	request.event_id = event_id
	request.source_id = &"dynamic_lab_integration"
	request.target_id = &"player"
	request.kind = DamageRequest.Kind.ENVIRONMENT
	request.amount = amount
	request.health_epoch = lab.controller.actor_resources.health.epoch
	request.actor_epoch = lab.lifetime.actor_epoch
	return lab.policy.submit(request)

func frames(count: int) -> void:
	for unused: int in count:
		await tree.physics_frame

func cleanup(app: DemoApp) -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	if app._lab != null:
		app._close_module_lab()
	app.queue_free()
	await tree.process_frame
