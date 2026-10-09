class_name FrameDamagePolicy
extends Node

signal batch_resolved(results: Array[DamageResult])
signal player_fatal
signal environment_return_requested
var lifetime: DemoLifetime
var monster_iframe := 0.65
var spawn_protection := 0.6
var clock := 0.0
var _targets: Dictionary = {}
var _queue: Array[DamageRequest] = []
var _seen: Dictionary = {}
var _monster_until := 0.0
var _protected_until := 0.0

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
		request.health_epoch = health.epoch
		request.actor_epoch = lifetime.actor_epoch
		return submit(request)
	return true

func submit(request: DamageRequest) -> bool:
	if request == null or lifetime == null or not lifetime.accepts(request.token) or not _targets.has(request.target_id):
		return false
	var target: Dictionary = _targets[request.target_id]
	var health: HealthState = target.health
	if request.event_id.is_empty() or request.source_id.is_empty() or not is_finite(request.amount) or request.amount <= 0.0 or request.kind not in [DamageRequest.Kind.MONSTER, DamageRequest.Kind.ENVIRONMENT]:
		return false
	if health.terminal or request.health_epoch != health.epoch or request.actor_epoch != lifetime.actor_epoch:
		return false
	var key := "%s/%s" % [request.target_id, request.event_id]
	if _seen.has(key):
		return false
	# Eligibility is frozen before any target's HP signals can affect the run.
	if target.player and (clock < _protected_until or (request.kind == DamageRequest.Kind.MONSTER and clock < _monster_until)):
		return false
	_seen[key] = true
	_queue.append(request.copy())
	return true

func protect_player() -> void:
	_protected_until = clock + maxf(0.0, spawn_protection)

func _physics_process(delta: float) -> void:
	clock += delta
	resolve_batch()

func resolve_batch() -> Array[DamageResult]:
	var pending := _queue
	_queue = []
	var results: Array[DamageResult] = []
	if lifetime == null or not lifetime.active:
		return results
	var chosen: Dictionary = {}
	for request: DamageRequest in pending:
		if not lifetime.accepts(request.token) or request.actor_epoch != lifetime.actor_epoch:
			continue
		if not chosen.has(request.target_id) or _comes_first(request, chosen[request.target_id]):
			chosen[request.target_id] = request
	var ids: Array = chosen.keys()
	ids.sort()
	# Commit every HP first, then choose failure/return/Boss/reward outcomes.
	for id: StringName in ids:
		var request: DamageRequest = chosen[id]
		var health: HealthState = _targets[id].health
		var applied := health.apply_damage(ActorResourceRequest.new(request.event_id, request.health_epoch, request.amount, health.get_instance_id()))
		if applied.status != ActorResourceResult.Status.APPLIED:
			continue
		var result := DamageResult.new()
		result.request = request
		result.health = applied.snapshot.copy()
		result.lethal = result.health.terminal
		results.append(result)
	var fatal := false
	var return_needed := false
	for result: DamageResult in results:
		if _targets[result.request.target_id].player:
			fatal = result.lethal
			return_needed = not fatal and result.request.kind == DamageRequest.Kind.ENVIRONMENT
			if not fatal and not return_needed:
				_monster_until = clock + maxf(0.0, monster_iframe)
	if fatal:
		# Invalidate before any consumer can claim a reward in batch_resolved.
		lifetime.end()
		player_fatal.emit()
	elif return_needed:
		environment_return_requested.emit()
	batch_resolved.emit(results)
	return results

static func _comes_first(a: DamageRequest, b: DamageRequest) -> bool:
	if a.kind != b.kind:
		return a.kind == DamageRequest.Kind.ENVIRONMENT
	if a.amount != b.amount:
		return a.amount > b.amount
	if a.source_id != b.source_id:
		return str(a.source_id) < str(b.source_id)
	return str(a.event_id) < str(b.event_id)
