class_name RuntimeMapShotLatchEncounter
extends Node2D
## A finite v2 data consumer of the existing ShotLatch. No new damage, input,
## reward, or save authority; the Stage supplies its existing player/lifetime.
const ADAPTER := preload("res://game/world/levels/content/runtime_map_shot_latch_adapter.gd")
var latches: Array[ShotLatch] = []
var state_keys: Array[String] = []
var error := ""
var _controller: WeakRef
var _lifetime: DemoLifetime
var _state: PlainsRegionState
var _installed := false
var _cancelled := false
var extras: RuntimeMapModuleExtras
var _runtime_modules: Array[Dictionary]=[]

static func validation_error(plan: LevelPlan, state: PlainsRegionState) -> String:
	if plan==null or state==null: return "Missing latch plan/state"
	for placement: LevelModulePlacement in plan.modules:
		if placement==null or placement.definition==null: return "Missing latch module definition"
		var instance: Variant = placement.definition.get_meta("runtime_map_v2_instance",{})
		var content: Variant = placement.definition.get_meta("runtime_map_v2_content",{})
		if not instance is Dictionary or not content is Dictionary: return "Invalid runtime-map latch metadata"
		# Modules without this source metadata have no v2 latch declaration.
		if instance.is_empty() and content.is_empty(): continue
		if instance.get("id")!=placement.instance_id: return "Latch source instance differs from placement"
		var problem := RuntimeMapContentAdapter.latch_error(content) if plan.get_meta("runtime_map_complete",false) else ADAPTER.validation_error(content,instance)
		if not problem.is_empty(): return placement.instance_id+"."+problem
		if plan.get_meta("runtime_map_complete",false) and state.mechanisms.has(placement.instance_id+"/runtime"):
			problem=RuntimeMapContentAdapter.runtime_state_error(content,state.mechanisms[placement.instance_id+"/runtime"])
			if not problem.is_empty():return problem
		for raw: Dictionary in RuntimeMapContentAdapter.mechanisms(content) if plan.get_meta("runtime_map_complete",false) else content.latches:
			var key := ADAPTER.state_key(placement.instance_id,str(raw.id))
			if state.mechanisms.has(key):
				problem = RuntimeMapContentAdapter.snapshot_error(state.mechanisms[key],raw) if plan.get_meta("runtime_map_complete",false) else ADAPTER.snapshot_error(state.mechanisms[key])
				if not problem.is_empty(): return key+"."+problem
			if state.opened.has(key) and state.opened[key]!=true: return key+": invalid permanent-open ledger value"
	return ""

static func has_latches(plan: LevelPlan) -> bool:
	for placement: LevelModulePlacement in plan.modules:
		var content: Dictionary = placement.definition.get_meta("runtime_map_v2_content",{})
		if not RuntimeMapContentAdapter.mechanisms(content).is_empty(): return true
	return false

