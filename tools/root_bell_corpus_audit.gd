extends SceneTree
## Read-only exact delivery corpus; distinct from development/pilot seed audit.
var output := "res://build/production_repair/ecology/delivery_corpus.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	var rows: Array=[]
	var failures: Array=[]
	for i: int in 10:
		var root_seed := "level-design-v2-baseline"+("/%02d"%i if i else "")
		for map_index: int in [1,2]:
			var seed_value:=PlainsRegionCampaign.seed_for(root_seed,map_index)
			var old:=PlainsRegionGenerator.new();old.root_bell_mode="v2"
			var current:=PlainsRegionGenerator.new();current.root_bell_mode="v3"
			var difficulty:="intro" if map_index==1 else "advanced"
			var a:=old.generate(seed_value,PlayerTuning.load_default(),false,"",difficulty)
			var b:=current.generate(seed_value,PlayerTuning.load_default(),false,"",difficulty)
			if not a.ok or not b.ok:failures.append(seed_value);continue
			var inspected: Array=[]
			for node: Dictionary in b.manifest.nodes:
				if node.module_id!="region_connection":continue
				var facts:=PlainsRootBellEncounterV3.inspect(b.manifest,node,PlainsRegionGenerator.definition)
				var has_guard: bool=b.manifest.enemies.any(func(e: Dictionary)->bool:return e.get("area","")==node.id and str(e.id).begins_with("plains/enemy/lane/"))
				inspected.append({"node":node.id,"guard":has_guard,"facts":facts})
			rows.append({"root_seed":root_seed,"map_index":map_index,"actual_seed":seed_value,"v11_hash":a.manifest.manifest_hash,"v12_hash":b.manifest.manifest_hash,"v11_admission":a.manifest.root_bell_admission,"v12_admission":b.manifest.root_bell_admission,"unchanged_enemy_count":a.manifest.enemies.size()==b.manifest.enemies.size(),"unchanged_nodes_connections_rewards":a.manifest.nodes==b.manifest.nodes and a.manifest.connections==b.manifest.connections and a.manifest.rewards==b.manifest.rewards,"connections":inspected})
	var report: Dictionary={"scope":"Read-only regeneration of exact original V3 10root x2map delivery corpus; route observations must be joined to original80captures separately; no native traversal or pixel claim","root_seed_basis":"docs/evidence/region_production_v3/final_multiseed_independent/check_actual_matrix.py expected corpus","rows":rows,"failures":failures}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	print("ROOT BELL DELIVERY CORPUS: maps=%s failures=%s"%[rows.size(),failures.size()])
	finish.call_deferred()
func finish()->void:quit()
