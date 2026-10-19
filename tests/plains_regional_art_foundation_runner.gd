extends "res://tools/plains_regional_art_preview.gd"
## Actual installed-node negative, not a plan flag mutation or fake support fixture.
var output_path := "res://build/plains_regional_art/foundation_native_01.json"
var assertions := 0
var failures: Array[String] = []
var rows: Array = []
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label);print("REGIONAL FOUNDATION FAILURE: ",label)
func static_solids(node: Node, found: Array) -> void:
	if node is CollisionShape2D and node.get_parent() is StaticBody2D:
		var shape := node as CollisionShape2D
		var body := node.get_parent() as StaticBody2D
		if (body.collision_layer & 1)!=0 and not shape.disabled and not shape.one_way_collision:
			found.append({"path":str(shape.get_path()),"transform":str(shape.global_transform),"shape":str(shape.shape),"rectangle_size":[shape.shape.size.x,shape.shape.size.y] if shape.shape is RectangleShape2D else []})
	for child: Node in node.get_children(): static_solids(child,found)
func _initialize() -> void:
	auto_accept_quit = false
	root.close_requested.connect(close_review)
	review_seed = "regional-art-02"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): review_seed = arg.trim_prefix("--seed=")
		elif arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
		else: push_error("Unsupported foundation negative argument");quit(2);return
	run.call_deferred()
func run() -> void:
	await super.run()
	if not is_instance_valid(app) or not app.stage is PlainsRegionStage: return
	var actual_stage := app.stage as PlainsRegionStage
	var initial: Dictionary = actual_stage.call("get_regional_art_snapshot")
	check(initial.get("ready",false),"Actual full regional consumer ready before negative")
	var original_manifest: String = JSON.stringify(actual_stage.generated.manifest,"",true)
	var original_solids: Array = []
	static_solids(actual_stage,original_solids)
	var renderer: Node = app.stage.get("regional_art_renderer")
	check(renderer!=null and renderer.has_method("validate_installed_foundations"),"Actual independent installed-foot validator exists")
	var shelters: Array = initial.get("art",{}).get("objects",[]).filter(func(item:Dictionary)->bool:return item.get("role","")=="shelter")
	check(not shelters.is_empty(),"Actual source-owned pavilions present")
	for object: Dictionary in shelters:
		var foundation: Dictionary = object.get("foundation",{})
		check(foundation.get("ok",false) and foundation.get("required",false) and foundation.get("feet",[]).size()==4,"All four actual pavilion feet independently grounded: "+str(object.id))
		for foot: Dictionary in foundation.get("feet",[]):
			check(foot.get("supported",false) and float(foot.get("installed_collision_error_world",INF))<=3.0,"Original installed SOLID collision supports real transformed foot")
		var node := app.stage.get_node_or_null(NodePath(str(object.node_path))) as Node2D
		check(node!=null,"Actual painted pavilion node resolves")
		if node==null: continue
		var original_position := node.position
		var support: Dictionary = {}
		for surface: Dictionary in initial.art_plan.surfaces:
			if surface.id==str(object.surface_id): support=surface
		check(not support.is_empty(),"Actual declared solid source resolves")
		if support.is_empty(): continue
		# Reproduce the original bug: root INSIDE the real floor, some feet
		# outside. Moving the whole pavilion far away would be weaker evidence.
		var target_anchor := float(support.a[0])+30.0
		node.global_position.x += target_anchor-float(object.actual_world_anchor[0])
		var negative: Dictionary = app.stage.call("get_regional_art_snapshot")
		var omitted: Array = negative.get("art",{}).get("omitted",[])
		check(not negative.get("ready",true),"Actual moved overhang makes stage not-ready")
		check(omitted.any(func(item:Dictionary)->bool:return item.get("reason","")=="landmark_foundation_unsupported" and item.get("id","")==object.id),"Actual overhang has explicit preserved consumer refusal")
		check(not node.visible,"Unsupported rendered pavilion is isolated")
		var negative_object: Dictionary = {}
		for item: Dictionary in negative.get("art",{}).get("objects",[]):
			if item.id==object.id: negative_object=item
		check(not negative_object.is_empty(),"Rejected actual node keeps its measured evidence")
		if not negative_object.is_empty():
			var anchor_x: float = negative_object.actual_world_anchor[0]
			check(anchor_x>=float(support.a[0]) and anchor_x<=float(support.b[0]),"Actual root remains INSIDE original real floor")
			check((negative_object.foundation.feet as Array).any(func(foot:Dictionary)->bool:return float(foot.world[0])<float(support.a[0]) or float(foot.world[0])>float(support.b[0])),"Actual source-transformed foot overhang is independently observed")
		var after_solids: Array = []
		static_solids(actual_stage,after_solids)
		check(after_solids==original_solids,"Refusal cannot add a floor or alter any installed static collision")
		check(JSON.stringify(actual_stage.generated.manifest,"",true)==original_manifest,"Consumer refusal never inserts floor or edits gameplay Manifest")
		rows.append({"id":object.id,"original_position":[original_position.x,original_position.y],"negative_position":[node.position.x,node.position.y],"initial_foundation":foundation,"negative_ready":negative.get("ready"),"negative_omitted":omitted.duplicate(true),"negative_objects":negative.get("art",{}).get("objects",[]).duplicate(true)})
		node.position = original_position
		var restored: Dictionary = app.stage.call("get_regional_art_snapshot")
		check(restored.get("ready",false) and node.visible,"Restoring actual node alone re-establishes support and visibility")
	var final: Dictionary = app.stage.call("get_regional_art_snapshot")
	check(final.get("ready",false),"Actual real source restored, no lingering omission")
	var receipt := {"scope":"Actual whole-region installed-pavilion source transforms and original SOLID collider support; negative moves only actual render node, no new floor/physics/plan edit","root_seed":review_seed,"assertions":assertions,"failures":failures,"cases":rows,"initial":initial,"final":final}
	var file := FileAccess.open(output_path,FileAccess.WRITE)
	if file==null:check(false,"Cannot archive actual consumer negative")
	else:file.store_string(JSON.stringify(receipt)+"\n")
	print("PLAINS REGIONAL FOUNDATION: %d assertions, %d failures" % [assertions,failures.size()])
	if not failures.is_empty(): push_error("Actual regional foundation negative failed")
	await close_review()
