class_name ThornQueenCanopyEncounter
extends ThornForestEncounter
## Body flanking, then persistent keep/cut routes, then one visibly locked receiving shore.
signal weave_event(event: Dictionary)
var geometry: Dictionary={}
var motion_mode := "intro"
var motion_clock := 0.0
var motion_section := 0
var motion_leg := 0
var motion_cycles := 0
var last_receiver_id := "S"
var locked_receiver_id := ""
var sampled_player := Vector2.ZERO
var knots: Array[ThornQueenWeaveKnot]=[]
var bands: Array[ThornQueenWeaveBand]=[]
var last_restore_accepted := false
var _bound := false
var _life: DemoLifetime
var _policy: FrameDamagePolicy
var _controller: PlayerController
var _collision_player: PlayerMotor
var _restored := false
var _restoring_fields := false
func config() -> ThornQueenCanopyDefinition: return definition as ThornQueenCanopyDefinition
func _ready() -> void:
	super._ready()
	motor.collision_mask=1
	core_open=true
	knots.resize(2);bands.resize(2)
	_sync_mobile_anchor()
func mobile_anchor_enabled() -> bool:
	return _bound and active and not health.terminal and motion_mode!="intro" and combat_target_active() and _life!=null and _life.active
func _sync_mobile_anchor() -> void:
	if not is_instance_valid(motor): return
	var enabled := mobile_anchor_enabled()
	if enabled and not motor.is_in_group(&"grapple_target"): motor.add_to_group(&"grapple_target")
	elif not enabled and motor.is_in_group(&"grapple_target"): motor.remove_from_group(&"grapple_target")
func bind_duel(data: Dictionary,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime) -> bool:
	if config()==null or controller==null or policy==null or lifetime==null: return false
	if _bound:
		if geometry!=data or _policy!=policy or _life!=lifetime: return false
	else:
		if typeof(data.get("version"))!=TYPE_STRING or data.version!=ThornQueenCanopyDefinition.VERSION or not _point_ok(data.get("origin")): return false
		if typeof(data.get("ok"))!=TYPE_BOOL or not data.ok or not data.get("entrance_connector") is Dictionary: return false
		var expected := config().build_geometry(_point(data.origin),not data.entrance_connector.is_empty())
		for key: String in ["version","boss_contract","origin","boss_arena","platforms","hook_anchors","boss_position","safe_return","reward_position","motion_paths","receiver_fields","high_field"]:
			if not RandomStageGenerator.new()._same_data(data.get(key),expected.get(key)): return false
		geometry=data.duplicate(true);_policy=policy;_life=lifetime;_bound=true
	if is_instance_valid(_collision_player) and _collision_player!=controller.motor: motor.remove_collision_exception_with(_collision_player)
	_collision_player=controller.motor
	motor.add_collision_exception_with(_collision_player)
	_controller=controller
	for field: ThornQueenWeaveBand in bands:
		if is_instance_valid(field):
			field.controller=controller
			if active: field.resume_restored()
	return true
func activate() -> bool:
	if not _bound or not super.activate(): return false
	core_open=true
	if not _restored:
		motion_mode="intro";mode=&"intro";motion_clock=intro_duration
	else:
		mode=StringName(motion_mode);_restored=false
	for field: ThornQueenWeaveBand in bands:
		if is_instance_valid(field): field.resume_restored()
	_sync_mobile_anchor()
	return true
func motion_path() -> Array[Vector2]:
	var result: Array[Vector2]=[]
	for point: Array in geometry.motion_paths[motion_section]: result.append(_point(point))
	return result
func _preview() -> void:
	motion_mode="migration_preview";mode=&"migration_preview";motion_leg=0;motion_clock=config().canopy_preview
	weave_event.emit({"event":"canopy_body_preview","section":motion_section,"cycle":motion_cycles,"phase":stage_phase,"path":geometry.motion_paths[motion_section],"seconds":motion_clock,"locked":true})
func _receiver_row(id: String) -> Dictionary:
	for row: Dictionary in geometry.receiver_fields:
		if row.id==id: return row
	return {}
func _observe_receiver() -> void:
	if not _controller.motor.is_on_floor(): return
	var half := Vector2(12,18)
	var at := _controller.motor.global_position
	for row: Dictionary in geometry.receiver_fields:
		var rect := _rect(row.support)
		if absf(at.y+half.y-rect.position.y)<1 and at.x-half.x>=rect.position.x and at.x+half.x<=rect.end.x:
			last_receiver_id=str(row.id)
