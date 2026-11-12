class_name WorldRestSequence
extends Node
## Explicit presentation owns the temporary freeze; only FixedWorldApp commits rest.
const SETTINGS := preload("res://game/presentation/world/station/rest_presentation.tres")
var app: FixedWorldApp
var active := false
var suspended := false
var phase := "approach"
var age := 0.0
var committed := false
var attempted := false
var session := -1
var room_owner: FixedWorldRoom
var body: UnderworldPlayer
var station: WorldChargingStation
var old_body_mode := Node.PROCESS_MODE_INHERIT
var old_station_mode := Node.PROCESS_MODE_INHERIT
var old_facing := 1.0
var flash: ColorRect
var flash_age := -1.0

func begin(application: FixedWorldApp) -> bool:
	app = application
	if app.controller == null or not app.controller.active or not app.player.is_on_floor(): return false
	body = PlayerPresentationRuntime.current_body(app.player)
	if body!=null and (body._hurt_remaining>0 or body._dead):return false
	if app.room.rest_point == Vector2.ZERO or absf(app.player.position.y-app.room.rest_point.y)>6: return false
	if app._fatal or app._return or not app._pause_world(): return false
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = true
	room_owner = app.room
	session = app.controller.session_id
	app.controller.active = false
	app.controller.shoot_ability.clear_projectiles()
	app.player.reset_motion()
	body = PlayerPresentationRuntime.current_body(app.player)
	if body != null:
		old_body_mode = body.process_mode
		old_facing = body.facing
		body.process_mode = Node.PROCESS_MODE_ALWAYS
		body.authored_pose.clear()
	station = room_owner.station_animation
	if station != null:
		old_station_mode = station.process_mode
		station.process_mode = Node.PROCESS_MODE_ALWAYS
	flash = ColorRect.new()
	flash.color = Color(.70,.91,.87,0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.ui.root.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.status = WorldText.text("rest.entering")
	return true

func _physics_process(delta: float) -> void:
	if not active: return
	if not is_instance_valid(app.controller) or not is_instance_valid(room_owner) or app.room!=room_owner or app.controller.session_id!=session or app.controller.actor_resources.health.terminal or not app.lifetime.active:
		finish();return
	if suspended: return
	if app.policy!=null and app.policy.has_pending_player_damage():
		finish();return
	age += delta
	if flash_age>=0:
		flash_age += delta
		var strength := SETTINGS.reduced_flash_alpha if bool(app.preferences.value.reduced) else SETTINGS.flash_alpha
		flash.color.a = strength*sin(PI*clampf(flash_age/SETTINGS.flash_seconds,0,1))
		if flash_age>=SETTINGS.flash_seconds: flash_age=-1;flash.color.a=0
	match phase:
		"approach":
			var distance := room_owner.rest_point.x-app.player.position.x
			if not app.player.is_on_floor():
				app.status=WorldText.text("rest.blocked")
				finish();return
			elif absf(distance)<=1.5:
				app.player.reset_motion()
				_set_phase("enter")
			elif age>=SETTINGS.approach_timeout:
				app.status=WorldText.text("rest.blocked")
				finish();return
			else:
				app.player.step(clampf(distance*8,-SETTINGS.approach_speed,SETTINGS.approach_speed)/app.player.tuning.ground_speed,delta)
		"enter":
			_pose(1+mini(3,int(age/SETTINGS.entry_seconds*4)), -SETTINGS.depth_step*smoothstep(0,1,age/SETTINGS.entry_seconds))
			if age>=SETTINGS.entry_seconds:
				_set_phase("charge")
				GameAudio.cue_rest(self,&"rest_current")
		"charge":
			_pose(4+posmod(int(age*5),3),-SETTINGS.depth_step)
			if station!=null: station.charge = minf(1,age/.25)
			if not attempted and age>=SETTINGS.commit_seconds:
				attempted=true
				committed=app._commit_rest()
				if committed:
					flash_age=0
					GameAudio.cue_rest(self,&"rest_restore")
					if station!=null: station.success=1
				else:
					GameAudio.stop_origin(self,false)
					_set_phase("exit")
			if age>=SETTINGS.charge_seconds: _set_phase("exit")
		"exit":
			_pose(7+mini(3,int(age/SETTINGS.exit_seconds*4)), -SETTINGS.depth_step*(1-smoothstep(0,1,age/SETTINGS.exit_seconds)))
			if station!=null:station.charge=maxf(0,1-age/.3)
			if age>=SETTINGS.exit_seconds: finish()

func _set_phase(value: String) -> void:
	phase=value;age=0
	if phase=="enter":
		if body!=null:
			old_facing=body.facing
			body.authored_pose.begin_rest(app.controller)
		GameAudio.cue_rest(self,&"rest_contact")
	elif phase=="exit": GameAudio.stop_origin(self,true)

func _pose(index: int, depth: float) -> void:
	if station!=null:station.set_occupied(depth < -SETTINGS.depth_step*.5)
	if body!=null:
		body.facing=old_facing
		body.authored_pose.rest_frame=index
		body.authored_pose.rest_depth=depth

func suspend(value: bool) -> void:
	if not active:return
	suspended=value
	if body!=null:body.process_mode=Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_ALWAYS
	if station!=null:station.process_mode=Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_ALWAYS
	var host:=GameAudio.for_origin(self) as GameAudio
	if host!=null:host.pause_origin(self,value)

func finish() -> void:
	if not active:return
	active=false
	GameAudio.stop_origin(self,false)
	if is_instance_valid(flash):flash.queue_free()
	if is_instance_valid(body):
		body.authored_pose.clear()
		body.process_mode=old_body_mode
		body.facing=old_facing
	if is_instance_valid(station):
		station.charge=0;station.success=0
		station.set_occupied(false)
		station.process_mode=old_station_mode
	if is_instance_valid(app.controller) and app.controller.session_id==session:
		app.controller.router.clear("rest_finished")
		app.player.reset_motion()
		app.controller.active=not app.controller.actor_resources.health.terminal
	app.paused=false
	get_tree().paused=false
	# Rest covers key releases just like a modal. Reconcile physical neutrality
	# so the next deliberate Up interacts, while a held key remains blocked.
	if is_instance_valid(app.player):
		var keyboard:=app.player.get_node_or_null("KeyboardMouseAdapter") as KeyboardMouseAdapter
		if keyboard!=null:keyboard.observe_current_key_neutral()
	queue_free()

func _exit_tree() -> void:
	finish()
