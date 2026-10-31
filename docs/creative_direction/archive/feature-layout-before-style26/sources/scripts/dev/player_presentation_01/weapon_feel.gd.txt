class_name PlayerWeaponFeel
extends Node2D
## Read-only accepted-event consumer. No Runtime, Motor or damage overrides.
var controller: PlayerController
var audio: PlayerWeaponFeelAudio
var profile := PlayerWeaponFeelProfile.new()
var enabled_candidate := true
var legacy: PlayerFeedback
var runtime: WeaponActionRuntime
var effects: Array[Dictionary] = []
var leaves: Array[PlayerWeaponFeelProjectile] = []
var events: Array[Dictionary] = []
var _seen_entities: Dictionary = {}
var _sound_keys: Dictionary = {}
var _owner := 0
var _epoch := -1
var _session := -1
var _previous_phase: StringName = &"idle"

func _ready() -> void:
	_owner=controller.motor.get_instance_id()
	runtime=controller.shoot_ability.runtime
	if runtime==null:
		push_error("Weapon sample requires the already initialized original Runtime")
		enabled_candidate=false
		set_process(false)
		set_physics_process(false)
		return
	legacy=controller.motor.get_node("PlayerFeedback") as PlayerFeedback
	if controller.shoot_ability.shot_fired.is_connected(legacy._shot): controller.shoot_ability.shot_fired.disconnect(legacy._shot)
	if controller.shoot_ability.projectile_impacted.is_connected(legacy._impact): controller.shoot_ability.projectile_impacted.disconnect(legacy._impact)
	controller.shoot_ability.shot_fired.connect(_shot)
	controller.shoot_ability.projectile_impacted.connect(_legacy_contact)
	runtime.phase_changed.connect(_phase)
	runtime.blast_fired.connect(_blast)
	runtime.entity_transition.connect(_entity_transition)
	controller.died.connect(clear)
	controller.segment_returned.connect(clear)
	controller.actor_resources.health.changed.connect(_health_changed)
	z_index=10
	process_physics_priority=8
	_epoch=controller.shoot_ability.weapon_epoch
	_session=controller.session_id
	set_candidate_enabled(enabled_candidate)

func set_candidate_enabled(value: bool) -> void:
	enabled_candidate=value and is_instance_valid(profile) and profile.valid() and is_instance_valid(runtime) and is_instance_valid(controller) and is_instance_valid(audio)
	clear()
	for leaf: PlayerWeaponFeelProjectile in leaves:
		if is_instance_valid(leaf):
			if enabled_candidate: leaf.trail_opacity=profile.trail_opacity
			leaf.set_active(enabled_candidate)

func clear() -> void:
	effects.clear()
	_sound_keys.clear()
	if is_instance_valid(audio): audio.stop_weapon(_owner)
	queue_redraw()

func _health_changed(result: ActorResourceResult) -> void:
	if result.operation==&"damage" and result.status==ActorResourceResult.Status.APPLIED and result.amount_applied<0: clear()

func _sound(cue: StringName, key: String, attenuation := -1.0, sustained := false) -> void:
	if not enabled_candidate or _sound_keys.has(key): return
	_sound_keys[key]=true
	if _sound_keys.size()>256: _sound_keys.erase(_sound_keys.keys()[0])
	audio.weapon_cue(cue,_owner,key,profile.shot_attenuation if attenuation<0 else attenuation,sustained,controller.shoot_ability.weapon.id)

func _effect(kind: StringName, point: Vector2, axis: Vector2, life: float, radius := 12.0) -> void:
	if not enabled_candidate: return
	if effects.size()>=profile.transient_cap: effects.pop_front()
	effects.append({"kind":kind,"point":point,"axis":axis,"age":0.0,"life":life,"radius":radius})