func _spawn_field(index: int) -> bool:
	if is_instance_valid(knots[index]): return true
	var row: Dictionary=geometry.high_field if index==0 else _receiver_row(locked_receiver_id)
	if row.is_empty(): return false
	var knot := ThornQueenWeaveKnot.new();knot.name="CanopyHighKnot" if index==0 else "CanopyReceiverKnot"
	motor.get_parent().add_child(knot);knot.global_position=_point(row.knot_position)
	if not knot.configure(config(),_policy,StringName("queen/canopy/%s"%index)): knot.queue_free();return false
	var field := ThornQueenWeaveBand.new();field.field_id="canopy_high" if index==0 else "canopy_receiver"
	motor.get_parent().add_child(field)
	field.configure(config(),_point(row.strand_start),_point(row.strand_tip),_controller,_policy,_life)
	knot.bare_stem_tip=_point(row.strand_start)-knot.global_position
	knot.severed.connect(field.cut)
	field.weave_event.connect(func(data: Dictionary) -> void:
		var event := data.duplicate(true);event["field"]=index;event["phase"]=stage_phase;weave_event.emit(event))
	knots[index]=knot;bands[index]=field
	if not _restoring_fields and not field.begin(): return false
	if _restoring_fields: return true
	weave_event.emit({"event":"canopy_field_preview","field":index,"receiver":locked_receiver_id if index==1 else "high","sampled_player":[sampled_player.x,sampled_player.y],"basis":"last_actual_full_foot_support" if index==1 else "authored_high_route","row":row.duplicate(true),"warning":config().preview_seconds,"grow":config().grow_seconds})
	return true
func _start_phase(next: int) -> void:
	stage_phase=next;phases.phase=next
	if next==3:
		locked_receiver_id=last_receiver_id
		sampled_player=_controller.motor.global_position
	if not _spawn_field(next-2): push_error("Canopy field failed to bind actual policy")
	phase_changed.emit(next)
	weave_event.emit({"event":"canopy_phase_started","phase":next,"boss_hp":health.current,"body_flight_unchanged":true})
func physics_tick(delta: float) -> void:
	_sync_mobile_anchor()
	if not _bound or not active or health.terminal or not is_finite(delta) or delta<=0: return
	if not combat_target_active() or not _life.active: motor.stop();return
	core_open=true
	_observe_receiver()
	var wanted := 3 if health.current<=health.capacity*config().phase_three_health else (2 if health.current<=health.capacity*config().phase_two_threshold else 1)
	while stage_phase<wanted: _start_phase(stage_phase+1)
	# Menus/actor transitions pause the existing field rather than resetting or erasing it.
	for field: ThornQueenWeaveBand in bands:
		if is_instance_valid(field) and not field.severed and not field.is_physics_processing(): field.resume_restored()
	if motion_mode=="intro":
		motion_clock=maxf(0,motion_clock-delta);motor.stop()
		if motion_clock==0: _preview()
	elif motion_mode=="migration_preview":
		motion_clock=maxf(0,motion_clock-delta);motor.stop()
		if motion_clock==0: motion_mode="flight";mode=&"flight"
	else:
		var path := motion_path()
		if (motor as ThornQueenWeaveMotor).travel_to(path[motion_leg+1],config().canopy_speed,delta):
			if motion_leg<path.size()-2: motion_leg+=1
			else:
				weave_event.emit({"event":"canopy_body_arrived","section":motion_section,"cycle":motion_cycles,"position":[motor.position.x,motor.position.y]})
				motion_section=(motion_section+1)%geometry.motion_paths.size()
				if motion_section==0: motion_cycles+=1
				_preview()
	_sync_mobile_anchor()
func accepts_core_direction(context: Dictionary) -> bool:
	return active and not health.terminal and typeof(context.get("amount")) in [TYPE_INT,TYPE_FLOAT] and float(context.amount)>0
func body_contact_enabled() -> bool:
	return active and not health.terminal and combat_target_active() and motion_mode!="intro"
func objective() -> String:
	if motion_mode=="intro": return config().display_name
	if stage_phase==1: return "看巡路，越身换侧 / FLANK THE SWEEP"
	if stage_phase==2: return "保高结，或剪开侧路 / KEEP OR CUT THE HIGH KNOT"
	return "旧岸已锁：换岸或剪网 / OLD SHORE LOCKED: MOVE OR CUT"
func cancel_pending_attacks() -> void:
	attack_epoch+=1
	for field: ThornQueenWeaveBand in bands:
		if is_instance_valid(field): field.pause_battle()
func cancel() -> void:
	cancel_pending_attacks()
	super.cancel()
	_sync_mobile_anchor()
func reward_stand_position() -> Vector2:
	return _point(geometry.reward_position) if _bound else Vector2.ZERO
func combat_snapshot() -> Dictionary:
	var fields: Array[Dictionary]=[]
	for index: int in 2:
		fields.append({"spawned":true,"health":knots[index].health.current,"weave":bands[index].snapshot()} if is_instance_valid(knots[index]) else {"spawned":false})
	return {"canopy_schema":1,"geometry_version":str(geometry.get("version","")),"body_position":[motor.position.x,motor.position.y],"mode":motion_mode,"motion_clock":motion_clock,"stage_phase":stage_phase,"section":motion_section,"leg":motion_leg,"cycles":motion_cycles,"last_receiver":last_receiver_id,"locked_receiver":locked_receiver_id,"sampled_player":[sampled_player.x,sampled_player.y],"intro_seen":intro_seen,"intro_duration":intro_duration,"fields":fields,"attack_epoch":attack_epoch}
