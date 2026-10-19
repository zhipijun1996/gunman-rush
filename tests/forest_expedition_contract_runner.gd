extends SceneTree
## Data/registry invariants, not a claim of Motor traversal or fun.
var checks: Array=[]
var cases: Array=[]
var output:="res://build/forest_feedback/contracts01.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok:printerr("FOREST EXPEDITION CONTRACT FAIL: "+label)
func run() -> void:
	var registry:=ThornForestRegionGenerator.new()
	var tuning:=PlayerTuning.load_default()
	var capability: Dictionary={"grapple":true,"abilities":["grapple"],"forest_layout_version":ThornForestRegionGenerator.DEPTH_LAYOUT_EXPEDITION}
	for root_seed: String in ["forest-depth-hollow-00","forest-depth-hollow-01","forest-depth-hollow-02","forest-depth-hollow-03","forest-depth-hollow-04","forest-depth-hollow-05","forest-depth-hollow-06","forest-depth-hollow-07","forest-depth-hollow-08","forest-depth-hollow-09"]:
		for map_index: int in [1,2]:
			var seed_value:=ThornForestRegionGenerator.seed_for(root_seed,map_index)
			var generated:=registry.generate_version(ThornForestRegionGenerator.DEPTH_VERSION,seed_value,tuning,map_index,capability)
			check(bool(generated.get("ok",false)),"expanded data generates / "+seed_value)
			if not generated.get("ok",false):continue
			var m: Dictionary=generated.manifest
			check(registry.validate(m,tuning),"complete expanded manifest validates / "+seed_value)
			check(ForestSceneLanguage.validate(m),"every block has consumed scene language / "+seed_value)
			var old:=preload("res://scripts/generation/thorn_forest_region_v2_v10.gd").new().generate(seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"]})
			var old_pinned:=registry.generate_version(ThornForestRegionGenerator.DEPTH_VERSION,seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"],"forest_layout_version":ThornForestRegionGenerator.DEPTH_LAYOUT_CANOPY})
			check(RandomStageGenerator.new()._same_data(old,old_pinned),"old v10 complete pinned output retained / "+seed_value)
			var kinds: Dictionary={};var left:=INF;var right:=-INF;var old_left:=INF;var old_right:=-INF
			var boss_ids: Dictionary={}
			for row: Dictionary in m.boss_contract.get("platforms",[]):boss_ids[str(row.id)]=true
			for row: Dictionary in m.platforms:
				kinds[row.scene_kind]=true
				if not boss_ids.has(str(row.id)):left=minf(left,float(row.rect[0]));right=maxf(right,float(row.rect[0])+float(row.rect[2]))
			for row: Dictionary in old.manifest.platforms:
				if not boss_ids.has(str(row.id)):old_left=minf(old_left,float(row.rect[0]));old_right=maxf(old_right,float(row.rect[0])+float(row.rect[2]))
			check(right-left>(old_right-old_left)*2,"non-Boss support span over twice old actual support span / "+seed_value)
			check(kinds.size()>=4,"distinct block languages not just labels / "+seed_value)
			check(m.enemies.size()>old.manifest.enemies.size(),"more placed encounters than old map / "+seed_value)
			check(m.boss_content==old.manifest.boss_content if map_index==2 else true,"original Boss2 content preserved / "+seed_value)
			var malformed: Dictionary=m.duplicate(true);malformed.platforms[0].scene_kind="generic_green_block"
			check(not registry.validate(malformed,tuning),"edited scene language refused / "+seed_value)
			malformed=m.duplicate(true)
			for instance: Dictionary in malformed.geometry_instances:
				if instance.id=="western_bridge":instance.local_geometry.action_program.clear()
			check(not registry.validate(malformed,tuning),"edited air program refused / "+seed_value)
			cases.append({"seed":root_seed,"map_index":map_index,"manifest":m,"non_boss_span":right-left,"old_non_boss_span":old_right-old_left,"enemies":m.enemies.size(),"old_enemies":old.manifest.enemies.size(),"scene_kinds":kinds.keys()})
	var failures:=checks.filter(func(c: Dictionary) -> bool:return not c.passed).size()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"scope":"data_registry_not_motor_or_fun","checks":checks,"cases":cases,"failures":failures}));file.close()
	print("FOREST EXPEDITION CONTRACTS: %s assertions, %s failures"%[checks.size(),failures])
	quit(0 if failures==0 else 1)
