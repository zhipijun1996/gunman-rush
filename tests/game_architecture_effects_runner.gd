extends SceneTree
## Focused extraction boundary checks. Original actives, boss-target and time
## suites remain responsible for real entity behavior and formal consumers.
var assertions := 0
var failures := 0

class CastHost extends RefCounted:
	var player := PlayerController.new()
	var world := Node2D.new()
	var inventory := RunInventory.new(&"cast_boundary")
	var trace: Array[StringName] = []
	var clock := 2.0
	var reject_patch := false
	var last_patch: StringName
	func actor() -> PlayerController:
		trace.append(&"actor")
		return player
	func world_root() -> Node2D: return world
	func is_live() -> bool: return true
	func effect(_id: StringName) -> Dictionary: return {"fixture": true}
	func state(id: StringName) -> Dictionary:
		trace.append(&"state")
		return inventory.instance_for_definition(id).effect_state
	func map_key() -> StringName:
		trace.append(&"map")
		return &"fixture/cast"
	func now() -> float:
		trace.append(&"now")
		return clock
	func spend_energy(amount: float, receipt: StringName) -> bool:
		trace.append(&"spend")
		return player.combat_energy.consume(String(receipt), amount)
	func on_spent(_receipt: String, _amount: float) -> void:
		trace.append(&"spent")
		clock += 3.0
	func patch_state(id: StringName, patch: Dictionary, receipt: StringName) -> bool:
		trace.append(&"patch")
		last_patch = receipt
		if reject_patch: return false
		return inventory.patch_effect_state(inventory.instance_for_definition(id).instance_id, patch, receipt)
	func cue(_kind: StringName, _point: Vector2, _detail: Dictionary) -> void: pass

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _run() -> void:
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false, "intentional strict-exit counterexample")
		quit(1)
		return
	var host := CastHost.new()
	host.player.session_id = 41
	host.player.combat_energy.current = 100.0
	host.player.combat_energy.spent.connect(host.on_spent)
	check(host.inventory.add_item(&"blast", ItemCatalogV5.get_item(&"B33")) and host.inventory.add_item(&"guard", ItemCatalogV5.get_item(&"G05")), "fixture uses original inventory and authored active definitions")
	var casts := ItemActiveCast.new(host)
	var blast := casts.prepare(&"B33", host.player)
	check(blast.receipt == &"fixture/cast/item/41/B33/1" and host.trace == [&"state", &"map"], "projectile preparation preserves cached actor, sequence and exact receipt")
	check(casts.commit(blast, 10.0, 4.0), "shared cast spends through real CombatEnergyState")
	check(host.trace == [&"state", &"map", &"spend", &"spent", &"now", &"patch"], "synchronous spent callback precedes cooldown clock and progress patch")
	var state := host.inventory.instance_for_definition(&"B33").effect_state
	check(host.player.combat_energy.current == 90.0 and state.cast_sequence == 1 and state.cooldown_until == 9.0 and host.last_patch == &"fixture/cast/item/41/B33/1/state", "accepted cast stores post-callback time and original state receipt")
	var revision := host.inventory.revision
	host.trace.clear()
	check(not casts.commit(blast, 10.0, 4.0) and host.trace == [&"spend"] and host.inventory.revision == revision and host.player.combat_energy.current == 90.0, "same energy receipt rejects before time/progress and cannot debit twice")
	host.trace.clear()
	var guard := casts.prepare(&"G05")
	check(guard.receipt == &"fixture/cast/item/41/G05/1" and host.trace == [&"state", &"map", &"actor"], "companion preparation resolves actor after state and map")
	check(casts.commit(guard, 20.0, 7.0) and host.inventory.instance_for_definition(&"G05").effect_state.cooldown_until == 15.0 and host.player.combat_energy.current == 70.0, "companion uses the same payment/progress operation with its own cooldown")
	host.reject_patch = true
	var next := casts.prepare(&"B33", host.player)
	check(casts.commit(next, 10.0, 4.0) and host.player.combat_energy.current == 60.0 and host.inventory.instance_for_definition(&"B33").effect_state.cast_sequence == 1, "known pre-existing behavior retained: refused progress after successful energy debit does not refund or reject cast")
	var time_context := ItemTimeContext.new(host)
	check(time_context.actor() == host.player and time_context.world_root() == host.world and time_context.is_live(), "time family receives its live player/world capabilities")
	check(not time_context.has_method("build") and not time_context.has_method("wallet") and not time_context.has_method("deal") and not time_context.has_method("runtime"), "time context exposes no Build, Wallet, damage or raw-runtime access")
	host.player.combat_energy.spent.disconnect(host.on_spent)
	host.player.free()
	host.world.free()
	var weak: WeakRef = weakref(host)
	var call_scope := time_context.scoped()
	host = null
	check(weak.get_ref() != null and call_scope.effect(&"B06").fixture, "local time call scope retains its owner across synchronous callbacks without exposing it")
	call_scope = null
	check(weak.get_ref() == null and time_context.actor() == null and time_context.world_root() == null and not time_context.is_live() and time_context.effect(&"B06").is_empty(), "cast/time contexts do not retain the run and become inactive when its owner is released")
	await process_frame
	print("GAME ARCHITECTURE EFFECTS: %s assertions, %s failures" % [assertions, failures])
	quit(1 if failures else 0)
