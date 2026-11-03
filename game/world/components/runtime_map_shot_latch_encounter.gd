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
		var problem := ADAPTER.validation_error(content,instance)
		if not problem.is_empty(): return placement.instance_id+"."+problem
		for raw: Dictionary in content.latches:
			var key := ADAPTER.state_key(placement.instance_id,str(raw.id))
			if state.mechanisms.has(key):
				problem = ADAPTER.snapshot_error(state.mechanisms[key])
				if not problem.is_empty(): return key+"."+problem
			if state.opened.has(key) and state.opened[key]!=true: return key+": invalid permanent-open ledger value"
	return ""

static func has_latches(plan: LevelPlan) -> bool:
	for placement: LevelModulePlacement in plan.modules:
		var content: Dictionary = placement.definition.get_meta("runtime_map_v2_content",{})
		if content.get("latches") is Array and not content.latches.is_empty(): return true
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
		for raw: Dictionary in content.get("latches",[]):
			var key := ADAPTER.state_key(placement.instance_id,str(raw.id))
			var latch := ShotLatch.new()
			latch.name = "RuntimeMapShotLatch"+str(latches.size())
			# SDK content is already local to the owned rectangle. Apply only the
			# same placement translation as its PlatformingModule, exactly once.
			latch.position = module.position
			latch.link_id = str(raw.id)
			latch.formal_presentation = true
			latch.prompt_text = raw.prompt
			latch.open_seconds = float(raw.open_seconds)
			latch.link_color = Color(raw.link_color)
			add_child(latch)
			latch.setup(controller,lifetime,ADAPTER.point(raw.bell),ADAPTER.rectangle(raw.gate))
			latch.set_region_presentation(true)
			if state.mechanisms.has(key): latch.restore_region_state(state.mechanisms[key])
			# restore_region_state assigns is_open, while this original helper
			# actually disables the restored permanent gate collision.
			latch.restore_region_opened(state.opened.has(key))
			latch.set_meta("runtime_map_instance_id",placement.instance_id)
			latch.set_meta("runtime_map_latch_id",str(raw.id))
			latch.set_meta("runtime_map_state_key",key)
			latch.opened.connect(_opened.bind(latch,key))
			latches.append(latch)
			state_keys.append(key)
	_installed = true
	return true

func matches_binding(controller: PlayerController, lifetime: DemoLifetime) -> bool:
	return _installed and not _cancelled and _controller!=null and _controller.get_ref()==controller and _lifetime==lifetime and lifetime!=null and lifetime.active

func _opened(latch: ShotLatch, key: String) -> void:
	if _cancelled or _lifetime==null or not _lifetime.active or not is_instance_valid(latch) or not latch.is_open: return
	_state.mechanisms[key] = latch.region_snapshot()
	_state.opened[key] = true

func capture_state() -> void:
	if _state==null: return
	for index: int in latches.size():
		var latch := latches[index]
		if not is_instance_valid(latch): continue
		_state.mechanisms[state_keys[index]] = latch.region_snapshot()
		if latch.is_open: _state.opened[state_keys[index]] = true

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
	for latch: ShotLatch in latches:
		if is_instance_valid(latch): latch.cancel_pending()

func cancel() -> void:
	_cancelled = true
	for latch: ShotLatch in latches:
		if is_instance_valid(latch): latch.cancel()

func _exit_tree() -> void:
	capture_state()
	cancel()
