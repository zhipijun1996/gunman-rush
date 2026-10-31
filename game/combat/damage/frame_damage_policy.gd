class_name FrameDamagePolicy
extends Node

signal batch_resolved(results: Array[DamageResult])
signal player_fatal
signal environment_return_requested
var lifetime: DemoLifetime
var monster_iframe := 0.65
var spawn_protection := 0.6
var clock := 0.0
# Only player protection uses real activity during a world freeze. The legacy
# world clock remains unchanged for attack/hazard simulation cadence.
var _player_clock_offset := 0.0
var _targets: Dictionary = {}
var _queue: Array[DamageRequest] = []
var _seen: Dictionary = {}
var _monster_until := 0.0
var _protected_until := 0.0
var _player_controller: PlayerController
var _authorized_effect_requests: Dictionary = {}

func register_player_controller(value: PlayerController) -> void:
	_player_controller = value
	if is_instance_valid(value): value.set_meta(&"frame_damage_policy",weakref(self))

# Read-only transaction guard for menus/services. Merely pausing the tree must
# not let a transaction race a player hit that this same frame already queued.
func has_pending_player_damage() -> bool:
	if lifetime == null or not lifetime.active: return false
	for request: DamageRequest in _queue:
		if not lifetime.accepts(request.token) or request.actor_epoch != lifetime.actor_epoch or not _targets.has(request.target_id): continue
		var target: Dictionary = _targets[request.target_id]
		var health := target.health as HealthState
		if bool(target.player) and health != null and not health.terminal and request.health_epoch == health.epoch: return true
	return false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 1000

func register_target(id: StringName, health: HealthState, is_player: bool = false) -> bool:
	if id.is_empty() or health == null or health.epoch == 0 or _targets.has(id):
		return false
	_targets[id] = {"health": health, "player": is_player}
	return true

func bind_damageable(id: StringName, receiver: Damageable, health: HealthState) -> bool:
	if not register_target(id, health):
		return false
	receiver.damage_sink = func(context: Dictionary) -> bool:
		var request := DamageRequest.new()
		request.token = lifetime.token()
		request.event_id = StringName(context.get("event_id", ""))
		request.source_id = StringName("player_projectile:%s" % context.get("source_actor_id", 0))
		request.target_id = id
		request.amount = float(context.get("amount", 0.0))
		var incoming: Variant = context.get("hit_direction", Vector2.ZERO)
		if not incoming is Vector2 or not (incoming as Vector2).is_finite(): return false
		request.hit_direction = incoming
		var committed_context := context.duplicate()
		request.on_damage_applied = func() -> void:
			if is_instance_valid(receiver): receiver.damaged.emit(committed_context)
		request.health_epoch = health.epoch
		request.actor_epoch = lifetime.actor_epoch
		request.on_committed = context.get("on_committed",Callable())
		if bool(context.get("item_effect_damage",false)):
			var runtime := _item_runtime()
			if runtime == null or not runtime.has_method("authorizes_effect") or not bool(runtime.call("authorizes_effect",context,receiver)): return false
			request.item_effect_damage = true
			var authority: WeakRef = weakref(runtime)
			var receiving: WeakRef = weakref(receiver)
			# Only immutable proof fields are captured; never capture the context
			# dictionary that also contains callbacks.
			var proof := {"event_id":request.event_id,"amount":request.amount,"item_origin":context.get("item_origin",&"")}
			request.effect_source_valid = func() -> bool:
				var current := authority.get_ref() as RefCounted
				var destination := receiving.get_ref() as Damageable
				return current != null and is_instance_valid(destination) and bool(current.call("authorizes_effect",proof,destination))
			_authorized_effect_requests[request.get_instance_id()] = _effect_signature(request)
		return submit(request)
	return true

