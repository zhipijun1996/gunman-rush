class_name WorldWaveEncounter
extends Node2D
## Authored finite waves; real enemy actors and the existing action receipt own results.
var app: FixedWorldApp
var settings: Dictionary
var wave := -1
var started := false
var finished := false
var warning := 0.0
var active_ids: Array[String] = []
var _launch_pending := false
var _exit_gate: StaticBody2D
var _entry_gate: StaticBody2D

func setup(application: FixedWorldApp) -> void:
	app=application;settings=app.room.wave_encounter
	_exit_gate=_gate(FixedWorldProvider.rect(settings.exit_gate))
	_entry_gate=_gate(FixedWorldProvider.rect(settings.entry_gate))
	_entry_gate.collision_layer=0
	finished=app.state.value.receipts.has(str(settings.completion_action))
	if finished:_exit_gate.collision_layer=0
	queue_redraw()

func _gate(rect: Rect2) -> StaticBody2D:
	var body:=StaticBody2D.new()
	body.position=rect.get_center();body.collision_layer=1;body.collision_mask=0
	var shape:=CollisionShape2D.new()
	var box:=RectangleShape2D.new();box.size=rect.size;shape.shape=box
	body.add_child(shape);add_child(body)
	return body

func _physics_process(delta: float) -> void:
	if app==null or app.paused or app.busy or finished:return
	if app.state.value.receipts.has(str(settings.completion_action)):
		finished=true;app.room.battle_finished=true
		_exit_gate.set_deferred("collision_layer",0)
		_entry_gate.set_deferred("collision_layer",0)
		GameAudio.cue(self,&"bell");queue_redraw();return
	if not started:
		var trigger:=FixedWorldProvider.rect(settings.trigger)
		if not trigger.encloses(Rect2(app.player.position-Vector2(12,18),Vector2(24,36))) or not app.player.is_on_floor():return
		started=true;app.room.battle_started=true;app.room.battle_finished=false
		app.entry_anchor=FixedWorldProvider.point(settings.recovery_point)
		_entry_gate.set_deferred("collision_layer",1)
		_next_wave()
	if warning>0:
		warning=maxf(0,warning-delta);queue_redraw()
		if warning<=0 and not _launch_pending:
			_launch_pending=true;_spawn.call_deferred()
		return
	if _launch_pending:return
	for id: String in active_ids:
		if app.room.enemies.has(id) and not (app.room.enemies[id] as EnemyActor).health.terminal:return
	if not active_ids.is_empty():
		active_ids.clear()
		if wave+1>=settings.waves.size():app.enqueue("action",str(settings.completion_action))
		else:_next_wave()
	elif wave+1>=settings.waves.size():app.enqueue("action",str(settings.completion_action))

func _next_wave() -> void:
	wave+=1;warning=1.0;_launch_pending=false
	GameAudio.cue(self,&"bell")
	queue_redraw()

func _spawn() -> void:
	if not is_instance_valid(app.room) or finished:return
	for spec: Dictionary in settings.waves[wave]:
		var actor:=app.room.spawn_enemy(spec,app.controller,app.policy,app.lifetime,{},app.entry_anchor)
		actor.set_meta("wave_attempt",true)
		active_ids.append(str(spec.id))
	_launch_pending=false
	queue_redraw()

func _draw() -> void:
	if settings.is_empty():return
	if not finished:
		draw_rect(FixedWorldProvider.rect(settings.exit_gate),Color("8d7854"))
		if started:draw_rect(FixedWorldProvider.rect(settings.entry_gate),Color("8d7854"))
	if started and not finished:
		var at:=FixedWorldProvider.point(settings.label_point)
		draw_string(GameTypography.FONT,at,"守望试炼 · %d / %d" % [wave+1,settings.waves.size()],HORIZONTAL_ALIGNMENT_CENTER,-1,18,Color("e8d7b0"))
	if warning>0:
		for spec: Dictionary in settings.waves[wave]:
			var at:=FixedWorldProvider.point(spec.point)
			draw_arc(at,24+warning*12,0,TAU,24,Color(1,.75,.4,.8),2)
