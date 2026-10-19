extends SceneTree
## Preregistered actual formal corpus; tutorial span is never a target.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var rows: Array = []
	var tuning := PlayerTuning.load_default()
	for index: int in range(1,21):
		var root_seed := "joint-recoil-%02d" % index
		var generator := PlainsRegionGenerator.new()
		generator.root_bell_mode = "v3"
		var result := generator.generate(PlainsRegionCampaign.seed_for(root_seed,1),tuning,false,"","intro")
		var row := {"root_seed":root_seed,"ok":result.get("ok",false),"targets":[]}
		if result.get("ok",false):
			var manifest: Dictionary = result.manifest
			row.manifest = manifest
			for node: Dictionary in manifest.nodes:
				if node.module_id!="plains_recoil_span" or str(node.id).begins_with("tutorial"): continue
				var target := {"node":node,"connections":[]}
				var definition := PlainsRegionGenerator.definition(node)
				target.platforms = []
				for r: Rect2 in definition.platforms: target.platforms.append([r.position.x,r.position.y,r.size.x,r.size.y])
				target.entry = [definition.entry_port.position.x,definition.entry_port.position.y]
				target.exit = [definition.exit_port.position.x,definition.exit_port.position.y]
				for edge: Dictionary in manifest.connections:
					if str(node.id).begins_with(str(edge.id)+"_"): target.connections.append(edge)
				row.targets.append(target)
		rows.append(row)
		print("JOINT RECOIL SCAN: ",root_seed," ok=",row.ok," targets=",row.targets.size())
	var output := "res://build/plains_joint_recoil/scan/actual.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null: quit(2);return
	file.store_string(JSON.stringify({"registered_roots":"joint-recoil-01..20 in numeric order","scope":"Actual generator corpus; no art or Motor acceptance","actual":rows})+"\n")
	quit(0)
