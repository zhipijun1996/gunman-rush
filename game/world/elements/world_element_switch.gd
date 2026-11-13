class_name WorldElementSwitch
extends WorldShotLatch
## Shot eligibility is shared; signal routing and accepted state are independent of targets.
@export var element_id := ""
@export_enum("permanent", "attempt") var state_scope := "permanent"
@export var access_points: Array[Vector2] = []
@export var links: Array[Dictionary] = []
@export var repeat_enabled := false
@export var duration := 0.0
var elements: WorldElementRuntime
var expiration_pending := false

func element_bind(context: Dictionary) -> void:
	elements = context.runtime
	stable_id = element_id
	setup(context.controller, context.lifetime, Vector2.ZERO, Rect2(0,0,1,1))
	gate_body.free(); gate_body = null; gate_shape = null
	gate_visual_enabled = false
	open_seconds = 0
	for point: Vector2 in access_points: add_access_bell(point-position)
	activation_requested.connect(context.submit)
	controller.router.cancelled.connect(on_router_cancelled)

func accepts_activation() -> bool:
	return not is_open or repeat_enabled

func _commit_open(request: Dictionary) -> void:
	pending_commit = request
	if can_commit(): activation_requested.emit(element_id)

func can_commit() -> bool:
	if expiration_pending: return is_open and lifetime.active and controller.active and not _cancelled and elements.can_signal(self, false)
	var request := pending_commit
	return not request.is_empty() and request.get("request_epoch",-1)==_request_epoch and not _cancelled and accepts_activation() and lifetime.accepts(request.token) and controller.active and not controller.actor_resources.health.terminal and controller.session_id==request.session and health.epoch==request.health_epoch and elements.can_signal(self, not is_open if repeat_enabled else true)

func element_state() -> Dictionary:
	return {"active":is_open,"clock":_clock,"opened_at":_opened_at,"open_count":open_count}

func proposed_state() -> Dictionary:
	return {"active":false if expiration_pending else (not is_open if repeat_enabled else true),"clock":_clock,"opened_at":_clock,"open_count":open_count+(0 if expiration_pending else 1)}

func element_signal() -> Dictionary:
	return {"output":"active","value":proposed_state().active}

func element_restore(data: Dictionary) -> void:
	is_open = bool(data.active); _clock = float(data.clock); _opened_at = float(data.opened_at); open_count = int(data.open_count)
	bell_body.collision_layer = 8 if accepts_activation() else 0
	for access: StaticBody2D in access_bodies: access.collision_layer = bell_body.collision_layer
	queue_redraw()

func accept_committed() -> void:
	var expired := expiration_pending
	pending_commit = {}; _eligible_shots.clear(); _seen.clear(); expiration_pending = false
	if expired: GameAudio.cue(self, &"armour")
	else: _play_bell(); opened.emit()

func cancel_pending() -> void:
	expiration_pending = false
	super.cancel_pending()

func _physics_process(delta: float) -> void:
	if elements == null: return
	_clock += delta
	if is_open and duration > 0 and _clock-_opened_at >= duration and not expiration_pending and elements.can_signal(self,false):
		expiration_pending = true; activation_requested.emit(element_id)
	for key: String in _eligible_shots.keys():
		if _eligible_shots[key].expires < _clock: _eligible_shots.erase(key)
	if not _pending.is_empty():
		var request := _pending; _pending = {}; _commit_open.call_deferred(request)
	for child: Node in get_children():
		if child is Sprite2D and child.get_meta("underworld_access_bell",false): child.rotation = _underworld_bell_swing()
	if duration>0 or (_opened_at >= 0 and _clock-_opened_at < .8): queue_redraw()

func _draw() -> void:
	super._draw()
	if elements == null: return
	for link: Dictionary in links:
		var target: Node = elements.nodes.get(str(link.target))
		if target is WorldMovingPlatform:
			var start := to_local(target.get_parent().to_global(target.origin))-Vector2(0,12)
			var end := to_local(target.get_parent().to_global(target.origin+target.endpoint))-Vector2(0,12)
			if target.route.is_empty(): draw_line(start,end,Color("685c48"),3)
			for at: Vector2 in [start,end]: draw_circle(at,5,Color("b39358"),false,2)
		elif target is WorldElementGate and duration>0:
			var corner := to_local(target.to_global(target.bounds.position))
			var left := clampf(1-(_clock-_opened_at)/duration,0,1) if is_open else 0.0
			for i: int in 6: draw_rect(Rect2(corner+Vector2(target.bounds.size.x+6,12+i*9),Vector2(6,4)),Color("efd78d") if left>float(i)/6 else Color("423e32"))
