class_name RuntimeMapWindchimeSlice
extends RuntimeMapGeneratedSlice
## Complete generated start module. Its external neighbor is deliberately not
## loaded or certified; this entrance stops at the actual owned exit bank.
const BINDINGS_PATH := "res://resources/levels/mapgen_host_041_windchime/bindings.json"
const BINDINGS_SHA256 := "d777af4b7365758c071d4bafcc019fc391f58aae015f268f6b2d9ff24e835176"
var exit_bank_world := Vector2.ZERO
var exit_port_id := ""

func _read_host_bindings() -> Dictionary:
	return RuntimeMapFrozenSource.read_binding_file(BINDINGS_PATH,BINDINGS_SHA256)

func _slice_description() -> String:
	return "complete start windchime / "+str(profile_inputs.get("seed",""))+" / shoot the bell, reach the exit bank; neighbor not loaded"

func _physics_admission() -> String:
	if not is_instance_valid(stage) or not stage.assembly_ok or stage.plan.modules.size()!=1:
		return "Start windchime admission requires one complete actual module"
	var resolved := generation.resolved_bindings(ticket,session.lifetime)
	if not resolved.get("selection_resolution") is Dictionary or resolved.selection_resolution.instances.size()!=1:
		return "Start windchime selection resolution is missing"
	var actual: Dictionary = resolved.selection_resolution.instances[0]
	var placement := stage.plan.modules[0]
	if actual.instance_id!=placement.instance_id or actual.module_id!="game-plains-windchime-lesson" or actual.content_version!=RuntimeMapShotLatchAdapter.CONTENT_VERSION or actual.role!="start":
		return "Start module/template/version/role differs from actual output"
	if not is_instance_valid(stage.shot_latch_encounter) or stage.shot_latch_encounter.latches.size()!=1:
		return "Complete start windchime must bind its original safe_lesson"
	var admitted: Dictionary = placement.definition.get_meta("runtime_map_v2_port_admission",{})
	if not admitted.get("used_ports") is Array or not resolved.get("exit_rule") is Dictionary:
		return "Actual used exit bank admission is missing"
	exit_port_id = str(resolved.exit_rule.get("port_id",""))
	var matches: Array[Dictionary] = []
	for row: Dictionary in admitted.used_ports:
		if row.port_id==exit_port_id: matches.append(row)
	if matches.size()!=1:
		return "Actual connected exit has no unique complete-body landing"
	var point: Array = matches[0].body_center_pixels
	exit_bank_world = placement.position+Vector2(point[0],point[1])
	return super()

func _source_observe(event: String) -> void:
	super(event)
	if not diagnostics_enabled or event!="committed": return
	print("MAPGEN_WINDCHIME ",JSON.stringify({"event":"committed","scope":"complete_owned_start_module_only","exit_port":exit_port_id,"exit_bank_world":[exit_bank_world.x,exit_bank_world.y],"latches":stage.shot_latch_encounter.observations(),"neighbor_loaded":false}))
