extends SceneTree
## Actual GDScript producer output for independent geometry review, not traversal.
var output := "/tmp/gunman-v16-manifests-third"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	# Dynamic loading lets this diagnostic exit with failure when either
	# producer cannot compile, instead of leaving a SceneTree alive until timeout.
	var world: GDScript = load("res://scripts/generation/forest_exploration_world.gd")
	var producer: GDScript = load("res://scripts/generation/thorn_forest_region_v2_v16.gd")
	if world == null or producer == null or not world.can_instantiate() or not producer.can_instantiate():
		push_error("Actual exploration producer failed to compile")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var rows: Array[Dictionary] = []
	for seed_index: int in 10:
		var root_seed := "forest-depth-hollow-%02d" % seed_index
		for map_index: int in [1,2]:
			var actual_seed: String = producer.seed_for(root_seed,map_index)
			var manifest: Dictionary = world.build(actual_seed,map_index)
			manifest.manifest_hash = producer._hash(manifest)
			var valid: bool = producer.new().validate(manifest, PlayerTuning.load_default())
			var name := "seed%02d-map%s.json" % [seed_index,map_index]
			FileAccess.open(output+"/"+name,FileAccess.WRITE).store_string(JSON.stringify(manifest))
			rows.append({"seed":root_seed,"map":map_index,"file":name,"producer_valid":valid,"platforms":manifest.get("platforms",[]).size(),"bounds":manifest.get("world_bounds",[]),"layout":manifest.get("layout_version","")})
			print("dumped ", name, " valid=", valid)
	FileAccess.open(output+"/index.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"actual_GDScript_world_build_and_producer_validator_only_no_Motor","cases":rows},"\t"))
	print("FOREST EXPLORATION MANIFEST DUMP: ", rows.size(), " actual world cases")
	quit(0)
