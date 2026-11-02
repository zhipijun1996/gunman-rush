class_name RuntimeMapSliceStage
extends Node2D
## Source-specific controlled Stage; no legacy Manifest or ordinary departure.
var plan: LevelPlan
var state: PlainsRegionState
var assembler: PlainsRegionAssembler
var assembly_ok := false
var error := ""

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
	if assembly_ok: assembler.setup_damage(controller,policy,lifetime)

func capture_state() -> Dictionary:
	if assembly_ok:
		for index: int in plan.modules.size():
			state.clocks[plan.modules[index].instance_id] = assembler.modules[index].clock
	return state.snapshot() if state != null else {}

func observe_player(point: Vector2) -> void:
	if not assembly_ok: return
	var index := assembler.module_index_at(point)
	if index >= 0: state.visited[plan.modules[index].instance_id] = true
