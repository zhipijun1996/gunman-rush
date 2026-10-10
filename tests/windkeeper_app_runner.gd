extends SceneTree
## Explicit Boss8 outcome fixture, not traversal through eight rooms.
var assertions := 0
var failures := 0
var app: DemoApp
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i: int in count: await physics_frame
func fixture() -> void:
	if is_instance_valid(app): app.free()
	paused = false
	app = preload("res://scenes/demo/demo.tscn").instantiate()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(2)
	app.start_plains("windkeeper-app-fixture")
	await frames(5)
	# Fill explicit fixture metadata while loading only the final formal stage.
	for index: int in range(2,9): app.director._enter_stage(index,&"boss" if index == 8 else &"combat")
	app.lifetime.stage_epoch += 7
	app.lifetime.actor_epoch += 7
	app._load_stage()
	await frames(8)
	var stage := app.stage as GeneratedDemoStage
	check(stage.boss.get_node("Encounter") is WindkeeperEncounter, "formal Boss8 loads actual giant sheep")
	app.player.reset_at(stage.boss_arena.position + Vector2(540,202))
	await frames(2)
	check(app._boss_started, "formal core entry activates actual sheep")
	var encounter := stage.boss.get_node("Encounter") as WindkeeperEncounter
	encounter.health.apply_damage(ActorResourceRequest.new(&"fixture_phase3",encounter.health.epoch,8,encounter.health.get_instance_id()))
	await frames(3)
	check(encounter.stage_phase == 3, "formal phaseIII lifecycle executes")
func submit(id: StringName, amount: float, health: HealthState,event: StringName) -> void:
	var request := DamageRequest.new()
	request.token = app.lifetime.token()
	request.actor_epoch = app.lifetime.actor_epoch
	request.health_epoch = health.epoch
	request.source_id = &"explicit_outcome_fixture"
	request.target_id = id
	request.event_id = event
	request.amount = amount
	check(app.policy.submit(request), "explicit fixture damage is eligible for real frame batch")
func run() -> void:
	await fixture()
	var stage := app.stage as GeneratedDemoStage
	var encounter := stage.boss.get_node("Encounter") as WindkeeperEncounter
	submit(&"boss",4,encounter.health,&"fixture_defeat")
	await frames(3)
	check(app.current_reward != null and app.current_reward.gold, "III defeat produces guaranteed gold offer once")
	check(app.segment.is_safe(stage.reward_position), "III gold exit is actually supported safe bridge standing point")
	var offer := app.current_reward
	app.player.reset_at(stage.reward_position)
	await frames(2)
	check(app.exit_modal.opened and paused, "safe bridge gold door opens real confirmation UI")
	app._confirm_generated_exit()
	await frames(2)
	check(app.reward_modal.opened and paused, "confirm opens guaranteed gold selection UI")
	check(app.current_reward.offer_id == offer.offer_id, "door confirmation preserves one gold settlement")
	var item := offer.candidates[0].stable_id
	check(app._claim_modal_item(item), "actual gold UI claim commits")
	check(not app._claim_modal_item(item), "repeat gold claim rejected")
	await frames(4)
	check(app.director.state == DemoRunDirector.State.HOME and app.meta.snapshot().completed_biomes == 1, "III gold returns home and records one completed biome")
	# Same physics batch: player death wins, neither reward nor biome progress.
	await fixture()
	stage = app.stage as GeneratedDemoStage
	encounter = stage.boss.get_node("Encounter")
	# Wait the unchanged spawn protection before submitting legitimate lethal hits.
	await frames(45)
	var health := app.controller.actor_resources.health
	submit(&"boss",encounter.health.current,encounter.health,&"tie_boss")
	submit(&"player",health.current,health,&"tie_player")
	await frames(5)
	check(app.director.state == DemoRunDirector.State.HOME, "same-frame lethal tie returns home as failure")
	check(app.current_reward == null and app.meta.snapshot().completed_biomes == 0, "same-frame tie creates no gold or biome completion")
	app.free()
	await process_frame
	print("WINDKEEPER APP: %s assertions, %s failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
