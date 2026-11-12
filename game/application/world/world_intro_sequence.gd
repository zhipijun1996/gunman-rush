class_name WorldIntroSequence
extends Node2D
## First-visit tutorial presentation. Progress is committed by FixedWorldApp.
var app: FixedWorldApp
var settings: Dictionary = {}
var phase := ""
var lines: Array = []
var line_index := 0
var dialogue_active := false
var _serial := 0
var _pose: Tween
var _body: UnderworldPlayer

func enter() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	settings=app.room.intro_sequence
	if settings.is_empty():
		app.controller.shoot_ability.enabled=true;set_physics_process(false);return
	phase="pending" if settings.get("kind")=="wake" and not app.state.has("intro_gun") else "traveler" if settings.get("kind")=="traveler" and not app.state.has("intro_traveler") else "done"
	app.controller.shoot_ability.enabled=phase!="pending"
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if app==null or not is_instance_valid(app.player) or not is_instance_valid(app.controller) or app.busy or app.paused or not is_instance_valid(app.room):return
	if phase=="pending":
		phase="waking"
		_wake()
	elif phase=="traveler" and FixedWorldProvider.rect(settings.trigger).has_point(app.player.position) and app.player.is_on_floor():
		phase="talking"
		_show_lines(settings.lines,"旅人")

func _wake() -> void:
	_serial+=1
	var serial:=_serial
	var session:=app.controller.session_id
	app.controller.active=false
	app.controller.router.clear("tutorial_wake")
	_body=PlayerPresentationRuntime.current_body(app.player)
	if _body!=null:
		_body.authored_pose.begin_wake(app.controller)
	_pose=create_tween()
	_pose.tween_interval(PlayerAuthoredPoses.WAKE_SECONDS)
	await _pose.finished
	if serial!=_serial or not is_instance_valid(app.player) or app.controller.session_id!=session:return
	if is_instance_valid(_body) and not _body.authored_pose.waking:return
	if is_instance_valid(_body):_body.authored_pose.clear()
	app.controller.active=true
	phase="pickup"
	_show_lines(["我在哪？"],"修钟者")

func target() -> Dictionary:
	if phase!="pickup" or dialogue_active:return {}
	if app.player.position.distance_to(FixedWorldProvider.point(settings.pickup_point))>64:return {}
	return {"kind":"intro_pickup","id":"intro_pickup_gun","label":"拾取 · 地上的枪"}

func pickup() -> void:
	if target().is_empty():return
	app._commit_action("intro_pickup_gun")
	if not app.state.has("intro_gun"):return
	app.controller.shoot_ability.enabled=true
	phase="picked"
	GameAudio.cue(app,&"confirm")
	var input: StringName=app.controller.router.current_device
	var instruction:="按住鼠标左键瞄准，松开开枪"
	if app.controller.router.touch_enabled:instruction="拖动右侧射击摇杆瞄准，松开开枪"
	elif input==&"gamepad":instruction="推动右摇杆进入慢时瞄准，按下 RB／R1 开枪"
	_show_lines(["我想起来了，可以"+instruction+"。","前面的风铃连着门。试着击中它。"],"修钟者")
	queue_redraw()

func _show_lines(value: Array,title: String) -> void:
	if not app._pause_world():return
	lines=value;line_index=0;dialogue_active=true
	set_meta("speaker",title)
	_present_line()

func _present_line() -> void:
	var panel:=app.ui.panel("dialogue",str(get_meta("speaker")),str(lines[line_index]))
	panel.button("继续" if line_index+1<lines.size() else "明白了",advance)
	panel.focus_first()

func advance() -> void:
	if not dialogue_active:return
	line_index+=1
	if line_index<lines.size():_present_line();return
	dialogue_active=false
	app._close_panel()
	if phase=="talking":
		var candidate:=WorldTraveler.talk_candidate(app.state,app.room.room_id)
		if not candidate.is_empty() and not app.state.commit(candidate,app.state.revision):return
		app._commit_action("intro_meet_traveler")
		phase="done" if app.state.has("intro_traveler") else "traveler"
	elif phase=="picked":phase="done"

func _draw() -> void:
	if settings.get("kind")!="wake" or phase in ["picked","done"]:return
	var at:=FixedWorldProvider.point(settings.pickup_point)+Vector2(0,12)
	# The ground pickup shares the existing brass/ink weapon palette.
	draw_line(at+Vector2(-15,-4),at+Vector2(17,-4),Color("171d25"),10)
	draw_line(at+Vector2(-15,-4),at+Vector2(17,-4),Color("c9a46d"),5)
	draw_line(at+Vector2(-5,-3),at+Vector2(-9,6),Color("755035"),6)
	draw_line(at+Vector2(5,-4),at+Vector2(17,-4),Color("e8d7b0"),2)
	draw_polyline(PackedVector2Array([at+Vector2(-4,-29),at+Vector2(0,-25),at+Vector2(4,-29)]),Color("e8d7b0"),2)

func _exit_tree() -> void:
	_serial+=1
	if _pose!=null and _pose.is_valid():_pose.kill()
	if is_instance_valid(_body):_body.authored_pose.clear()
