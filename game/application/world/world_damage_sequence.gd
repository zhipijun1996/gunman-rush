class_name WorldDamageSequence
extends Node2D
## One accepted-result presentation. World facts stay in Policy/App; movement
## and covered relocation stay in Motor. Never changes Engine.time_scale.
const SETTINGS: DamageFeedbackDefinition = preload("res://game/combat/damage/feedback.tres")
var app: FixedWorldApp
var active := false
var kind := ""
var age := 0.0
var relocated := false
var body: UnderworldPlayer
var body_mode := Node.PROCESS_MODE_INHERIT
var owner_room: FixedWorldRoom
var session := -1
var impact := Vector2.ZERO
var suspended := false
var visual_tail := false
var show_impact := true

func begin(application: FixedWorldApp, result: String) -> void:
	app = application
	kind = result
	show_impact = kind != "terrain" or not (app.review.active and app.review.invincible)
	owner_room = app.room
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	active = true
	app.busy = true
	app.controller.router.clear("accepted_" + kind)
	app.controller.air_focus_ability.stop()
	if kind == "death": app.controller.die()
	else: app.controller.active = false
	session = app.controller.session_id
	impact = app.player.global_position + Vector2(0, -7)
	body = PlayerPresentationRuntime.current_body(app.player)
	if body != null:
		body_mode = body.process_mode
		if kind != "hit": body.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	if show_impact and not bool(app.preferences.value.reduced):
		(app.camera as WorldCamera).shake(SETTINGS.death_shake if kind == "death" else SETTINGS.impact_shake, .18)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: suspended = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: suspended = false

func _physics_process(delta: float) -> void:
	# A terminal airborne body still falls onto real support. The inactive
	# Controller cannot also step; no presentation code assigns a body position.
	if active and kind == "death" and not suspended and is_instance_valid(app.controller) and app.controller.session_id == session and app.room == owner_room and not app.player.is_on_floor():
		app.player.step(0.0, delta)

func _process(delta: float) -> void:
	if not active:
		if visual_tail:
			age += delta / maxf(Engine.time_scale, .001)
			queue_redraw()
			if age >= .32 or not is_instance_valid(app.controller) or app.controller.session_id != session: queue_free()
		return
	if not is_instance_valid(app.controller) or app.room != owner_room or app.controller.session_id != session:
		cancel()
		return
	if suspended: return
	age += delta / maxf(Engine.time_scale, .001)
	queue_redraw()
	match kind:
		"hit":
			if age >= SETTINGS.hit_hold_seconds: finish()
		"terrain":
			var cover_at := SETTINGS.hazard_impact_seconds if show_impact else 0.0
			var move_at := cover_at + SETTINGS.hazard_conceal_seconds
			if age < cover_at: return
			if not relocated:
				_cover(smoothstep(0, 1, (age-cover_at)/SETTINGS.hazard_conceal_seconds))
				if age >= move_at:
					_cover(1.0)
					if not app._complete_terrain_return():
						cancel(false)
						return
					relocated = true
					session = app.controller.session_id
			else:
				_cover(1.0-smoothstep(0, 1, (age-move_at)/SETTINGS.hazard_reveal_seconds))
				if age >= move_at+SETTINGS.hazard_reveal_seconds: finish()
		"death":
			if age < SETTINGS.death_body_seconds: return
			_cover(smoothstep(0, 1, (age-SETTINGS.death_body_seconds)/SETTINGS.death_conceal_seconds))
			if age >= SETTINGS.death_body_seconds+SETTINGS.death_conceal_seconds:
				_cover(1.0)
				# No asynchronous callback survives the room/actor that accepted death.
				_release()
				app._recover_death()
				queue_free()

func _cover(alpha: float) -> void:
	app.ui.curtain.color = Color(0, 0, 0, clampf(alpha, 0, 1))
	app.ui.curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	app.ui.curtain.show()

func _release() -> void:
	active = false
	if is_instance_valid(body): body.process_mode = body_mode
	if is_inside_tree(): get_tree().paused = false

func finish() -> void:
	_release()
	app.ui.curtain.hide()
	app.controller.active = true
	app.busy = false
	if kind == "terrain": app.policy.protect_player()
	if kind == "hit": visual_tail = true
	else: queue_free()

func cancel(resume := true) -> void:
	if not active:
		if visual_tail: queue_free()
		return
	_release()
	if is_instance_valid(app.ui): app.ui.curtain.hide()
	if resume and is_instance_valid(app.controller) and not app.controller.actor_resources.health.terminal:
		app.controller.active = true
		app.busy = false
	queue_free()

func _exit_tree() -> void:
	if active: _release()

func _draw() -> void:
	if (not active and not visual_tail) or not show_impact: return
	var fade := clampf(1.0-age/.32, 0, 1)
	var center := to_local(impact)
	# Small warm clock-sparks read against both plains daylight and dark interiors.
	# No full-screen white flash, black character or procedural sprite distortion.
	for i: int in 12:
		var axis := Vector2.from_angle(i*TAU/12+.12)
		var point := center + axis*(8+age*105)
		PixelVfx.streak(self,point,axis,3+fade*8,maxf(.4,fade),Color(.97,.87,.61,fade))
	if kind == "death":
		var lift := maxf(0, age-.18)
		for i: int in 14:
			var phase := float(i)/14
			var point := center + Vector2(sin(i*2.4)*lift*34, -lift*(25+phase*55))
			var alpha := sin(PI*clampf(lift/.95,0,1))*.85
			PixelVfx.shard(self,point,Vector2.from_angle(i+lift),2+alpha*2,.75,Color(.94,.78,.43,alpha))
		PixelVfx.clip(self,&"dissolve",center,clampf(lift/.95,0,1))