func _shot(axis: Vector2, serial: int) -> void:
	_sync_identity()
	var ability := controller.shoot_ability
	var mode := ability.weapon.mode
	var cue: StringName = &"blade" if mode in [WeaponDefinition.Mode.SHURIKEN,WeaponDefinition.Mode.FAN] else &"machine" if mode==WeaponDefinition.Mode.MACHINE else &"pulse"
	# One sound per simultaneous volley; subsequent machine rounds keep rhythm.
	var key := "%s/%s/%s/%s" % [_epoch,ability.packet_id,Engine.get_physics_frames(),cue]
	# Lv1 bomb registers the same accepted-shot identity as a projectile, but its
	# existing blast callback owns its sound/flash; never add a pulse-gun sound.
	if mode != WeaponDefinition.Mode.BOMB:
		if not enabled_candidate: legacy._shot(axis,serial)
		else: _sound(cue,key)
	for projectile: PlayerProjectile in ability._projectiles:
		if not is_instance_valid(projectile) or projectile.shot_id!=serial: continue
		projectile.impacted.connect(_contact.bind(projectile,mode))
		var leaf := PlayerWeaponFeelProjectile.new()
		leaf.projectile=projectile
		leaf.previous=projectile.presentation
		leaf.previous_visible=leaf.previous.visible if is_instance_valid(leaf.previous) else true
		leaf.mode=mode
		leaf.trail_opacity=profile.trail_opacity
		projectile.add_child(leaf)
		leaves.append(leaf)
		leaf.set_active(enabled_candidate)
	events.append({"type":"shot","tick":Engine.get_physics_frames(),"serial":serial,"packet":ability.packet_id,"mode":mode})
	if events.size()>256: events.pop_front()

func _legacy_contact(point: Vector2, axis: Vector2) -> void:
	if not enabled_candidate: legacy._impact(point,axis)

func _contact(point: Vector2, axis: Vector2, projectile: PlayerProjectile, mode: int) -> void:
	if not enabled_candidate: return
	# This is a physical contact, including walls, not proof of committed damage.
	var key := "contact/%s/%s/%s" % [projectile.weapon_epoch,projectile.energy_receipt_id,Engine.get_physics_frames()]
	_sound(&"contact",key,16)
	_effect(&"contact",point,-axis,profile.contact_seconds,9 if mode==WeaponDefinition.Mode.MACHINE else 13)
	events.append({"type":"contact","tick":Engine.get_physics_frames(),"serial":projectile.shot_id,"point":[point.x,point.y]})
	if events.size()>256: events.pop_front()

func _phase(value: StringName) -> void:
	_sync_identity()
	audio.stop_weapon(_owner,true)
	if enabled_candidate and value in [&"beam",&"singularity",&"charge"]:
		_sound(&"beam","phase/%s/%s/%s" % [controller.shoot_ability.weapon_epoch,controller.shoot_ability.packet_id,value],profile.sustained_attenuation,true)
	var released_beam := false
	for fx: Dictionary in runtime._fx:
		if fx.kind=="beam" and bool(fx.skill) and float(fx.age)<=.001: released_beam=true
	if enabled_candidate and value==&"idle" and _previous_phase==&"charge" and controller.shoot_ability.weapon.mode==WeaponDefinition.Mode.LASER and released_beam:
		_sound(&"pulse","cannon/%s/%s" % [controller.shoot_ability.weapon_epoch,controller.shoot_ability.packet_id],10)
	_previous_phase=value

func _blast(point: Vector2) -> void:
	_sync_identity()
	var ability := controller.shoot_ability
	_sound(&"blast","blast/%s/%s/%s" % [ability.weapon_epoch,ability.packet_id,Engine.get_physics_frames()],11)
	_effect(&"blast",point,Vector2.UP,.22,ability.weapon.blast_radius*(ability.weapon.skill_multiplier if runtime._skill else 1))

func _entity_transition(entity: WeaponEntity, value: StringName) -> void:
	_sync_identity()
	if value in [&"attached",&"caught"]:
		_sound(&"contact","entity/%s/%s/%s" % [controller.shoot_ability.weapon_epoch,entity.serial,value],20)
		_effect(&"contact",entity.global_position,entity.direction,.12,9)

