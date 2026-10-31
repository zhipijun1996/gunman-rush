class_name PlayerWeaponFeelV2
extends PlayerWeaponFeel
## V2 only: actual damage receipts, producer-scoped audio and optional draw leaf.
var renderer: PlayerWeaponVfxV2
var _previous_renderer: CanvasItem
var _previous_audio: Callable
var _mine_beeps: Dictionary = {}
var _hit_clock := 0.0
var _last_hit := -100.0

func _ready() -> void:
	super._ready()
	if not is_instance_valid(runtime): return
	_previous_renderer=runtime.presentation
	_previous_audio=runtime.audio_override
	renderer=PlayerWeaponVfxV2.new()
	renderer.runtime=runtime
	renderer.controller=controller
	renderer.opacity=profile.accent_opacity
	add_child(renderer)
	runtime.presentation=renderer
	runtime.audio_override=_runtime_audio
	controller.weapon_damage_committed.connect(_enemy_hit)
	set_candidate_enabled(enabled_candidate)

func set_candidate_enabled(value: bool) -> void:
	super.set_candidate_enabled(value)
	if is_instance_valid(renderer): renderer.visible=enabled_candidate
	if is_instance_valid(runtime): runtime.queue_redraw()
	if enabled_candidate and is_instance_valid(runtime):
		if runtime.phase==&"beam": _loop(&"ion_loop")
		elif runtime.phase==&"singularity": _loop(&"blackhole_loop")

func clear() -> void:
	super.clear()
	_mine_beeps.clear()
	_last_hit=-100.0

func _runtime_audio(id: StringName) -> bool:
	# This callback belongs to this specific Runtime, never the global service.
	if not enabled_candidate: return _previous_audio.call(id)==true if _previous_audio.is_valid() else false
	return id in [&"focus_start",&"jump",&"confirm",&"impact"]

func _shot(axis: Vector2, serial: int) -> void:
	super._shot(axis,serial)
	for projectile: PlayerProjectile in controller.shoot_ability._projectiles:
		if is_instance_valid(projectile) and projectile.shot_id==serial:
			projectile.terrain_impacted.connect(_wall.bind(projectile))

func _contact(point: Vector2, axis: Vector2, projectile: PlayerProjectile, mode: int) -> void:
	if not enabled_candidate: return
	# Contact spark alone never claims HP loss; only the receipt plays enemy-hit.
	_effect(&"contact",point,-axis,profile.contact_seconds,10 if mode==WeaponDefinition.Mode.MACHINE else 14)
	events.append({"type":"contact","tick":Engine.get_physics_frames(),"serial":projectile.shot_id,"point":[point.x,point.y]})
	if events.size()>256: events.pop_front()

func _wall(_point: Vector2, _axis: Vector2, projectile: PlayerProjectile) -> void:
	_sound(&"wall","wall/%s/%s/%s" % [projectile.weapon_epoch,projectile.energy_receipt_id,Engine.get_physics_frames()],17)

func _enemy_hit(packet: int, shot: int, receiver: Damageable, source_session: int, source_weapon_epoch: int) -> void:
	_sync_identity()
	if not enabled_candidate or not is_instance_valid(receiver) or receiver.faction!=&"enemy": return
	if source_session!=_session or source_weapon_epoch!=_epoch: return
	var tick := Engine.get_physics_frames()
	# A beam/pellet volley cannot pile a dozen hit transients on one audio frame.
	if _hit_clock-_last_hit<.055: return
	_last_hit=_hit_clock
	_sound(&"hit","enemy_hit/%s/%s/%s/%s" % [_epoch,packet,shot,tick],10)
	events.append({"type":"enemy_damage_committed","tick":tick,"packet":packet,"shot":shot})
	if events.size()>256: events.pop_front()

func _loop(cue: StringName) -> void:
	_sound(cue,"loop/%s/%s/%s" % [_epoch,controller.shoot_ability.packet_id,cue],profile.sustained_attenuation,true)

