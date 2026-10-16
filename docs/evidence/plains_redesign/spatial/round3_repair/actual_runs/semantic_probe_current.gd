extends SceneTree
var failures := 0
func _initialize() -> void:
	var cases: Array = []
	for root_seed: String in ["level-design-v2-baseline/03", "level-design-v2-baseline/04", "level-design-v2-baseline/01"]:
		var map_index := 1 if root_seed.ends_with("03") else 2
		var generated := PlainsRegionGenerator.new().generate(PlainsRegionCampaign.seed_for(root_seed,map_index),PlayerTuning.load_default(),false,"","intro" if map_index==1 else "advanced")
		var m: Dictionary = generated.manifest
		var nodes: Array = m.route_intents.short_technique
		var broken: Array = []
		for i: int in nodes.size()-1:
			var exists := false
			for edge: Dictionary in m.connections:
				if edge.condition == "open" and ((edge.a == nodes[i] and edge.b == nodes[i+1]) or (edge.bidirectional and edge.a == nodes[i+1] and edge.b == nodes[i])):
					exists = true
			if not exists: broken.append([nodes[i],nodes[i+1]])
		var assembled := PlainsRegionAssembler.new()
		assembled.manifest = m
		var trace = load("res://tests/plains_region_trace.gd").new()
		trace.stage = assembled
		var path: Array = trace.path_to("area_0_1",str(m.merchant_id))
		var actual: Array = []
		for step: Dictionary in path: actual.append({"edge":step.edge.id,"forward":step.forward,"kind":step.edge.kind})
		cases.append({"seed":m.seed,"hash":m.manifest_hash,"family":m.family,"declared":nodes,"missing_links":broken,"actual_camp_policy_path":actual})
		print("SEMANTIC PROBE seed=",m.seed," declared_missing=",broken," actual_camp_edges=",actual.size())
		if not broken.is_empty(): failures += 1
		assembled.free()
	var output := FileAccess.open("res://build/plains_redesign/spatial_preparation/semantic_probe_current.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures":failures,"cases":cases},"  ",true))
	output.close()
	print("SEMANTIC PROBE: ",failures," authored short-route contracts fail")
	quit(1 if failures else 0)
