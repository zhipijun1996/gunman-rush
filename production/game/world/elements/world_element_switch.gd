class_name WorldElementSwitch
extends WorldShotLatch
## Shot eligibility is shared; signal routing and accepted state are independent of targets.
@export var element_id := ""
@export_enum("permanent", "attempt") var state_scope := "permanent"
@export var access_points: Array[Vector2] = []
@export var links: Array[Dictionary] = []
@export var repeat_enabled := false
@export var initial_active := false
@export var section_id := "main"
@export var duration := 0.0
var elements: WorldElementRuntime
var expiration_pending := false
var packet_receipts := {}
var ring_age := 1.0

func element_bind(context: Dictionary) -> void:
	elements = context.runtime
	stable_id = element_id
	setup(context.controller, context.lifetime, Vector2.ZERO, Rect2(0,0,1,1))
	gate_body.free(); gate_body = null; gate_shape = null
	gate_visual_enabled = false
	open_seconds = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for point: Vector2 in access_points:
		add_access_bell(point-position)
		# Paint every shooting point with the same suspended native bell.
		(get_child(-1) as Sprite2D).hide()
	is_open = initial_active
	activation_requested.connect(context.submit)
	controller.router.cancelled.connect(on_router_cancelled)

func accepts_activation() -> bool:
	return not is_open or repeat_enabled

func _register_shot(direction: Vector2, shot_id: int) -> void:
	super._register_shot(direction,shot_id)
	var key := "%s:%s" % [controller.session_id,shot_id]
	if not _eligible_shots.has(key): return
	var packet := "%s:%s" % [controller.session_id,controller.shoot_ability.packet_id]
	var shot: Dictionary = _eligible_shots[key]
	shot.packet = packet
	# All receivers of this bell share the receipt through the last round's lifetime.
	var receipt: Dictionary = packet_receipts.get(packet,{"accepted":false})
	receipt.expires = shot.expires
	packet_receipts[packet] = receipt

func _receive_projectile(context: Dictionary) -> bool:
	var key := "%s:%s" % [context.get("session_id",-1),context.get("shot_id",-1)]
	var shot: Dictionary = _eligible_shots.get(key,{})
	if not shot.has("packet") or packet_receipts[shot.packet].accepted: return false
	if not super._receive_projectile(context): return false
	packet_receipts[shot.packet].accepted = true
	return true

func _commit_open(request: Dictionary) -> void:
	if not pending_commit.is_empty() and elements != null:
		if elements.request_reserved(element_id): return
		for link: Dictionary in links:
			var receiver: Node = elements.nodes.get(link.target)
			if receiver is WorldPermanentResult and receiver.phase == "executing": return
	pending_commit = request
	for link: Dictionary in links:
		var receiver: Node = elements.nodes.get(link.target)
		if receiver is WorldPermanentResult:
			receiver.begin(self)
			return
	if can_commit(): activation_requested.emit(element_id)

func can_commit() -> bool:
	if expiration_pending: return is_open and lifetime.active and controller.active and not _cancelled and elements.can_signal(self, false)
	return request_is_live() and elements.can_signal(self, not is_open if repeat_enabled else true)

func request_is_live() -> bool:
	var request := pending_commit
	return not request.is_empty() and request.get("request_epoch",-1)==_request_epoch and not _cancelled and accepts_activation() and lifetime.accepts(request.token) and controller.active and not controller.actor_resources.health.terminal and controller.session_id==request.session and health.epoch==request.health_epoch

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
	pending_commit = {}; _seen.clear(); expiration_pending = false
	if expired: GameAudio.cue(self, &"armour")
	else:
		ring_age = 0.0
		_play_bell()
		opened.emit()

func cancel_pending() -> void:
	ring_age = 1.0
	queue_redraw()
	expiration_pending = false
	packet_receipts.clear()
	super.cancel_pending()

func _physics_process(delta: float) -> void:
	if elements == null: return
	_clock += delta
	ring_age = minf(1.0,ring_age+delta)
	if is_open and duration > 0 and _clock-_opened_at >= duration:
		expiration_pending = true
		if can_commit(): activation_requested.emit(element_id)
	for packet: String in packet_receipts.keys():
		if packet_receipts[packet].expires < _clock: packet_receipts.erase(packet)
	for key: String in _eligible_shots.keys():
		if _eligible_shots[key].expires < _clock: _eligible_shots.erase(key)
	if not _pending.is_empty():
		var request := _pending; _pending = {}; _commit_open.call_deferred(request)
	if duration>0 or ring_age < .8: queue_redraw()

func _draw() -> void:
	if elements == null: return
	BellGateArt.bell(self,bell_position,ring_age,is_open)
	for point: Vector2 in access_positions: BellGateArt.bell(self,point,ring_age,is_open)
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
			BellGateArt.countdown(self,corner+Vector2(target.bounds.size.x,0),left)