func _sync_identity() -> void:
	var ability := controller.shoot_ability
	if _epoch!=ability.weapon_epoch or _session!=controller.session_id:
		_epoch=ability.weapon_epoch
		_session=controller.session_id
		clear()
		_seen_entities.clear()

func _physics_process(_delta: float) -> void:
	_sync_identity()
	if not controller.active: return
	# Read the arrays without invoking gameplay getters that compact them.
	var live_ids: Dictionary = {}
	for entity: WeaponEntity in runtime.entities:
		if is_instance_valid(entity) and not entity.spent: live_ids[entity.get_instance_id()]=true
	for id: int in _seen_entities.keys():
		if not live_ids.has(id): _seen_entities.erase(id)
	for entity: WeaponEntity in runtime.entities:
		if not is_instance_valid(entity) or entity.spent or _seen_entities.has(entity.get_instance_id()): continue
		_seen_entities[entity.get_instance_id()]=true
		if entity.kind==&"boomerang" or entity.kind==&"mine":
			_sound(&"blade","entity_launch/%s/%s/%s" % [_epoch,entity.packet,Engine.get_physics_frames()],16)
	for i: int in range(leaves.size()-1,-1,-1):
		if not is_instance_valid(leaves[i]): leaves.remove_at(i)

func _process(delta: float) -> void:
	for i: int in range(effects.size()-1,-1,-1):
		effects[i].age+=delta
		if effects[i].age>=effects[i].life: effects.remove_at(i)
	if enabled_candidate: queue_redraw()

func _draw() -> void:
	if not enabled_candidate or not is_instance_valid(controller) or not is_instance_valid(runtime) or not controller.active: return
	var alpha := profile.accent_opacity
	for fx: Dictionary in effects:
		var progress := float(fx.age)/float(fx.life)
		var color := Color("ffe8ac")
		color.a=(1-progress)*alpha
		var center := to_local(fx.point)
		if fx.kind==&"contact":
			for i: int in 3:
				var axis: Vector2=fx.axis.rotated((i-1)*.6)
				var start := (center+axis*(2+progress*float(fx.radius))).snapped(Vector2(2,2))
				draw_line(start,start+axis*4*(1-progress),color,2,false)
		else:
			# Only a thin broken front; original gameplay-owned blast remains.
			for i: int in 8:
				var angle := i*TAU/8
				draw_arc(center,float(fx.radius)*(.2+.6*progress),angle,angle+.22,3,color,2,false)
	var beam := runtime.beam_visual_segment()
	if beam.size()==2:
		var start := to_local(beam[0])
		var end := to_local(beam[1])
		draw_line(start,end,Color(1,.97,.83,alpha*.8),runtime.beam_item_width_scale(),false)
		if runtime._beam_start.distance_to(runtime._beam_point)<controller.shoot_ability.weapon.range_limit-.5:
			for i: int in 3:
				var unit := Vector2.from_angle(runtime.age*18+i*TAU/3)
				draw_line(end+unit*3,end+unit*7,Color(1,.91,.64,alpha*.7),1,false)
	for entity: WeaponEntity in runtime.entities:
		if not is_instance_valid(entity) or entity.spent: continue
		if entity.kind==&"mine" and entity.phase==&"attached":
			var center := to_local(entity.global_position)
			for i: int in 4:
				var unit := Vector2.from_angle(i*TAU/4)
				draw_line(center+unit*13,center+unit*(15+sin(entity.age*8)),Color(.95,.85,.61,alpha*.7),2,false)

func _exit_tree() -> void:
	clear()
	for leaf: PlayerWeaponFeelProjectile in leaves:
		if is_instance_valid(leaf): leaf.set_active(false)
	if is_instance_valid(legacy) and is_instance_valid(controller):
		if not controller.shoot_ability.shot_fired.is_connected(legacy._shot): controller.shoot_ability.shot_fired.connect(legacy._shot)
		if not controller.shoot_ability.projectile_impacted.is_connected(legacy._impact): controller.shoot_ability.projectile_impacted.connect(legacy._impact)