func _phase(value: StringName) -> void:
	_sync_identity()
	audio.stop_weapon(_owner,true)
	var packet := controller.shoot_ability.packet_id
	if value==&"beam":
		_sound(&"ion_start","ion_start/%s/%s" % [_epoch,packet],10)
		_loop(&"ion_loop")
	elif value==&"singularity":
		_sound(&"blackhole_start","blackhole_start/%s/%s" % [_epoch,packet],11)
		_loop(&"blackhole_loop")
	elif value==&"charge" and controller.shoot_ability.weapon.mode==WeaponDefinition.Mode.LASER:
		_sound(&"ion_start","charge/%s/%s" % [_epoch,packet],13,true)
	if value==&"idle" and _previous_phase==&"beam":
		_sound(&"ion_tail","ion_tail/%s/%s" % [_epoch,packet],15)
	var released := false
	for fx: Dictionary in runtime._fx:
		if fx.kind=="beam" and bool(fx.skill) and float(fx.age)<=.001: released=true
	if value==&"idle" and _previous_phase==&"charge" and controller.shoot_ability.weapon.mode==WeaponDefinition.Mode.LASER and released:
		_sound(&"ion_start","cannon/%s/%s" % [_epoch,packet],9)
	_previous_phase=value

func _blast(_point: Vector2) -> void:
	_sync_identity()
	var ability := controller.shoot_ability
	var cue: StringName=&"blackhole_burst" if ability.weapon.mode==WeaponDefinition.Mode.SINGULARITY else &"blast"
	_sound(cue,"blast/%s/%s/%s" % [_epoch,ability.packet_id,Engine.get_physics_frames()],9)

func _entity_transition(entity: WeaponEntity, value: StringName) -> void:
	_sync_identity()
	if value==&"returning":
		_sound(&"boomerang_return","return/%s/%s" % [_epoch,entity.serial],10)
	elif value==&"attached":
		_sound(&"wall","attached/%s/%s" % [_epoch,entity.serial],19)
	elif value==&"caught" and not entity.manual_recall:
		_sound(&"boomerang_return","catch/%s/%s" % [_epoch,entity.serial],17)

func _physics_process(delta: float) -> void:
	_hit_clock+=delta
	super._physics_process(delta)
	if not enabled_candidate or not controller.active: return
	var alive: Dictionary = {}
	for entity: WeaponEntity in runtime.entities:
		if not is_instance_valid(entity) or entity.spent or entity.kind!=&"mine": continue
		var id := entity.get_instance_id()
		alive[id]=true
		if not _mine_beeps.has(id): _mine_beeps[id]=maxf(.2,entity.age+.05)
		if entity.age<float(_mine_beeps[id]): continue
		var duration := runtime.definition().mine_fuse_seconds
		if duration<=0: continue
		var t := clampf(entity.age/duration,0,1)
		_sound(&"mine_beep","beep/%s/%s/%s" % [_epoch,entity.serial,Engine.get_physics_frames()],lerpf(18,12,t))
		_mine_beeps[id]=entity.age+lerpf(.95,.12,t*t)
	for id: int in _mine_beeps.keys():
		if not alive.has(id): _mine_beeps.erase(id)

func _draw() -> void:
	if not enabled_candidate or not is_instance_valid(controller) or not controller.active: return
	for fx: Dictionary in effects:
		var p := float(fx.age)/float(fx.life)
		var center := to_local(fx.point)
		for i: int in 4:
			var axis: Vector2=fx.axis.rotated((i-1.5)*.5)
			var start := center+axis*(2+p*float(fx.radius))
			draw_line(start,start+axis*6*(1-p),Color(1,.9,.65,(1-p)*profile.accent_opacity),2,false)
	for entity: WeaponEntity in runtime.entities:
		if not is_instance_valid(entity) or entity.spent or entity.kind!=&"mine": continue
		var t := clampf(entity.age/maxf(.01,runtime.definition().mine_fuse_seconds),0,1)
		var center := to_local(entity.global_position)
		var strength := .55+.45*sin(entity.age*(7+32*t*t))
		draw_circle(center+Vector2(0,-10),3,Color(1,.12+.5*(1-t),.08,strength))
		draw_arc(center,16,0,TAU*t,20,Color(1,.4,.15,.75),2,false)

func _exit_tree() -> void:
	if is_instance_valid(controller) and controller.weapon_damage_committed.is_connected(_enemy_hit): controller.weapon_damage_committed.disconnect(_enemy_hit)
	if is_instance_valid(runtime):
		if runtime.presentation==renderer: runtime.presentation=_previous_renderer if is_instance_valid(_previous_renderer) else null
		if runtime.audio_override==_runtime_audio: runtime.audio_override=_previous_audio
		runtime.queue_redraw()
	super._exit_tree()