func setup(plan: LevelPlan, assembler: PlainsRegionAssembler, controller: PlayerController, lifetime: DemoLifetime, state: PlainsRegionState) -> bool:
	if _installed or not is_inside_tree() or not is_instance_valid(assembler) or not is_instance_valid(controller) or controller.shoot_ability==null or lifetime==null or not lifetime.active:
		error = "Invalid or already installed latch context"
		return false
	error = validation_error(plan,state)
	if not error.is_empty(): return false
	if assembler.modules.size()!=plan.modules.size():
		error = "Latch assembler differs from admitted module count"
		return false
	_controller = weakref(controller)
	_lifetime = lifetime
	_state = state
	for index: int in plan.modules.size():
		var placement := plan.modules[index]
		var module := assembler.modules[index]
		if not is_instance_valid(module) or module.definition==null or module.definition.module_id!=placement.template_id or module.position!=placement.position:
			error = "Latch module differs from admitted placement"
			cancel()
			return false
		var content: Dictionary = placement.definition.get_meta("runtime_map_v2_content",{})
		var carriers: Dictionary={}
		for platform: ModuleMovingPlatform in module.moving_platforms:carriers[str(platform.definition.platform_id)]=platform
		var saved: Dictionary=state.mechanisms.get(placement.instance_id+"/runtime",{})
		var local_latches: Dictionary={}
		var relay_ids: Dictionary={}
		for special: Dictionary in content.get("approved_hq_cells",[]):
			if special.kind=="hit_turret":relay_ids[str(special.latch_id)]=true
		for raw: Dictionary in RuntimeMapContentAdapter.mechanisms(content):
			var key:=ADAPTER.state_key(placement.instance_id,str(raw.id))
			var kind:=str(raw.get("kind",""))
			var latch: ShotLatch
			if raw.has("paired_gate"):latch=RuntimeMapPairedLatch.new()
			elif kind in ["retractable_gears","retract_thorns"]:latch=RuntimeMapHazardLatch.new()
			elif raw.has("carrier_dock"):latch=RuntimeMapDockLatch.new()
			elif relay_ids.has(str(raw.id)):latch=RuntimeMapRelayLatch.new()
			else:latch=ShotLatch.new()
			latch.name="RuntimeMapShotLatch"+str(latches.size());latch.position=module.position;latch.link_id=str(raw.id);latch.formal_presentation=true
			latch.prompt_text=str(raw.get("prompt","SHOOT BELL"));latch.open_seconds=float(raw.open_seconds);latch.link_color=Color(str(raw.get("link_color","e8bd65")))
			if raw.has("sequence_offset"):latch.sequence_offset=ADAPTER.point(raw.sequence_offset)
			add_child(latch)
			if latch is RuntimeMapPairedLatch:
				latch.reward_only=kind=="reward_pair"
				latch.setup_pair(controller,lifetime,ADAPTER.point(raw.bell),ADAPTER.rectangle(raw.gate),ADAPTER.rectangle(raw.paired_gate),str(raw.initial_open))
			elif latch is RuntimeMapHazardLatch:
				var stage:=assembler.get_parent() as GeneratedDemoStage
				latch.setup_hazards(controller,lifetime,stage.bound_policy,raw,placement.instance_id+"/hazards/",kind=="retractable_gears")
			else:latch.setup(controller,lifetime,ADAPTER.point(raw.bell),ADAPTER.rectangle(raw.gate))
			if raw.has("ferry_id") or kind=="group_motion":
				var targets: Array[ModuleMovingPlatform]=[]
				var ids: Array=raw.targets if kind=="group_motion" else [raw.ferry_id]
				for id: Variant in ids:targets.append(carriers[str(id)])
				for platform: ModuleMovingPlatform in targets:platform.bind_bell_control()
				latch.bind_motion(targets[0])
				latch.opened.connect(func() -> void:
					for platform: ModuleMovingPlatform in targets:platform.set_motion_running(latch.is_open))
			if latch is RuntimeMapDockLatch:latch.configure_dock(carriers[str(raw.carrier_dock.platform_id)],ADAPTER.rectangle(raw.carrier_dock.rect))
			if raw.has("return_access"):
				var instance: Dictionary=placement.definition.get_meta("runtime_map_v2_instance")
				_add_access(latch,ADAPTER.point(raw.return_access),str(raw.get("return_access_side_policy","left" if instance.transform.mirror_x else "right")))
			if raw.has("additional_pair_access"):_add_access(latch,ADAPTER.point(raw.additional_pair_access),"any")
			if raw.has("access"):
				var access: Array=raw.access
				if access.size()==2 and access[0] is float or access.size()==2 and access[0] is int:_add_access(latch,ADAPTER.point(access),"any")
				else:
					for at: Array in access:_add_access(latch,ADAPTER.point(at),"any")
			latch.set_region_presentation(true)
			if state.mechanisms.has(key):latch.restore_region_state(state.mechanisms[key])
			latch.restore_region_opened(state.opened.has(key))
			if raw.has("carrier_mount"):latch.reparent(carriers[str(raw.carrier_mount)],true)
			latch.set_meta("runtime_map_instance_id",placement.instance_id);latch.set_meta("runtime_map_latch_id",str(raw.id));latch.set_meta("runtime_map_state_key",key)
			latch.opened.connect(_opened.bind(latch,key));latches.append(latch);state_keys.append(key);local_latches[str(raw.id)]=latch
		for special: Dictionary in content.get("approved_hq_cells",[]):
			if special.kind=="rigid_mounted_bell":
				var latch: ShotLatch=local_latches[str(special.id)]
				var carrier: ModuleMovingPlatform=carriers[str(special.mount)]
				if latch.get_parent()!=carrier:latch.reparent(carrier,true)
				latch.position=ADAPTER.point(special.offset)-latch.bell_body.position
			if special.kind=="native_one_way_carriers":
				for id: Variant in special.ids:
					var carrier: ModuleMovingPlatform=carriers[str(id)];carrier.add_to_group("one_way_platform")
					for shape: Node in carrier.get_children():
						if shape is CollisionShape2D:shape.one_way_collision=true
			if special.kind=="projectile_barrier":
				var carrier: ModuleMovingPlatform=carriers[str(special.id)];carrier.collision_layer=8;carrier.set_meta("projectile_barrier",true);carrier.queue_redraw()
		for id: Variant in saved.get("platforms",{}):
			var phase: Dictionary=saved.platforms[id]
			if not carriers.has(str(id)) or not phase.get("clock") is float and not phase.get("clock") is int or not phase.get("running") is bool or not phase.get("controlled") is bool:
				error="invalid saved carrier state";cancel();return false
			var carrier: ModuleMovingPlatform=carriers[str(id)];carrier.bell_controlled=phase.controlled;carrier.restore_motion(float(phase.clock),phase.running)
		if plan.get_meta("runtime_map_complete",false):_runtime_modules.append({"instance_id":placement.instance_id,"module":module,"content":content,"carriers":carriers,"latches":local_latches})
	if plan.get_meta("runtime_map_complete",false):
		extras=RuntimeMapModuleExtras.new();add_child(extras)
		if not extras.setup(_runtime_modules,assembler.get_parent() as PlainsRegionStage,controller,lifetime,state):error=extras.error;cancel();return false
	_installed = true
	return true

