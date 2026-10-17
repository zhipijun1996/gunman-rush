extends SceneTree
## New hollow/clearing EXPERIMENT data contracts. Old macroA runner is archived;
## these data checks neither erase its failures nor establish physical routes.
const GEN := preload("res://scripts/generation/thorn_forest_region_v2.gd")
var assertions := 0
var failures := 0
var checks: Array = []
var representatives: Dictionary = {}
var families: Dictionary = {}
var adjacency: Dictionary = {}
var output := "res://build/forest_depth/spatial/hollow-experiment/capture.json"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	assertions+=1;checks.append({"label":label,"passed":ok})
	if not ok:failures+=1;printerr("FOREST TOPOLOGY FAIL: "+label)
func row(rows: Array,id: String) -> Dictionary:
	for value: Dictionary in rows:
		if value.id==id:return value
	return {}
func same(a: Variant,b: Variant) -> bool:return RandomStageGenerator.new()._same_data(a,b)
func route_nodes(m: Dictionary,ids: Array) -> Array:
	var result: Array=["arrival"];var at:="arrival"
	for id: String in ids:
		var edge:=row(m.connections,id)
		check(not edge.is_empty() and edge.a==at,"actual route adjacency "+id)
		if edge.is_empty():return result
		at=str(edge.b);result.append(at)
	return result