func submit(request: DamageRequest) -> bool:
	var admitted_effect := false
	if request != null and request.item_effect_damage:
		admitted_effect = _authorized_effect_requests.get(request.get_instance_id(),[]) == _effect_signature(request)
		_authorized_effect_requests.erase(request.get_instance_id())
		if not admitted_effect: return false
	if request == null or lifetime == null or not lifetime.accepts(request.token) or not _targets.has(request.target_id):
		return false
	var target: Dictionary = _targets[request.target_id]
	if request.item_effect_damage and (target.player or request.kind != DamageRequest.Kind.MONSTER): return false
	var health: HealthState = target.health
	if request.event_id.is_empty() or request.source_id.is_empty() or not is_finite(request.amount) or request.amount <= 0.0 or not request.hit_direction.is_finite() or request.kind not in [DamageRequest.Kind.MONSTER, DamageRequest.Kind.ENVIRONMENT]:
		return false
	if health.terminal or request.health_epoch != health.epoch or request.actor_epoch != lifetime.actor_epoch:
		return false
	var key := "%s/%s" % [request.target_id, request.event_id]
	if _seen.has(key):
		return false
	# Eligibility is frozen before any target's HP signals can affect the run.
	if target.player and (player_clock() < _protected_until or (request.kind == DamageRequest.Kind.MONSTER and player_clock() < _monster_until)):
		return false
	_seen[key] = true
	_queue.append(request.copy())
	return true

func protect_player() -> void:
	_protected_until = player_clock() + maxf(0.0, spawn_protection)

func player_clock() -> float:
	return clock + _player_clock_offset

func _physics_process(delta: float) -> void:
	var runtime := _item_runtime()
	var world_frozen := runtime != null and runtime.has_method("world_is_frozen") and bool(runtime.call("world_is_frozen"))
	if world_frozen:
		if is_instance_valid(_player_controller) and _player_controller.active and _player_controller.router.has_application_focus and not get_tree().paused:
			_player_clock_offset += delta / Engine.time_scale
	else:
		clock += delta
	resolve_batch()

func resolve_batch() -> Array[DamageResult]:
	var pending := _queue
	_queue = []
	var results: Array[DamageResult] = []
	if lifetime == null or not lifetime.active:
		return results
	var chosen: Dictionary = {}
	var effects: Array[DamageRequest] = []
	for request: DamageRequest in pending:
		if not lifetime.accepts(request.token) or request.actor_epoch != lifetime.actor_epoch:
			continue
		if request.item_effect_damage:
			effects.append(request)
			continue
		if not chosen.has(request.target_id) or _comes_first(request, chosen[request.target_id]):
			chosen[request.target_id] = request
	var ids: Array = chosen.keys()
	ids.sort()
	# Commit every HP first, then choose failure/return/Boss/reward outcomes.
	for id: StringName in ids:
		var request: DamageRequest = chosen[id]
		var health: HealthState = _targets[id].health
		var committed := _commit_selected(request,health,bool(_targets[id].player))
		if committed != null: results.append(committed)
	# Legacy primary selection/order is unchanged. Only authenticated V5 effects
	# are additive, and player primary death suppresses their later HP commits.
	var primary_player_fatal := false
	for result: DamageResult in results:
		if _targets[result.request.target_id].player and result.lethal: primary_player_fatal = true
	if not primary_player_fatal:
		effects.sort_custom(func(a: DamageRequest,b: DamageRequest) -> bool:
			if a.target_id != b.target_id: return String(a.target_id) < String(b.target_id)
			if a.source_id != b.source_id: return String(a.source_id) < String(b.source_id)
			return String(a.event_id) < String(b.event_id))
		for request: DamageRequest in effects:
			if not lifetime.accepts(request.token) or request.actor_epoch != lifetime.actor_epoch: continue
			if not request.effect_source_valid.is_valid() or not bool(request.effect_source_valid.call()): continue
			var health: HealthState = _targets[request.target_id].health
			var committed := _commit_selected(request,health,false)
			if committed != null: results.append(committed)
	var fatal := false
	var return_needed := false
	for result: DamageResult in results:
		if _targets[result.request.target_id].player:
			fatal = result.lethal
			return_needed = not fatal and result.request.kind == DamageRequest.Kind.ENVIRONMENT
			if not fatal and not return_needed and (not result.blocked or result.barrier_absorbed > 0.0 or result.rescued):
				var iframe := monster_iframe
				var runtime := _item_runtime()
				if runtime != null and runtime.has_method("monster_iframe"): iframe = float(runtime.call("monster_iframe",monster_iframe))
				_monster_until = player_clock() + maxf(0.0, iframe)
	if not fatal:
		var runtime := _item_runtime()
		if runtime != null and runtime.has_method("on_damage"):
			for result: DamageResult in results:
				if _targets[result.request.target_id].player and result.hp_lost > 0.0:
					runtime.call("on_damage",{"event_id":result.request.event_id,"hp_lost":result.hp_lost,"amount":result.request.amount,"barrier_absorbed":result.barrier_absorbed,"kind":result.request.kind,"source":result.request.source_id,"lethal":result.lethal,"point":_player_controller.motor.global_position})
					result.health = (_targets[result.request.target_id].health as HealthState).snapshot()
	if not fatal and not return_needed and is_instance_valid(_player_controller):
		for result: DamageResult in results:
			if _targets[result.request.target_id].player and (result.hp_lost > 0.0 or result.barrier_absorbed > 0.0 or result.rescued):
				_player_controller.motor.accept_damage_knockback(result.request.hit_direction)
	if fatal:
		# Invalidate before any consumer can claim a reward in batch_resolved.
		lifetime.end()
		player_fatal.emit()
	elif return_needed:
		environment_return_requested.emit()
	for result: DamageResult in results:
		if result.hp_lost > 0.0 and result.request.on_damage_applied.is_valid(): result.request.on_damage_applied.call()
	# Refund only selected, actually committed hits after death/return priority.
	if not fatal:
		for result: DamageResult in results:
			if result.hp_lost > 0.0 and lifetime.accepts(result.request.token) and result.request.on_committed.is_valid(): result.request.on_committed.call()
	batch_resolved.emit(results)
	return results