func matches_binding(controller: PlayerController, lifetime: DemoLifetime) -> bool:
	return _installed and not _cancelled and _controller!=null and _controller.get_ref()==controller and _lifetime==lifetime and lifetime!=null and lifetime.active

func _opened(latch: ShotLatch, key: String) -> void:
	if _cancelled or _lifetime==null or not _lifetime.active or not is_instance_valid(latch) or not latch.is_open: return
	_state.mechanisms[key] = latch.region_snapshot()
	if latch.open_seconds==0 and not latch.motion_mode and not latch.repeatable: _state.opened[key] = true

func _add_access(latch: ShotLatch,at: Vector2,side: String) -> void:
	latch.add_access_bell(at,false,false)
	if side=="any":return
	var receiver:=latch.access_bodies[-1].get_node("Damageable") as Damageable
	receiver.damage_sink=func(hit:Dictionary) -> bool:
		var shot: Dictionary=latch._eligible_shots.get("%s:%s" % [hit.get("session_id",-1),hit.get("shot_id",-1)],{})
		if not shot.has("actor_position"):return false
		var x: float=latch.to_local(shot.actor_position).x
		if side=="right" and x<latch.gate_rect.end.x+12 or side=="left" and x>latch.gate_rect.position.x-12:return false
		return latch._receive_projectile(hit)

func capture_state() -> void:
	if _state==null: return
	for row: Dictionary in _runtime_modules:
		var platforms: Dictionary={}
		for id: Variant in row.carriers:
			var carrier: ModuleMovingPlatform=row.carriers[id]
			if is_instance_valid(carrier):platforms[str(id)]={"clock":carrier.motion_clock,"running":carrier.motion_running,"controlled":carrier.bell_controlled}
		var key: String=str(row.instance_id)+"/runtime"
		var saved: Dictionary=_state.mechanisms.get(key,{})
		saved["platforms"]=platforms;_state.mechanisms[key]=saved
	if is_instance_valid(extras):extras.capture_state()
	for index: int in latches.size():
		var latch := latches[index]
		if not is_instance_valid(latch): continue
		_state.mechanisms[state_keys[index]] = latch.region_snapshot()
		if latch.is_open and latch.open_seconds==0 and not latch.motion_mode and not latch.repeatable: _state.opened[state_keys[index]] = true

func observations() -> Array[Dictionary]:
	# Read-only diagnostics of the original actual colliders and latch state.
	# These values never participate in simulation, identity, or admission.
	var result: Array[Dictionary] = []
	for index: int in latches.size():
		var latch := latches[index]
		if not is_instance_valid(latch) or not is_instance_valid(latch.bell_body) or not is_instance_valid(latch.gate_body): continue
		var bell := latch.bell_body.global_position
		var gate := Rect2(latch.to_global(latch.gate_rect.position),latch.gate_rect.size)
		result.append({"instance_id":str(latch.get_meta("runtime_map_instance_id","")),"latch_id":str(latch.get_meta("runtime_map_latch_id","")),"state_key":state_keys[index],"bell_world":[bell.x,bell.y],"gate_world":[gate.position.x,gate.position.y,gate.size.x,gate.size.y],"is_open":latch.is_open,"open_count":latch.open_count,"gate_disabled":latch.gate_shape.disabled,"snapshot":latch.region_snapshot()})
	return result

func cancel_pending() -> void:
	if is_instance_valid(extras):extras.cancel_pending()
	for latch: ShotLatch in latches:
		if is_instance_valid(latch): latch.cancel_pending()

func cancel() -> void:
	_cancelled = true
	if is_instance_valid(extras):extras.cancel()
	for latch: ShotLatch in latches:
		if is_instance_valid(latch): latch.cancel()

func _exit_tree() -> void:
	capture_state()
	cancel()
