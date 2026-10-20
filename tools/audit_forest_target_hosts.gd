extends SceneTree
## Twenty real default App assemblies; no route or aesthetic admission claim.
var output := "res://build/forest_revision04/hosts-W8-audit"
var reference := "res://build/forest_revision04/corpus80-final-W6"
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var references: Dictionary = {}
var reference_files: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--reference="):reference=arg.trim_prefix("--reference=")
	run.call_deferred()

func check(ok: bool,reason: String) -> void:
	if not ok:failures.append(reason)

func frames(count: int) -> void:
	for unused: int in count:await physics_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for directory: String in DirAccess.get_directories_at(reference):
		if not directory.ends_with("-fast"):continue
		var path := reference.path_join(directory).path_join("capture.json")
		var prior: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var m: Dictionary = prior.manifest
		references[str(m.seed)]=m
		reference_files[str(m.seed)]={"path":path,"sha256":FileAccess.get_sha256(path)}
	check(references.size()==20,"twenty_original_corpus_references")
	var canonicalizer := RandomStageGenerator.new()
	for root_index: int in 10:
		for map_index: int in [1,2]:
			var root_seed := "forest-depth-hollow-%02d" % root_index
			var context := "%s/map%s" % [root_seed,map_index]
			var before_failures := failures.size()
			var app := DemoApp.new()
			app.meta_persistence_enabled=false
			root.add_child(app)
			# Omit layout: exercise the actual fresh default, not an explicit pin.
			if not app.start_debug_region(&"thorn_forest",map_index,root_seed,ThornForestRegionGenerator.DEPTH_VERSION):
				check(false,context+"/actual_entry");app.free();continue
			await frames(10)
			var stage := app.stage as ThornForestRegionStage
			if not is_instance_valid(stage) or not stage.assembly_ok:
				check(false,context+"/actual_assembly");app.free();continue
			var m: Dictionary = stage.generated.manifest
			var original := JSON.stringify(m)
			var assembler := stage.assembler as ThornForestRegionAssembler
			var audit := assembler.presentation_host_audit()
			check(m.layout_version==ForestTargetHosts.LAYOUT,context+"/fresh_default_v14")
			var expected: Dictionary = references.get(str(m.seed),{})
			var canonical_equal: bool = not expected.is_empty() and canonicalizer._same_data(m,expected)
			check(canonical_equal,context+"/exact_original_corpus_manifest")
			check(audit.unresolved.is_empty(),context+"/runtime_support_candidates_resolved")
			check(assembler.hook_targets.size()==m.hook_anchors.size(),context+"/no_added_or_removed_targets")
			var targets: Array = []
			var pending := 0
			var fruits := 0
			var rings := 0
			for row: Dictionary in m.hook_anchors:
				var id := str(row.id)
				var mount := ForestTargetHosts.mount_for(audit,id)
				var is_pending: bool = row.get("fruit_presentation")=="existing_marker_pending_local_support"
				if is_pending:pending+=1
				else:check(mount.is_empty(),context+"/no_second_host/"+id)
				var fruit: bool = row.get("fruit_presentation")=="rooted_fruit" or (bool(mount.get("resolved",false)) and mount.get("presentation")=="runtime_rooted_fruit")
				var target: GrappleAnchor = assembler.hook_targets.get(id)
				if not is_instance_valid(target):check(false,context+"/missing_target/"+id);continue
				var script_path := "res://scripts/world/forest_fruit_anchor.gd" if fruit else "res://scripts/world/grapple_anchor.gd"
				var radius := -1.0
				var shape_count := 0
				for child: Node in target.get_children():
					if child is CollisionShape2D:
						shape_count+=1
						if child.shape is CircleShape2D:radius=child.shape.radius
				var target_ok: bool = target.get_script().resource_path==script_path and target.position==Vector2(row.position[0],row.position[1]) and target.collision_layer==8 and target.collision_mask==0 and shape_count==1 and radius==12 and target.hang_enabled==bool(row.get("hang_enabled",false)) and target.is_in_group(&"grapple_target")
				check(target_ok,context+"/original_target_contract/"+id)
				if fruit:fruits+=1
				else:rings+=1
				if not mount.is_empty():
					var host := Rect2(mount.host_rect[0],mount.host_rect[1],mount.host_rect[2],mount.host_rect[3])
					check(is_pending and bool(mount.resolved) and host.grow(0.001).has_point(Vector2(mount.root[0],mount.root[1])),context+"/actual_host_root/"+id)
				targets.append({"id":id,"script":script_path,"position":[target.position.x,target.position.y],"layer":target.collision_layer,"mask":target.collision_mask,"radius":radius,"hang":target.hang_enabled,"contract_passed":target_ok})
			check(pending==audit.mounts.size(),context+"/only_pending_mounts")
			var unchanged: bool = JSON.stringify(m)==original and JSON.stringify(assembler.manifest)==original
			check(unchanged,context+"/manifest_unchanged_after_assembly_and_audit")
			cases.append({"context":context,"seed":m.seed,"map":map_index,"layout":m.layout_version,"manifest_hash":m.manifest_hash,"reference":reference_files.get(str(m.seed),{}),"original_manifest_canonical_equal":canonical_equal,"manifest_unchanged":unchanged,"target_count":targets.size(),"fruits":fruits,"functional_rings":rings,"pending_annotations":pending,"runtime_host_audit":audit,"actual_targets":targets,"passed":failures.size()==before_failures})
			app.process_mode=Node.PROCESS_MODE_DISABLED
			app._cancel_enemy_attacks()
			check(await preload("res://tests/audio_teardown.gd").drain_world(app),context+"/audio_release")
			app.free()
			await process_frame;await process_frame
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"twenty_actual_default_App_runtime_assemblies_not_routes_or_visual_admission","presentation_revision":ForestTargetHosts.PRESENTATION_REVISION,"cases":cases,"failures":failures}));file.close()
	print("FOREST TARGET HOST AUDIT: %s App cases / %s failures" % [cases.size(),failures.size()])
	quit(0 if cases.size()==20 and failures.is_empty() else 1)