func _commit_selected(request: DamageRequest, health: HealthState, player: bool) -> DamageResult:
	var amount := request.amount
	var defense: Dictionary = {}
	var runtime := _item_runtime()
	if player and runtime != null and runtime.has_method("defend_request"):
		defense = runtime.call("defend_request",request,health.current)
		amount = float(defense.get("amount",amount))
		if not is_finite(amount) or amount < 0.0 or amount > request.amount: return null
	var result := DamageResult.new()
	result.request = request
	result.barrier_absorbed = float(defense.get("barrier_absorbed",0.0))
	result.blocked = bool(defense.get("blocked",false))
	result.rescued = bool(defense.get("rescued",false))
	if amount > 0.0:
		var applied := health.apply_damage(ActorResourceRequest.new(request.event_id,request.health_epoch,amount,health.get_instance_id()))
		if applied.status != ActorResourceResult.Status.APPLIED: return null
		result.health = applied.snapshot.copy()
		result.hp_lost = -applied.amount_applied
	else:
		if not player or (not result.blocked and not result.rescued): return null
		result.health = health.snapshot()
	result.lethal = result.health.terminal
	return result

func _item_runtime() -> RefCounted:
	return _player_controller.get("item_runtime") as RefCounted if is_instance_valid(_player_controller) else null

static func _effect_signature(request: DamageRequest) -> Array:
	return [request.event_id,request.source_id,request.target_id,request.amount,request.health_epoch,request.actor_epoch,request.token.key() if request.token != null else "",request.effect_source_valid]

static func _comes_first(a: DamageRequest, b: DamageRequest) -> bool:
	if a.kind != b.kind:
		return a.kind == DamageRequest.Kind.ENVIRONMENT
	if a.amount != b.amount:
		return a.amount > b.amount
	if a.source_id != b.source_id:
		return str(a.source_id) < str(b.source_id)
	return str(a.event_id) < str(b.event_id)