func inspect(m: Dictionary,generator: RefCounted,tuning: PlayerTuning) -> void:
	check(m.production_pool==false and m.admission.motor=="unverified","data candidate is not gameplay promotion")
	check(m.geometry_instances.size()==1,"one shared giant trunk, no three lab boxes")
	var instance: Dictionary=m.geometry_instances[0]
	var source:=ForestHollowTrunkGeometry.build("deep_zeroR")
	check(same(instance.source_geometry,source),"exact current factory source recorded")
	check(instance.facing==1 and instance.translation==[600.0,600.0],"actual translation, no unproved mirror")
	check(instance.native_verified==false,"whole macro assembly does not inherit local golden acceptance")
	var split: bool=int(m.choices.skeleton)==1
	check(instance.derivations.size()==(2 if split else 1),"actual split-cavity derivation is explicit")
	for raw: Dictionary in instance.local_geometry.platforms:
		var world:=row(m.platforms,str(instance.platform_id_map[raw.id]))
		check(not world.is_empty(),"shared actual platform present "+raw.id)
		if world.is_empty():continue
		check(same(world.rect,[float(raw.rect[0])+600,float(raw.rect[1])+600,raw.rect[2],raw.rect[3]]) and world.one_way==raw.one_way,"shared platform exact translated bytes "+raw.id)
	check(m.dangers==[[810.0,482.0,120.0,24.0]],"actual thorn occupies only removed upper solid cap, not safe window")
	var ceiling:=row(m.platforms,"hollow__trunk_above_window")
	check(ceiling.rect==[810.0,80.0,120.0,402.0] and ceiling.rect[1]+ceiling.rect[3]==m.dangers[0][1],"real solid ends exactly where replacement thorn begins")
	check(m.dangers[0][1]+m.dangers[0][3]==m.thorn_window_contract.safe_window_world[1],"safe upper opening boundary preserved without spike/solid overlap")
	check(instance.danger_indices==[0],"shared derived danger has actual manifest index")
	check(m.danger_presentations==[{"facing":"down"}],"explicit ceiling-thorn presentation aligns with actual hazard index")
	for raw: Dictionary in instance.local_geometry.hook_anchors:
		var world:=row(m.hook_anchors,str(instance.anchor_id_map[raw.id]))
		check(same(world.position,[float(raw.position[0])+600,float(raw.position[1])+600]),"static ring exact translated position "+raw.id)
	for id: String in ["upper_out","lower_in","inner_recovery"]:
		var edge:=row(m.connections,id)
		check(edge.geometry_instance=="hollow" and edge.has("from_port") and edge.has("to_port") and edge.has("landing_support_id"),"formal consumer physical port contract "+id)
	for name: String in ["fast","growth","high_return","change_mind"]:
		var nodes:=route_nodes(m,m.routes[name])
		check(nodes[-1]==("gate_ready" if name in ["fast","growth"] else "camp"),"actual itinerary endpoint "+name)
		if name in ["growth","high_return"]:check(nodes.has("cache") and nodes.has("camp"),"reward and actual safe camp included "+name)
		check(not m.routes[name].has("arena_entry"),"route stops outside Boss fight "+name)
	check(not same(m.routes.fast,m.routes.growth),"growth does not duplicate fast itinerary")
	for id: String in m.macro_loops:
		var edges: Array=m.macro_loops[id]
		check(not edges.is_empty(),"actual loop has edges "+id)
		var first:=row(m.connections,str(edges[0]));var at: String=first.a
		for edge_id: String in edges:
			var edge:=row(m.connections,edge_id);check(edge.a==at,"loop directed continuity "+edge_id);at=str(edge.b)
		check(at==str(first.a),"loop actually closes "+id)
	if int(m.map_index)==2:
		var left: Array=m.macro_loops.left;var right: Array=m.macro_loops.right
		var shared: Array=[]
		for id: String in left:
			if right.has(id):shared.append(id)
		check(shared==["inner_recovery"] if not split else shared.is_empty(),"shared-edge versus shared-node actually changes edges")
	var camp:=GEN._point(m.merchant_position)
	for actor: Dictionary in m.enemies:
		check(GEN._point(actor.position).distance_to(GEN._point(m.spawn))>=150,"explicit safe spawn reserve "+str(actor.id))
		check(GEN._point(actor.position).distance_to(camp)>=350,"actual safe camp exclusion "+str(actor.id))
		var definition:=load(actor.definition_path) as EnemyDefinition
		check(String(definition.behavior_id)==str(actor.behavior_id) and String(definition.stable_id)==str(actor.stable_id),"actual Definition identity, no invented badger "+str(actor.id))
		if not actor.aerial:
			var support:=row(m.platforms,str(actor.support_id))
			check(not support.is_empty() and absf(float(actor.position[1])+definition.collision_size.y*.5-float(support.rect[1]))<.01,"actual ground enemy feet "+str(actor.id))
	for edge: Dictionary in m.connections:
		for step: Dictionary in edge.get("steps",[]):
			var support:=row(m.platforms,str(step.support_id))
			check(not support.is_empty(),"declared ordinary destination support exists "+str(edge.id))
			if support.is_empty():continue
			var rect:=GEN._rect(support.rect);var at:=GEN._point(step.landing)
			check(absf(at.y+18-rect.position.y)<.01 and at.x-12>=rect.position.x and at.x+12<=rect.end.x,"declared ordinary full-body landing "+str(edge.id))
		if edge.a=="cache":check(edge.get("claim_before_edge")==true and edge.claim_area=="cache" and edge.claim_id==m.rewards[0].id,"actual reward claim-before-leaving contract "+str(edge.id))
	for field: String in ["platform","anchor","reward","route"]:
		var changed:=m.duplicate(true)
		match field:
			"platform":changed.platforms[0].rect[0]+=1
			"anchor":changed.hook_anchors[0].position[0]+=1
			"reward":changed.rewards[0].position[0]+=1
			"route":changed.routes.high_return=[]
		changed.manifest_hash=GEN._hash(changed)
		check(not generator.validate_spatial_candidate(changed,tuning),"regeneration rejects repaired-hash tamper "+field)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	var generator:=GEN.new();var tuning:=PlayerTuning.load_default()
	check(ThornForestRegionGenerator.VERSION==ThornForestRegionGenerator.LEGACY_VERSION,"default remains v1 during experiment")
	for root_index: int in 8:
		for map_index: int in [1,2]:
			var seed_value:=GEN.seed_for("forest-depth-hollow-%02d"%root_index,map_index)
			var result: Dictionary=generator.generate_spatial_candidate(seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"]})
			check(result.ok,"fixed corpus candidate builds "+seed_value)
			if not result.ok:continue
			var m: Dictionary=result.manifest
			check(generator.validate_spatial_candidate(m,tuning),"candidate deterministic validator "+seed_value)
			check(same(m,generator.generate_spatial_candidate(seed_value,tuning,map_index,{"grapple":true}).manifest),"same seed reconstructs complete data "+seed_value)
			families[m.family]=true;adjacency[GEN.topology_signature(m)]=true
			if not representatives.has(m.family):representatives[m.family]={"root_seed":"forest-depth-hollow-%02d"%root_index,"map_index":map_index,"manifest":m}
			inspect(m,generator,tuning)
	check(families.size()==4,"fixed eight roots x two maps cover all four actual skeletons; no reselection")
	check(adjacency.size()>=4,"actual directed graph diversity, not camp-role label count")
	var file: FileAccess
	DirAccess.make_dir_recursive_absolute(output.get_base_dir());file=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"task_id":"FOREST-DEPTH-02","scope":"new hollow/clearing experiment DATA ONLY; not Motor or content approval","assertions":assertions,"failures":failures,"engine":Engine.get_version_info(),"checks":checks,"families":families.keys(),"representative_manifests":representatives,"sampling":"8 fixed roots x 2 maps; no reselection","source_sha256":FileAccess.get_sha256("res://scripts/generation/thorn_forest_region_v2.gd")},"\t"));file.close()
	print("FOREST DEPTH TOPOLOGY: %s assertions, %s failures; new experiment DATA ONLY"%[assertions,failures]);quit(1 if failures else 0)
