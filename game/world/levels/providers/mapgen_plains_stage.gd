class_name MapgenPlainsStage
extends PlainsRegionStage
## Formal presentation, encounters, fog and rewards stay in PlainsRegionStage.
var runtime_latches: RuntimeMapShotLatchEncounter

func _ready() -> void:
	super._ready()
	if restored_boss.get("seal_closed",false) and float(restored_boss.get("health",0))>0:
		spawn=boss_entry_position()

func boss_entry_position() -> Vector2:
	var point := super.boss_entry_position()
	for placement: LevelModulePlacement in level_plan.modules:
		var instance: Dictionary=placement.definition.get_meta("runtime_map_v2_instance",{})
		if instance.get("role")!="boss": continue
		for port: Dictionary in instance.ports:
			if port.id in instance.connected_port_ids and port.face=="RIGHT":
				return Vector2(boss_arena.end.x-(point.x-boss_arena.position.x),point.y)
	return point

func setup_shot_latches(controller: PlayerController, lifetime: DemoLifetime) -> bool:
	runtime_latches=RuntimeMapShotLatchEncounter.new()
	add_child(runtime_latches)
	if not runtime_latches.setup(level_plan,assembler as PlainsRegionAssembler,controller,lifetime,region_state):
		push_error(runtime_latches.error)
		return false
	shot_latches=runtime_latches.latches
	return true

func cancel_shot_latch_requests(permanent: bool = false) -> void:
	if not is_instance_valid(runtime_latches): return
	if permanent: runtime_latches.cancel()
	else: runtime_latches.cancel_pending()

func _capture_tick_state() -> void:
	if assembly_ok:_update_navigation()

func _process(_delta: float) -> void:
	# The live world remains authoritative at 60Hz. Capture its completed
	# physics steps once per displayed frame; explicit save/unload still calls
	# capture_state() synchronously and never relies on this sampling cadence.
	if assembly_ok:_capture_live_ledger()

func _capture_latch_state() -> void:
	if is_instance_valid(runtime_latches):runtime_latches.capture_state()
