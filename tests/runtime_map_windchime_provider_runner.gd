extends SceneTree
## Actual SDK generation drives admission. No sample map or edited geometry is
## substituted for the positive; copies below are explicit rejection probes.
const PROFILE = preload("res://game/world/generation/mapgen/runtime_map_generation_profile.gd")
const DATA = preload("res://addons/mapgen/data_json.gd")
var checks := 0
var failures := 0
var trace: Array[Dictionary] = []
var source := RuntimeMapGenerationJob.new()
var lifetime := DemoLifetime.new()
var ticket: RefCounted
var request := LevelRequest.new()
var actual: Dictionary
var provenance: Dictionary
var bindings: Dictionary
var ids: Array[String] = []
var spawn: Vector2
var selected: Dictionary

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("WINDCHIME PROVIDER: "+label)

func admit(result: Dictionary, source_record: Dictionary = {}) -> LevelBuildResult:
	return RuntimeMapV2Provider.load_generated_level(request,result,ids,spawn,bindings,provenance if source_record.is_empty() else source_record)

func run() -> void:
	var profile := PROFILE.read_profile()
	var input := RuntimeMapFrozenSource.read_binding_file(RuntimeMapGeneratedSlice.DEFAULT_BINDINGS_PATH,RuntimeMapGeneratedSlice.DEFAULT_BINDINGS_SHA256)
	check(profile.ok and input.ok,"real installed profile and original three-module recipe decode")
	if not profile.ok or not input.ok:
		finish()
		return
	request.root_seed = str(profile.request.seed)
	request.tuning = PlayerTuning.load_default()
	request.capabilities = {"profile":"explicit_upstream_conformance_not_a_grant","collision_half_extents":profile.request.player.clearance_half_extents_pixels.duplicate()}
	var empty: Array[String] = []
	ticket = source.begin(root,lifetime,request,profile.request,profile.config,input.bindings,empty)
	check(ticket!=null,"existing source owns the real generation job")
	if ticket==null:
		finish()
		return
	while source.phase(ticket) in ["preload","generate","validate"]:
		source.tick(ticket,lifetime)
		await process_frame
	check(source.phase(ticket)=="ready","actual SDK result and existing three-module Plan admitted: "+source.error(ticket))
	if source.phase(ticket)!="ready":
		finish()
		return
	actual = source.actual_result(ticket,lifetime)
	provenance = source.provenance(ticket,lifetime)
	var roots: Array[Dictionary] = []
	for row: Dictionary in actual.map.instances:
		if row.get("module_id")=="game-plains-windchime-lesson" and row.get("content_version")=="sha256:b2ee44df5422a7b4dd9be1358a075c46cefb00992de802607389f6f94ecfa433" and row.get("role")=="start": roots.append(row)
	check(roots.size()==1,"actual generated start selected by exact template/content/role, never an M number")
	if roots.size()!=1:
		finish()
		return
	selected = roots[0]
	ids.assign([str(selected.id)])
	var content: Dictionary = actual.content_store[selected.content_ref]
	var platform: Array = content.platforms[0]
	spawn = Vector2(selected.origin_blocks[0],selected.origin_blocks[1])*128.0+Vector2(float(platform[0])+float(platform[2])*0.5,float(platform[1])-float(request.capabilities.collision_half_extents[1]))
	bindings = {"schema":"gunman-rush/runtime-map-bindings/v1","version":"windchime-provider-actual-r1","selected_instances":ids.duplicate(),"spawns":{"seam":[spawn.x,spawn.y]},"scope":"single_complete_start_module_no_neighbor_traversal"}
	var original_half: Array = request.capabilities.collision_half_extents.duplicate()
	var before := DATA.canonical(actual)
	var built := admit(actual)
	check(built.accepted(),"complete original start accepted with closed unused helper: "+built.error)
	if not built.accepted():
		finish()
		return
	var definition: PlatformingModuleDefinition = built.plan.modules[0].definition
	check(built.plan.modules.size()==1 and built.plan.connections.is_empty() and built.plan.actors.is_empty() and built.plan.pickups.is_empty(),"single full module; no invented neighbor/enemy/reward coverage")
	check(definition.platforms.size()==content.platforms.size()+selected.seals.size(),"all original platforms and original unused-port seals enter exactly once")
	for index: int in content.platforms.size():
		var rect: Array = content.platforms[index]
		check(definition.platforms[index]==Rect2(rect[0],rect[1],rect[2],rect[3]),"unchanged original materialized platform: "+str(index))
	for index: int in selected.seals.size():
		var rect: Array = selected.seals[index].rect_pixels
		check(definition.platforms[content.platforms.size()+index]==Rect2(rect[0],rect[1],rect[2],rect[3]),"unchanged original seal: "+str(index))
	check(not definition._standing_point(Vector2(content.entry_port[0],content.entry_port[1])),"actual closed unused entry blocks old helper; positive did not silently remove its seal")
	check(definition.is_valid() and definition.supports(request.tuning),"original geometry/body/capability validators still run and pass")
	check(definition.get_meta("runtime_map_v2_authored_helpers").entry_port==content.entry_port and definition.get_meta("runtime_map_v2_content")==content,"all original helpers/content remain source provenance")
	var admission: Dictionary = definition.get_meta("runtime_map_v2_port_admission")
	check(admission.policy=="runtime-map-used-port-banks/1" and admission.used_ports.size()==selected.connected_port_ids.size(),"admission enumerates actual used ports")
	check(admission.used_ports[0].port_id==selected.connected_port_ids[0] and admission.used_ports[0].body_center_pixels==content.exit_port,"actual used exit resolves original physical receiving shore, not geometric aperture centre")
	var used_port: Dictionary
	for port: Dictionary in selected.ports:
		if port.id==selected.connected_port_ids[0]: used_port=port
	check(Vector2(content.exit_port[0],content.exit_port[1])!=Vector2(used_port.local_position_pixels[0],used_port.local_position_pixels[1]),"geometric Port is explicitly different from a supported body centre")
	var same := admit(actual)
	check(same.accepted() and same.plan.map_hash==built.plan.map_hash,"same actual result/scope/bindings replay identity")
	var state := PlainsRegionState.new()
	state.bind_map(built.plan.map_hash)
	var saved := state.snapshot()
	check(PlainsRegionState.new().restore(saved,built.plan.map_hash),"current admitted load restores original run-local state schema")
	var identity: Dictionary = built.plan.get_meta("runtime_map_v2_identity")
	check(identity.generation_input_fingerprint==actual.request_fingerprint and identity.host_load.adapter_version=="runtime-map-generated/3" and identity.host_load.port_admission_policy==admission.policy,"new host policy identity preserves upstream fingerprint verbatim")
	var old_policy: Dictionary = identity.host_load.duplicate(true)
	old_policy.adapter_version = "runtime-map-generated/2"
	old_policy.erase("port_admission_policy")
	var old_policy_record := saved.duplicate(true)
	old_policy_record.manifest_hash = JSON.stringify(old_policy,"",true,true).sha256_text()
	check(not PlainsRegionState.new().restore(old_policy_record,built.plan.map_hash),"old host-admission policy record explicitly refuses new policy identity")
	for mode: String in ["blocked_used_bank","missing_exit_shore","wrong_connection","missing_connection","wrong_peer_face","illegal_permission","legal_unidirectional","body_snapshot","unknown_latch","old_implementation"]:
		var changed: Dictionary = actual.duplicate(true)
		var changed_content: Dictionary = changed.content_store[selected.content_ref]
		var changed_instance: Dictionary
		for row: Dictionary in changed.map.instances:
			if row.id==selected.id: changed_instance = row
		var source_record: Dictionary = provenance.duplicate(true)
		match mode:
			"blocked_used_bank": changed_content.platforms.append([480,120,32,100])
			"missing_exit_shore": changed_content.platforms.remove_at(1)
			"wrong_connection":
				for edge: Dictionary in changed.map.connections:
					if edge.a.instance_id==selected.id or edge.b.instance_id==selected.id: edge.position_pixels[1] += 1
			"missing_connection": changed.map.connections=changed.map.connections.filter(func(edge: Dictionary) -> bool: return edge.a.instance_id!=selected.id and edge.b.instance_id!=selected.id)
			"wrong_peer_face":
				for edge: Dictionary in changed.map.connections:
					if edge.a.instance_id!=selected.id and edge.b.instance_id!=selected.id: continue
					var peer: Dictionary = edge.b if edge.a.instance_id==selected.id else edge.a
					for row: Dictionary in changed.map.instances:
						if row.id!=peer.instance_id: continue
						for port: Dictionary in row.ports:
							if port.id==peer.port_id: port.face="RIGHT" if port.face=="LEFT" else "LEFT"
			"illegal_permission","legal_unidirectional":
				for port: Dictionary in changed_instance.ports:
					if port.id in changed_instance.connected_port_ids: port.permission="IN" if mode=="illegal_permission" else "INPUT"
			"body_snapshot": request.capabilities.collision_half_extents=[13,18]
			"unknown_latch": changed_content.latches[0].kind="timed_unknown"
			"old_implementation":
				source_record.implementation="mapgen/gdscript-candidate-0.4.0"
				source_record.algorithm_package.version="0.4.0"
		var refused := admit(changed,source_record)
		check(not refused.accepted() and refused.plan==null and not refused.error.is_empty(),"explicit no-Plan rejection: "+mode)
		if mode=="illegal_permission": check("invalid protocol value" in refused.error,"protocol-external IN is illegal")
		if mode=="legal_unidirectional": check("host capability unsupported for legal INPUT" in refused.error,"legal INPUT is distinctly unsupported")
		trace.append({"case":mode,"error":refused.error})
		request.capabilities.collision_half_extents=original_half.duplicate()
	var helper_only: Dictionary = actual.duplicate(true)
	helper_only.content_store[selected.content_ref].entry_port=[24,100]
	var revised := admit(helper_only)
	check(revised.accepted(),"retained inactive helper is not a standing/admission authority")
	check(revised.accepted() and revised.plan.map_hash!=built.plan.map_hash and not PlainsRegionState.new().restore(saved,revised.plan.map_hash),"changed source helper still changes content identity and refuses old recovery")
	check(DATA.canonical(actual)==before,"all original actual result content and fingerprint unchanged after positive/negative probes")
	finish()

func finish() -> void:
	source.close()
	lifetime.end()
	var path := "res://build/mapgen041/windchime_provider.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source":"actual_installed_sdk_generation","selected_instance":selected,"trace":trace},"  "))
	print("RUNTIME_MAP_WINDCHIME_PROVIDER checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
