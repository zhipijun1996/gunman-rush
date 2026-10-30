extends "res://tests/windkeeper_pressure_01/formal_app.gd"
## Actual App terminal/reward chain, declared Boss-only lethal health fixture.
## Player health, Router movement, gravity, pickup admission and receipts stay live.
func reward_case(broken: bool) -> void:
	var ready := false
	if broken:
		await bridge_transition_escape()
		ready = is_instance_valid(app) and encounter != null and not app.controller.actor_resources.health.terminal
	else:
		ready = await setup()
	if ready:
		if broken:
			# Disclosed pre-lethal observation fixture: wait on another actual
			# shelf so automatic pickup cannot hide the physical bounce/settle.
			for child: Node in encounter.get_children():
				if not child is WindkeeperArena: continue
				var arena := child as WindkeeperArena
				var farthest := Vector2.INF
				var distance := -1.0
				for index: int in range(1, 4):
					var slab: Rect2 = arena.module.definition.platforms[index]
					var point := arena.module.to_global(Vector2(slab.get_center().x, slab.position.y - 18))
					var gap := point.distance_squared_to(encounter.motor.global_position)
					if gap > distance: distance = gap; farthest = point
				if farthest.is_finite(): relocate(farthest, "pre-lethal distant supported shelf to observe unclaimed coin landing")
			await ticks(3)
		var hp: float = app.controller.actor_resources.health.current
		var wallet_start: int = app.wallet.balance
		var total: int = encounter._config().reward_coin_total
		var lethal := ActorResourceRequest.new(&"explicit-pressure-reward-terminal-fixture", encounter.health.epoch,
			encounter.health.current, encounter.health.get_instance_id())
		check(encounter.health.apply_damage(lethal).accepted(), "declared Boss-only terminal fixture uses original HealthState transaction")
		encounter.set_physics_process(true)
		await ticks(45)
		check(not app.stage.region_state.drops.has(WindkeeperPressureRewards.SOURCE), "coins do not appear before the real collapse impact")
		await ticks(30)
		var units: Array[Dictionary] = []
		for pickup: Dictionary in app.stage.pickups:
			if str(pickup.get("source", "")) == WindkeeperPressureRewards.SOURCE: units.append(pickup)
		check(not units.is_empty(), "actual death-impact event creates physical reward units")
		var sum := 0
		var large := 0
		var small := 0
		for pickup: Dictionary in units:
			sum += int(pickup.amount)
			large += int(pickup.amount == 5)
			small += int(pickup.amount == 1)
			check(pickup.get("loot_motion", false) and pickup.get("spawn_origin", Vector2.INF).is_finite(), "each physical coin has a real body origin and ballistic motion")
		check(sum == total and large * 5 + small == total, "actual one/five denomination sum equals configured reward")
		check(app.director.stage_complete and app.current_reward != null and app.current_reward.gold, "original guaranteed gold-item chain remains present")
		check(not WindkeeperPressureRewards.spawn(app.stage, encounter), "repeated impact cannot settle Boss coins twice")
		check(app._windkeeper_pressure_rewards_pending(), "unclaimed physical coins prevent automatic exit popup")
		await ticks(78)
		check(units.all(func(pickup: Dictionary) -> bool: return int(pickup.get("loot_bounces", 0)) >= 1), "physical Boss coins actually touch and bounce on supported ground before collection")
		check(units.all(func(pickup: Dictionary) -> bool: return bool(pickup.get("loot_settled", false)) and not bool(pickup.get("loot_returning", false))), "actual ballistic coins settle on reachable ground without safe-return substitution")
		var collector: RefCounted = load("res://tools/windkeeper_pressure_01/legal_input_pilot.gd").new()
		for index: int in 720:
			if app.wallet.balance - wallet_start == total: break
			collector.step(app, encounter, encounter.combat_metrics(), units)
			await ticks(1)
		app.controller.router.set_source_axis(&"keyboard_mouse", 0)
		check(app.wallet.balance - wallet_start == total and units.all(func(pickup: Dictionary) -> bool: return bool(pickup.claimed)), "actual normal movement and original pickup chain collect exactly configured coins")
		check(not app._windkeeper_pressure_rewards_pending(), "only complete physical pickup clears pending gate")
		check(app.controller.actor_resources.health.current == hp, "terminal body and late attacks cannot hurt player collecting rewards")
		app.stage.capture_state()
		var saved: Dictionary = app.stage.region_state.drops[WindkeeperPressureRewards.SOURCE]
		check(saved.units.size() == units.size(), "all physical reward identities persist in original stage drop ledger")
		for unit: Dictionary in saved.units:
			check(app.stage.region_state.claimed.has(unit.id), "original per-unit claim identity persists")
		observations.append({"case":"actual Boss reward chain", "total":total, "wallet_delta":app.wallet.balance-wallet_start,
			"large":large,"small":small,"units":saved.units,"scope":"declared Boss-only lethal fixture; player and physical App pickup unchanged"})
	await cleanup()


func run() -> void:
	await reward_case(false)
	await reward_case(true)
	DirAccess.make_dir_recursive_absolute("res://build/windkeeper_pressure_01")
	var file := FileAccess.open("res://build/windkeeper_pressure_01/rewards.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"observations":observations},"\t"))
	file.close()
	print("WINDKEEPER PRESSURE REWARDS: ",assertions," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
