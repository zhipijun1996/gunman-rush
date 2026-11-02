class_name SimpleRoomReward
extends RefCounted

signal committed(result: SimpleRewardResult)
var claimed: bool:
	get: return _claimed
var _claimed := false
var _definition: SimpleRewardDefinition
var _lifetime: DemoLifetime
var _health: HealthState
var _wallet: RunWallet
var _run_epoch := 0
var _stage_epoch := 0
var _receipts: Dictionary = {}
var _committing := false

func configure(definition: SimpleRewardDefinition, lifetime: DemoLifetime, health: HealthState, wallet: RunWallet) -> bool:
	# A stage owns this service; reconfiguration must not erase its ledger.
	if _definition != null or definition == null or not definition.is_valid() or lifetime == null or not lifetime.active or health == null or wallet == null:
		return false
	_definition = definition.duplicate(true)
	_lifetime = lifetime
	_health = health
	_wallet = wallet
	_run_epoch = lifetime.epoch
	_stage_epoch = lifetime.stage_epoch
	return true

func claim(token: DemoToken, event_id: StringName) -> SimpleRewardResult:
	if token == null or event_id.is_empty() or _definition == null:
		return SimpleRewardResult.rejected(SimpleRewardResult.Status.INVALID)
	var payload := token.key()
	if _receipts.has(event_id):
		if _receipts[event_id].payload != payload:
			return SimpleRewardResult.rejected(SimpleRewardResult.Status.CONFLICT)
		var replay: SimpleRewardResult = _receipts[event_id].result.copy()
		replay.status = SimpleRewardResult.Status.REPLAY
		return replay
	if not _lifetime.accepts(token) or token.run_epoch != _run_epoch or token.stage_epoch != _stage_epoch:
		return SimpleRewardResult.rejected(SimpleRewardResult.Status.STALE)
	if _health.terminal:
		return SimpleRewardResult.rejected(SimpleRewardResult.Status.TERMINAL)
	if _claimed or _committing:
		return SimpleRewardResult.rejected(SimpleRewardResult.Status.UNAVAILABLE)
	var source := StringName("room_reward:%d:%d:%s" % [_run_epoch, _stage_epoch, _definition.stable_id])
	var result := SimpleRewardResult.new()
	result.event_id = event_id
	result.status = SimpleRewardResult.Status.COMMITTED
	_committing = true
	if _definition.kind == SimpleRewardDefinition.Kind.COINS:
		var before := _wallet.balance
		if not _wallet.grant(int(_definition.amount), source):
			_committing = false
			return SimpleRewardResult.rejected(SimpleRewardResult.Status.CONFLICT)
		result.amount_applied = _wallet.balance - before
		if result.amount_applied == 0.0:
			result.status = SimpleRewardResult.Status.REPLAY
	else:
		var effect := SupplyHealEffect.apply(_health, _definition.amount, source)
		if not effect.accepted():
			_committing = false
			return SimpleRewardResult.rejected(SimpleRewardResult.Status.UNAVAILABLE)
		result.amount_applied = effect.amount_applied
		if effect.status == ActorResourceResult.Status.REPLAY:
			result.status = SimpleRewardResult.Status.REPLAY
	result.coins = _wallet.balance
	result.current_health = _health.current
	result.maximum_health = _health.capacity
	_claimed = true
	_receipts[event_id] = {"payload": payload, "result": result.copy()}
	_committing = false
	if result.status == SimpleRewardResult.Status.COMMITTED:
		committed.emit(result.copy())
	return result
