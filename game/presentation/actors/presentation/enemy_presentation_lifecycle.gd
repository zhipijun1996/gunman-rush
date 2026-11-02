class_name EnemyPresentationLifecycle
extends RefCounted
## One host lifecycle: explicit resource binding, paused epoch synchronization,
## one optional motion/feedback clock owner, and idempotent release.
## The renderer retains its species clocks, assets and terminal policy.
var actor: EnemyActor
var host: Node2D
var snapshot: Dictionary = {}
var epoch := -1
var _health: HealthState
var _initialize := Callable()
var _changed := Callable()
var _motion: RefCounted
var _sample: EnemyFeedback01
var _owns_sample_clock := false
var _cleanup: Array[Callable] = []
var _bound := false

func bind(owner_actor: EnemyActor, presentation: Node2D, initialize_callback: Callable, health_callback := Callable(), motion: RefCounted = null, sample: EnemyFeedback01 = null, owns_sample_clock := false) -> bool:
	if not is_instance_valid(owner_actor) or not is_instance_valid(presentation) or owner_actor.health == null: return false
	if not bool(owner_actor.presentation_state().get("valid",false)): return false
	if _bound and actor == owner_actor and host == presentation and _health == owner_actor.health: return true
	dispose()
	actor = owner_actor
	host = presentation
	_health = actor.health
	_initialize = initialize_callback
	_changed = health_callback
	_motion = motion
	_sample = sample
	_owns_sample_clock = owns_sample_clock
	epoch = -1
	_bound = true
	_health.changed.connect(_resource_changed)
	sync_initialize()
	return true

func is_bound() -> bool:
	return _bound and is_instance_valid(actor) and is_instance_valid(host)

func own_cleanup(callback: Callable) -> void:
	if callback.is_valid() and not _cleanup.has(callback): _cleanup.append(callback)

func read_state() -> Dictionary:
	if not is_bound(): return {}
	return actor.presentation_state()

func sync_initialize() -> void:
	if not is_bound(): return
	snapshot = read_state()
	if not bool(snapshot.get("valid",false)): return
	if epoch == _health.epoch: return
	epoch = _health.epoch
	if _motion != null and _motion.has_method("sync_epoch"):
		_motion.call("sync_epoch",actor,snapshot)
	if _initialize.is_valid(): _initialize.call()

func synchronize() -> void:
	# Complete-restore synchronization is separate from initialization. Same
	# epoch calls refresh only position/facing baselines, preserving accepted H/D.
	sync_initialize()
	if not is_bound(): return
	if _motion != null and _motion.has_method("synchronize"):
		_motion.call("synchronize",actor,snapshot)
	host.queue_redraw()

func advance(delta: float) -> bool:
	sync_initialize()
	if not is_bound() or not bool(snapshot.get("valid",false)) or not host.is_inside_tree() or host.get_tree().paused or not is_finite(delta) or delta <= 0.0: return false
	if _motion != null: _motion.call("advance",actor,delta,snapshot)
	if _owns_sample_clock and _sample != null: _sample.advance(delta)
	return true

func _resource_changed(result: ActorResourceResult) -> void:
	if not is_bound() or result == null or result.snapshot == null or result.snapshot.epoch != _health.epoch: return
	if result.operation == &"initialize":
		sync_initialize()
	else:
		snapshot = read_state()
		if _changed.is_valid(): _changed.call(result)

func dispose() -> void:
	if _health != null and _health.changed.is_connected(_resource_changed):
		_health.changed.disconnect(_resource_changed)
	_bound = false
	for callback: Callable in _cleanup:
		if callback.is_valid(): callback.call()
	_cleanup.clear()
	if _owns_sample_clock and _sample != null: _sample.dispose()
	if _motion != null and _motion.has_method("dispose"): _motion.call("dispose")
	actor = null
	host = null
	_health = null
	_motion = null
	_sample = null
	_initialize = Callable()
	_changed = Callable()
	_owns_sample_clock = false
	snapshot = {}
	epoch = -1
