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
		await terminal_reload(broken, units.size())
	await cleanup()

func current_arena() -> WindkeeperArena:
	for child: Node in encounter.get_children():
		if child is WindkeeperArena: return child as WindkeeperArena
	return null

func terminal_reload(broken: bool, unit_count: int) -> void:
	# Existing earned terminal/reward fixture, followed by the actual App reload.
	# Pause only excludes a fresh damage batch until the completion flag is read.
	var old_stage_id: int = app.stage.get_instance_id()
	var balance: int = app.wallet.balance
	var wallet: RunWallet = app.wallet
	var inventory: RunInventory = app.build.inventory
	var claimed: Dictionary = app.region_state.claimed.duplicate(true)
	var run_epoch: int = app.lifetime.epoch
	var stage_epoch: int = app.lifetime.stage_epoch
	paused = true
	await app._load_stage()
	encounter = app.stage.boss.get_node("Encounter")
	check(app.stage.get_instance_id()!=old_stage_id and encounter.health.terminal, "terminal App reload creates a new actual Stage and preserves Boss death")
	check(not app.director.stage_complete and app.current_reward==null, "terminal App reentry reopens completion before the next real damage batch")
	await ticks(2)
	var arena := current_arena()
	check(arena!=null and arena.broken==broken and encounter.bridge_break_ready()==broken, "terminal Pressure reload restores the actual bridge-release flag, not phase alone")
	if arena!=null:
		check(arena.module.get_node("Platform0").collision_layer==(0 if broken else 1), "terminal restore binds the corresponding actual collision surface")
	check(app.wallet==wallet and app.build.inventory==inventory and app.wallet.balance==balance and app.region_state.claimed==claimed, "terminal reentry retains the real wallet, inventory and claimed-source ledger")
	check(app.lifetime.epoch==run_epoch and app.lifetime.stage_epoch==stage_epoch, "same-stage terminal reentry does not advance run or stage epoch")
	paused = false
	await ticks(3)
	check(app.director.stage_complete and app.current_reward!=null and app.current_reward.gold, "first live batch rebuilds the guaranteed reward through the original completion chain")
	var restored_units: Array = app.stage.pickups.filter(func(pickup: Dictionary) -> bool: return str(pickup.get("source", ""))==WindkeeperPressureRewards.SOURCE)
	check(restored_units.size()==unit_count and restored_units.all(func(pickup: Dictionary) -> bool: return bool(pickup.claimed)) and app.wallet.balance==balance, "terminal reload neither duplicates physical coins nor pays an already claimed source")
	check(not WindkeeperPressureRewards.spawn(app.stage,encounter), "restored terminal impact still cannot resettle its original receipt")
	observations.append({"case":"actual terminal App reload", "bridge_released":broken, "physical_units":unit_count, "wallet":balance, "scope":"actual unload/bind/terminal restore/completion batch; original earned reward fixture, no injected bridge or completion state"})

func unreleased_phase_three_restore() -> void:
	if not await setup(): return
	var arena := current_arena()
	var health_goal: float = encounter.health.capacity * encounter._config().phase_three_health - 1
	var request := ActorResourceRequest.new(&"explicit-restore-unreleased-phase3", encounter.health.epoch,
		encounter.health.current-health_goal, encounter.health.get_instance_id())
	check(encounter.health.apply_damage(request).accepted(), "unreleased restore fixture reaches phase3 through the original Boss resource transaction")
	encounter.set_physics_process(true)
	await ticks(1)
	paused = true
	check(encounter.stage_phase==3 and not encounter.bridge_break_ready() and arena!=null and not arena.broken, "Pressure is actually in phase3 before its verified landing releases the bridge")
	encounter.restore_bridge_geometry()
	await ticks(2)
	check(not arena.broken and arena.module.get_node("Platform0").collision_layer==1, "Pressure restore cannot substitute phase3 for the unreleased bridge flag")
	await cleanup()

func active_bridge_reload() -> void:
	# Earn the real bridge release using the original Boss HP transaction and
	# ordinary player jump fixture, then exercise App's second restore consumer.
	await bridge_transition_escape()
	if not is_instance_valid(app) or not is_instance_valid(encounter): return
	check(encounter.bridge_break_ready() and current_arena()!=null and current_arena().broken, "active reload begins after the actual grounded bridge release")
	var health: float = encounter.health.current
	var stage_id: int = app.stage.get_instance_id()
	paused = true
	await app._load_stage()
	encounter = app.stage.boss.get_node("Encounter")
	var arena := current_arena()
	check(app.stage.get_instance_id()!=stage_id and arena!=null and not arena.broken and not app._boss_started, "live Pressure reload waits for actual activation before restoring its bridge")
	check(bool(app.stage.restored_boss.get("active",false)), "active snapshot is retained for the real activation restore consumer")
	app._start_generated_boss()
	check(app._boss_started and encounter.health.current==health and app.stage.restored_boss.is_empty(), "actual App activation consumes the saved active combat state")
	check(encounter.bridge_break_ready() and not arena.broken, "active bridge restore retains the same deferred collision boundary")
	await ticks(2)
	check(arena.broken and arena.module.get_node("Platform0").collision_layer==0, "App activation restores the physically earned broken bridge through its owner")
	observations.append({"case":"actual active App bridge reload", "scope":"earned original bridge fixture, actual unload/bind and explicit existing App activation command while paused; not a natural approach-route claim"})
	await cleanup()

func run() -> void:
	await reward_case(false)
	await reward_case(true)
	await unreleased_phase_three_restore()
	await active_bridge_reload()
	DirAccess.make_dir_recursive_absolute("res://build/windkeeper_pressure_01")
	var file := FileAccess.open("res://build/windkeeper_pressure_01/rewards.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"observations":observations},"\t"))
	file.close()
	print("WINDKEEPER PRESSURE REWARDS: ",assertions," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