func serialize_combat_state() -> Dictionary: return combat_snapshot()
func valid_duel_snapshot(data: Dictionary) -> bool:
	if not _bound or not _integer(data.get("canopy_schema")) or int(data.canopy_schema)!=1: return false
	for key: String in ["geometry_version","mode","last_receiver","locked_receiver"]:
		if typeof(data.get(key))!=TYPE_STRING: return false
	if data.geometry_version!=ThornQueenCanopyDefinition.VERSION or not _point_ok(data.get("body_position")) or not _point_ok(data.get("sampled_player")): return false
	if data.has("position") and not RandomStageGenerator.new()._same_data(data.body_position,data.position): return false
	if typeof(data.get("intro_seen"))!=TYPE_BOOL or not _number(data.get("intro_duration")) or float(data.intro_duration)<0 or float(data.intro_duration)>config().intro_seconds: return false
	for key: String in ["stage_phase","section","leg","cycles","attack_epoch"]:
		if not _integer(data.get(key)): return false
	if data.stage_phase<1 or data.stage_phase>3 or data.section>=geometry.motion_paths.size(): return false
	if data.last_receiver not in config().receiver_ids or (data.locked_receiver not in config().receiver_ids if data.stage_phase==3 else not data.locked_receiver.is_empty()): return false
	if data.mode not in ["intro","migration_preview","flight"] or not _number(data.get("motion_clock")) or float(data.motion_clock)<0: return false
	var path: Array=geometry.motion_paths[int(data.section)]
	var at := _point(data.body_position)
	if data.mode=="flight":
		if data.leg>=path.size()-1 or float(data.motion_clock)!=0 or Geometry2D.get_closest_point_to_segment(at,_point(path[int(data.leg)]),_point(path[int(data.leg)+1])).distance_to(at)>.001: return false
	else:
		if data.leg!=0 or at.distance_to(_point(path[0]))>.001 or (data.mode=="intro" and data.section!=0): return false
		if float(data.motion_clock)>(config().intro_seconds if data.mode=="intro" else config().canopy_preview)+.00001: return false
	if not data.get("fields") is Array or data.fields.size()!=2: return false
	for index: int in 2:
		var row: Variant=data.fields[index]
		if not row is Dictionary or typeof(row.get("spawned"))!=TYPE_BOOL: return false
		if bool(row.spawned)!=(int(data.stage_phase)>=index+2): return false
		if not row.spawned:
			if row.size()!=1 or is_instance_valid(knots[index]): return false
			continue
		if not _number(row.get("health")) or float(row.health)<0 or float(row.health)>config().knot_health_definition.max_health: return false
		if not row.get("weave") is Dictionary or not ThornQueenWeaveBand.valid_snapshot_for(row.weave,config()): return false
		if not _integer(row.weave.get("pulse")) or bool(row.weave.severed)!=(float(row.health)==0) or bool(row.weave.suspended) or float(row.weave.initial_angle)!=0: return false
	return true
func restore_combat_state(data: Dictionary) -> void:
	last_restore_accepted=false
	if not valid_duel_snapshot(data): return
	stage_phase=int(data.stage_phase);phases.phase=stage_phase
	last_receiver_id=str(data.last_receiver);locked_receiver_id=str(data.locked_receiver);sampled_player=_point(data.sampled_player)
	_restoring_fields=true
	for index: int in 2:
		if not data.fields[index].spawned: continue
		if not _spawn_field(index) or not knots[index].restore_health(float(data.fields[index].health)) or not bands[index].restore(data.fields[index].weave):
			_restoring_fields=false;return
	_restoring_fields=false
	motion_mode=str(data.mode);mode=StringName(motion_mode);motion_clock=float(data.motion_clock);motion_section=int(data.section);motion_leg=int(data.leg);motion_cycles=int(data.cycles)
	intro_seen=bool(data.intro_seen);intro_duration=float(data.intro_duration);attack_epoch=maxi(attack_epoch,int(data.attack_epoch))+1
	motor.global_position=_point(data.body_position);_restored=true;last_restore_accepted=true
	if active:
		for field: ThornQueenWeaveBand in bands:
			if is_instance_valid(field): field.resume_restored()
static func _number(value: Variant) -> bool: return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))
static func _integer(value: Variant) -> bool: return _number(value) and float(value)>=0 and float(value)<=1000000000 and float(value)==floorf(float(value))
static func _point_ok(value: Variant) -> bool: return value is Array and value.size()==2 and _number(value[0]) and _number(value[1])
static func _point(value: Array) -> Vector2: return Vector2(value[0],value[1])
static func _rect(value: Array) -> Rect2: return Rect2(value[0],value[1],value[2],value[3])
