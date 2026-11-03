class_name RuntimeMapSliceStage
extends Node2D
## Source-specific controlled Stage; no legacy Manifest or ordinary departure.
var plan: LevelPlan
var state: PlainsRegionState
var assembler: PlainsRegionAssembler
var assembly_ok := false
var error := ""
var _damage_controller: WeakRef
var _damage_policy: WeakRef
var _damage_lifetime: DemoLifetime
var _static_contacts: Array[DemoContactEmitter] = []

func _ready() -> void:
	set_meta("underworld_formal_style",true)
	set_meta("pixel_formal_style",true)
	if plan == null or state == null or not state.bind_map(plan.map_hash):
		error = "Missing plan/state or map identity changed"
		return
	for placement: LevelModulePlacement in plan.modules:
		var clock: Variant = state.clocks.get(placement.instance_id,0.0)
		if not (clock is int or clock is float) or not is_finite(float(clock)) or float(clock)<0:
			error = "Invalid saved module clock: "+placement.instance_id
			return
	var result := LevelRuntime.assemble(self,plan,state)
	assembly_ok = result.ok
	assembler = result.assembler as PlainsRegionAssembler
	error = str(result.get("error",""))

func bind_damage(controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime) -> void:
	if not assembly_ok or not is_instance_valid(controller) or not is_instance_valid(policy) or lifetime == null: return
	if _damage_controller != null and _damage_policy != null and _damage_controller.get_ref()==controller and _damage_policy.get_ref()==policy and _damage_lifetime==lifetime:
		return
	for previous: DemoContactEmitter in _static_contacts:
		if is_instance_valid(previous):
			previous.enabled = false
			remove_child(previous)
			previous.queue_free()
	_static_contacts.clear()
	_damage_controller = weakref(controller)
	_damage_policy = weakref(policy)
	_damage_lifetime = lifetime
	# Existing saws keep their original shared module clock and damage owner.
	assembler.setup_damage(controller,policy,lifetime)
	var records := assembler.world_static_hazard_records()
	for index: int in records.size():
		var record: Dictionary = records[index]
		var rect: Rect2 = record.rect
		var emitter := DemoContactEmitter.attach(self,policy,controller,StringName("runtime_map_static_%d" % index),DamageRequest.Kind.ENVIRONMENT,rect.size/2.0)
		emitter.position = to_local(rect.get_center())
		emitter.fall_plane = record.role=="fall_plane"
		emitter.set_meta("hazard_role",record.role)
		emitter.set_meta("hazard_module",record.module_id)
		emitter.set_meta("hazard_authored_id",record.authored_id)
		_static_contacts.append(emitter)

func capture_state() -> Dictionary:
	if assembly_ok:
		for index: int in plan.modules.size():
			state.clocks[plan.modules[index].instance_id] = assembler.modules[index].clock
	return state.snapshot() if state != null else {}

func observe_player(point: Vector2) -> void:
	if not assembly_ok: return
	var index := assembler.module_index_at(point)
	if index >= 0: state.visited[plan.modules[index].instance_id] = true
