class_name WorldTerrainReturn
extends Node2D
## Terrain branch of the fixed world's accepted-damage timeline. The room
## owns the safe anchor and the player motor owns every actual relocation.
var host: WorldGameHost
var source: OrdinaryRoomSession
var body: UnderworldPlayer
var body_mode: ProcessMode
var camera_mode: ProcessMode
var phase := &"impact"
var age := 0.0
var impact := Vector2.ZERO
var reduced := false
var suspended := false
var waiting := false
var relocated := false
var saved := false
var prior_pause := false
var retry_button: Button
var cover_frame := 0
var retry_finger := -1

func begin(owner_host: WorldGameHost) -> void:
	host = owner_host
	source = host.active
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	impact = source.player.global_position+Vector2(0,-7)
	reduced = source.camera.reduced_effects
	host.last_error = ""
	host.crossing = true
	source.policy.protect_player()
	host._lock_session(true)
	source.controller.air_focus_ability.stop()
	body = PlayerPresentationRuntime.current_body(source.player)
	if body != null:
		body_mode = body.process_mode
		body.process_mode = Node.PROCESS_MODE_ALWAYS
	camera_mode = source.camera.process_mode
	source.camera.process_mode = Node.PROCESS_MODE_ALWAYS
	host.curtain.color = Color.TRANSPARENT
	host.curtain.show()
	prior_pause = get_tree().paused
	get_tree().paused = true

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		suspended = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		suspended = false
	else: return
	if phase!=&"done" and is_instance_valid(source):
		var mode := Node.PROCESS_MODE_PAUSABLE if suspended else Node.PROCESS_MODE_ALWAYS
		if is_instance_valid(body): body.process_mode=mode
		source.camera.process_mode=mode

func _physics_process(delta: float) -> void:
	if phase == &"done" or host == null: return
	if host.active != source or not source.lifetime.active:
		cancel()
		return
	if suspended or not source.controller.router.has_application_focus or waiting: return
	var settings := source.player.damage_feedback
	var dt := delta / maxf(Engine.time_scale,.001)
	age += dt
	queue_redraw()
	match phase:
		&"impact":
			if age >= settings.hazard_impact_seconds: _phase(&"conceal")
		&"conceal":
			_cover(smoothstep(0,1,age/settings.hazard_conceal_seconds))
			if age >= settings.hazard_conceal_seconds:
				_cover(1.0)
				_phase(&"return")
		&"return":
			# Multiple physics ticks can run before rendering one frame.
			if Engine.get_process_frames() < cover_frame+2: return
			if not relocated:
				if not source.recovery.relocate(source):
					_failed("terrain_anchor_unavailable","当前进入侧没有安全落点。")
					return
				relocated = true
				impact = Vector2.INF
			source.player.step(0,dt)
			if not source.player.is_on_floor():
				if age > .35: _failed("terrain_support_unavailable","进入侧落点缺少脚下支撑。")
				return
			if not saved:
				if not source.checkpoint(true):
					_failed("terrain_save_failed","无法保存本次受伤进度。")
					return
				saved = true
			source.camera.reset_view()
			_phase(&"reveal")
		&"reveal":
			_cover(1.0-smoothstep(0,1,age/settings.hazard_reveal_seconds))
			if age >= settings.hazard_reveal_seconds: finish()

func _phase(next: StringName) -> void:
	phase = next
	age = 0
	if next == &"return": cover_frame = Engine.get_process_frames()

func _cover(alpha: float) -> void:
	host.curtain.color = Color(0,0,0,alpha)

func _failed(error: String, message: String) -> void:
	waiting = true
	host.last_error = error
	host.notice.text = message
	host.notice.modulate.a = 1
	host.notice.show()
	_cover(0)
	if retry_button == null:
		retry_button = Button.new()
		retry_button.text = "重试安全返回"
		retry_button.theme = DemoClockworkTheme.create_theme()
		retry_button.process_mode = Node.PROCESS_MODE_ALWAYS
		host.curtain.get_parent().add_child(retry_button)
		retry_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		retry_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
		retry_button.pressed.connect(retry)
	retry_button.show()
	retry_button.grab_focus()

func _input(event: InputEvent) -> void:
	if not waiting or not event is InputEventScreenTouch: return
	var inside := retry_button.get_global_rect().has_point(event.position)
	if event.pressed and inside and retry_finger<0:
		retry_finger=event.index
	elif not event.pressed and event.index==retry_finger:
		retry_finger=-1
		if inside and not event.canceled: retry()
	else: return
	get_viewport().set_input_as_handled()

func retry() -> void:
	if not waiting: return
	waiting = false
	retry_button.hide()
	host.notice.hide()
	host.last_error = ""
	_cover(1)
	_phase(&"return")

func finish() -> void:
	source.policy.protect_player()
	host._lock_session(false)
	cancel()

func cancel() -> void:
	if phase==&"done": return
	_phase(&"done")
	if is_instance_valid(body): body.process_mode=body_mode
	if is_instance_valid(source) and is_instance_valid(source.camera): source.camera.process_mode=camera_mode
	if is_instance_valid(retry_button): retry_button.queue_free()
	if is_instance_valid(host) and host.terrain_return==self:
		host.terrain_return=null
		host.curtain.hide()
		host.notice.hide()
		host.crossing=false
	if is_inside_tree(): get_tree().paused=prior_pause
	queue_free()

func _exit_tree() -> void:
	if phase!=&"done" and host!=null: cancel()

func _draw() -> void:
	if reduced or phase!=&"impact" or not impact.is_finite(): return
	var fade := clampf(1.0-age/.32,0,1)
	var center := to_local(impact)
	for i: int in 12:
		var axis := Vector2.from_angle(i*TAU/12+.12)
		var point := center+axis*(8+age*105)
		draw_line(point,point+axis*(3+fade*8),Color(.97,.87,.61,fade),2)
