extends RefCounted
## Explicit outcome/position fixtures; natural traversal is covered separately.
## Death clocks and physical entitlements remain production-owned. Every coin
## is claimed through the real App, never by editing a balance or claim ledger.
static func second_map(app: DemoApp, tree: SceneTree) -> bool:
	var stage:=app.stage as PlainsRegionStage
	app.player.reset_at(stage.boss_arena.position+Vector2(540,202))
	for i: int in 3: await tree.physics_frame
	if not app._boss_started: return false
	var boss:=stage.boss.get_node("Encounter") as BellstriderEncounter
	if boss == null: return false
	var before := app.wallet.balance
	var amount := (boss.definition as BellstriderDefinition).reward_coin_total
	var request:=DamageRequest.new()
	request.token=app.lifetime.token()
	request.actor_epoch=app.lifetime.actor_epoch
	request.health_epoch=boss.health.epoch
	request.target_id=&"boss"
	request.source_id=&"explicit_campaign_fixture"
	request.event_id=&"mini_fixture_defeat"
	request.amount=boss.health.current
	if not app.policy.submit(request): return false
	for i: int in 3: await tree.physics_frame
	# The former portal-payment fixture must now consume the current physical
	# reward. Keep its explicit positioning policy, including a safe observation.
	app.player.reset_at(stage.spawn)
	if not await wait_bell_reward(app,tree): return false
	if not collect_boss_coins(app,BellstriderRewards.source_id(stage),amount): return false
	if app.wallet.balance < before+amount: return false
	app.player.reset_at(stage.reward_position)
	for i: int in 2: await tree.physics_frame
	if not app.exit_modal.opened or not app._confirm_generated_exit(): return false
	for i: int in 8: await tree.physics_frame
	return app.director.stage_index==2 and app.stage is PlainsRegionStage and app.stage.assembly_ok

static func wait_bell_reward(app: DemoApp, tree: SceneTree, complete_death: bool = true) -> bool:
	var stage := app.stage as PlainsRegionStage
	var boss := stage.boss.get_node("Encounter") as BellstriderEncounter
	if boss == null: return false
	var definition := boss.definition as BellstriderDefinition
	var budget := ceili((definition.death_seconds+5.0)*Engine.physics_ticks_per_second)
	for _i: int in budget:
		if not is_instance_valid(stage) or app.stage!=stage or not app.lifetime.active or app.controller.actor_resources.health.terminal: return false
		var impact := boss.reward_impact_ready() and stage.region_state.drops.has(BellstriderRewards.source_id(stage))
		var finished := float(boss.rig_pose().death_age)>=definition.death_seconds and stage.clock>=stage.reward_ready_at
		if impact and (not complete_death or finished): return true
		await tree.physics_frame
	return false

static func wait_pressure_reward(app: DemoApp, tree: SceneTree) -> bool:
	var stage := app.stage as PlainsRegionStage
	var boss := stage.boss.get_node("Encounter") as WindkeeperPressureEncounter
	if boss == null: return false
	var definition := boss.definition as WindkeeperPressureDefinition
	# Unlike Bell, Pressure's real clock remains zero until its locked support
	# landing completes. Observe that clock; elapsed wall frames cannot replace it.
	var budget := ceili((definition.death_seconds+5.0)*Engine.physics_ticks_per_second)
	for _i: int in budget:
		if not is_instance_valid(stage) or app.stage!=stage or not app.lifetime.active or app.controller.actor_resources.health.terminal: return false
		if boss.health.terminal and float(boss.combat_metrics().get("death_age",0.0))>=definition.death_seconds and stage.clock>=stage.reward_ready_at and stage.region_state.drops.has(WindkeeperPressureRewards.SOURCE): return true
		await tree.physics_frame
	return false

static func collect_boss_coins(app: DemoApp, source: String, expected_total: int) -> bool:
	var stage := app.stage as PlainsRegionStage
	var indices: Array[int] = []
	var ids: Dictionary = {}
	var total := 0
	for index: int in stage.pickups.size():
		var pickup: Dictionary = stage.pickups[index]
		if str(pickup.get("source",""))!=source: continue
		if pickup.kind!="coin" or ids.has(pickup.id): return false
		ids[pickup.id]=true
		indices.append(index)
		total+=int(pickup.amount)
	if indices.is_empty() or total!=expected_total: return false
	for index: int in indices:
		var pickup: Dictionary = stage.pickups[index]
		var before := app.wallet.balance
		if pickup.claimed:
			if not stage.region_state.claimed.has(pickup.id): return false
		else:
			if stage.clock<float(pickup.get("ready_at",0.0)): return false
			# Same disclosed position fixture as plains_cohesion_drops_runner:
			# use each live unit's real location, then the original App admission.
			app.player.reset_at(stage.to_global(pickup.position))
			if not app._commit_pickup(index) or not pickup.claimed or app.wallet.balance!=before+int(pickup.amount): return false
			if not stage.region_state.claimed.has(pickup.id): return false
		var credited := app.wallet.balance
		if app._commit_pickup(index) or app.wallet.balance!=credited: return false
	return true
