extends SceneTree
## Source and installed-node contract. No screenshot or artistic approval claim.
const PRIOR_MANIFESTS:Dictionary={
	"joint-recoil-01":{"default":"98a71fc9d52471dfbc8ec6b25dfb09d1a1326d158cd9dbc71367966ef0ec2a51","deep":"a8e7bf5fffeb893539711577b0fb7c0809e42c9d425e7f20c48f673e5576d5f8"},
	"joint-recoil-07":{"default":"d5c548f7d177852e42b52cfed73146096e3439ee93162784e2640b5e1f280da3","deep":"29f81cfa36891e15a06e9006c0353d0473a1343106514228f0ff90d3682e5e6d"}
}
class NativeArtStage:
	extends Node2D
	var assembler:PlainsRegionAssembler
var assertions:=0
var failures:Array[String]=[]
var output_path:=""
var baseline_cache:Dictionary={}

func check(ok:bool,label:String)->void:
	assertions+=1
	if not ok:failures.append(label);print("ART LANGUAGE FAILURE: ",label)

func packed(points:Array)->PackedVector2Array:
	var result:=PackedVector2Array()
	for point:Array in points:result.append(Vector2(float(point[0]),float(point[1])))
	return result

func arrays(points:PackedVector2Array)->Array:
	var result:Array=[]
	for point:Vector2 in points:result.append([point.x,point.y])
	return result

func _initialize()->void:
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output_path=argument.trim_prefix("--output=")
	if output_path.is_empty():print("Missing --output path");quit(2);return
	run.call_deferred()

func verify_baselines(tuning:PlayerTuning)->void:
	for root_seed:String in PRIOR_MANIFESTS:
		var seed:=PlainsRegionCampaign.seed_for(root_seed,1)
		var generator:=PlainsRegionGenerator.new();generator.root_bell_mode="v3"
		var ordinary:=generator.generate(seed,tuning,false,"","intro")
		check(ordinary.get("ok",false) and ordinary.manifest.manifest_hash==PRIOR_MANIFESTS[root_seed].default,root_seed+": original default Manifest bytes unchanged")
		var deep:=PlainsRegionArtPlan.generate(seed,tuning)
		check(deep.get("ok",false) and deep.manifest.manifest_hash==PRIOR_MANIFESTS[root_seed].deep,root_seed+": original noncandidate deep profile unchanged")
		if deep.get("ok",false):baseline_cache[seed]=deep.manifest

func verify_embedding_counterfactual(manifest:Dictionary)->Dictionary:
	var baseline:Dictionary=baseline_cache.get(str(manifest.seed),{})
	var origin:="cached_actual_regional_baseline_same_seed_family_attempt"
	if baseline.is_empty() or baseline.family!=manifest.family or baseline.attempt!=manifest.attempt:
		var generator:=PlainsRegionGenerator.new()
		generator.root_bell_mode="v3";generator.regional_art_profile="continuous_plains_v1"
		baseline=generator._candidate(str(manifest.seed),false,str(manifest.family),int(manifest.attempt),str(manifest.difficulty))
		origin="actual_regional_candidate_same_seed_family_attempt_no_reroll"
	check(baseline.seed==manifest.seed and baseline.family==manifest.family and baseline.attempt==manifest.attempt,"Counterfactual holds exact Seed, topology family and attempt constant")
	check(PlainsRegionArtPlan.topology_signature(baseline)==PlainsRegionArtPlan.topology_signature(manifest),"Art-aware embedding preserves exact topology while changing spatial allocation")
	var before_recipes:Array=[]
	var after_recipes:Array=[]
	for edge:Dictionary in baseline.connections:
		if edge.kind=="horizontal":before_recipes.append([edge.id,edge.design_recipe])
	for edge:Dictionary in manifest.connections:
		if edge.kind=="horizontal":after_recipes.append([edge.id,edge.design_recipe])
	check(before_recipes==after_recipes,"Counterfactual keeps actual operation recipes and action order unchanged")
	var old_columns:Array=baseline.topology.column_positions
	var new_columns:Array=manifest.topology.column_positions
	check(old_columns!=new_columns,"Selected art language really changes world coordinates, not only metadata")
	var minimums:Dictionary=manifest.art_language_intent.minimum_column_spans
	for index:int in range(new_columns.size()-1):
		check(float(new_columns[index+1])-float(new_columns[index])>=float(minimums[str(index)]),"Actual embedded column honors precomputed art minimum span")
	var edge_budgets:Array=[]
	for edge:Dictionary in manifest.connections:
		if edge.kind!="horizontal":continue
		var from_area:Dictionary={};var to_area:Dictionary={}
		for area:Dictionary in manifest.areas:
			if area.id==edge.a:from_area=area
			if area.id==edge.b:to_area=area
		var operation_end:=-INF
		for node_index:int in edge.modules:
			var node:Dictionary=manifest.nodes[node_index]
			var definition:=PlainsRegionGenerator.definition(node)
			operation_end=maxf(operation_end,float(node.offset[0])+definition.world_bounds.end.x)
		var arrival_boundary:=float(to_area.position[0])-PlainsRegionGenerator.HALF
		var available:=arrival_boundary-operation_end
		var modules:Array=edge.art_language.modules
		var shoulder:=maxf(float(modules[0].assembly.shoulder_width),float(modules[-1].assembly.shoulder_width))
		var quiet:=float(edge.art_language.quiet_arrival_width)
		check(available>=2.0*shoulder+quiet+80.0,"Measured actual operation endpoint leaves both shoulder budgets and quiet arrival before neighbor")
		edge_budgets.append({"edge_id":edge.id,"column":from_area.col,"actual_operation_end_x":operation_end,"neighbor_arrival_boundary_x":arrival_boundary,"remaining_world_span":available,"shoulder_budget_each":shoulder,"quiet_arrival_width":quiet,"existing_join_reserve":80.0})
	return {"baseline_origin":origin,"seed":manifest.seed,"family":manifest.family,"attempt":manifest.attempt,"baseline_manifest_hash":baseline.manifest_hash,"before_column_positions":old_columns,"after_column_positions":new_columns,"minimum_column_spans":minimums,"unchanged_topology_signature":PlainsRegionArtPlan.topology_signature(baseline),"actual_edge_budgets":edge_budgets,"scope":"Actual layout allocation proof; shoulder/root painted pieces are still missing and not claimed instantiated"}

func verify_language_negatives()->void:
	var catalog:=PlainsArtLanguage.catalog()
	for module_id:String in catalog.module_families:
		var actual:=RandomStageGenerator.new().definition_for(module_id,false,false)
		var planned:=PlainsArtLanguage.plan_definition(actual,str(catalog.module_families[module_id]),"native/catalog/"+module_id)
		check(planned.get("ok",false),"Every declared finite module family is expressible from its actual Definition: "+module_id)
		if not planned.get("ok",false):continue
		for surface:Dictionary in planned.assembly.platforms:
			var rect:Rect2=actual.platforms[int(surface.platform_index)]
			var parts:Dictionary=surface.assembly_plan
			check(parts.get("ok",false) and absf(float(parts.covered_length)-float(parts.target_length))<0.00001,"Finite fixed pieces actually cover source contact span")
			if rect.size.y>=rect.size.x:check(surface.structural_role=="vertical_wall" and parts.axis=="y" and float(parts.target_length)==rect.size.y,"Tall narrow source obstacle becomes vertical wall, not horizontal floating bank")
			else:check(parts.axis=="x" and float(parts.target_length)==rect.size.x,"Horizontal source contact uses horizontal family part span")
			check(float(parts.pieces[0].offset)==0.0 and absf(float(parts.pieces[-1].offset)+float(parts.pieces[-1].axis_length)-float(parts.target_length))<0.00001,"Actual part coverage retains both uncut endpoints")
			for piece:Dictionary in parts.pieces:
				check(float(piece.source_scale)==1.0 and float(piece.axis_length)==float(catalog.part_grammar.parts[piece.part_id].axis_length),"Every requested piece uses a fixed registered dimension without stretch")
			for joint:Dictionary in parts.joints:
				var left:Dictionary=parts.pieces[int(joint.from_part)]
				var right:Dictionary=parts.pieces[int(joint.to_part)]
				var overlap:=float(left.offset)+float(left.axis_length)-float(right.offset)
				check(absf(overlap-float(joint.overlap_world))<0.00001 and overlap>=float(catalog.part_grammar.overlap_world_range[0]) and overlap<=float(catalog.part_grammar.overlap_world_range[1]),"Actual assembly intervals overlap only inside declared finite joint window")
	check(not PlainsArtLanguage._assemble_parts(40.0,"grounded_bank",catalog.part_grammar).get("ok",false),"Unexpressible small bank is rejected, not compressed or truncated")
	for span:float in [70.0,85.0,90.0]:
		check(PlainsArtLanguage._assemble_parts(span,"supported_lintel",catalog.part_grammar).get("ok",false),"Registered short beam variant has legal fixed pieces: "+str(span))
	check(not PlainsArtLanguage._assemble_parts(100.25,"grounded_bank",catalog.part_grammar).get("ok",false),"Off-source-pixel contact length is refused without coordinate rounding")
	var definition:=RandomStageGenerator.new().definition_for("plains_recoil_span",false,false)
	var expression:=PlainsArtLanguage.plan_definition(definition,"fissure_banks","native/recoil")
	check(expression.get("ok",false) and PlainsArtLanguage.expression_errors(expression).is_empty(),"Actual recoil Definition has registered finite family expression")
	if not expression.get("ok",false):return
	for mutation:Dictionary in [
		{"path":["family_id"],"value":"unknown_family","reason":"Unregistered landform family"},
		{"path":["size_spec","id"],"value":"w799","reason":"Unregistered finite size"},
		{"path":["size_spec","operation_width"],"value":799.0,"reason":"Width differs from registered source"},
		{"path":["size_spec","visual_body_depth"],"value":999.0,"reason":"Body depth exceeds registered family"},
		{"path":["assembly","scale"],"value":1.1,"reason":"Stretch instead of registered size"},
		{"path":["assembly","allow_free_floating_rock"],"value":true,"reason":"Floating rock cannot satisfy grounded family"},
		{"path":["assembly","support"],"value":"air","reason":"Support relationship missing"},
		{"path":["assembly","contour"],"value":"rectangle_with_alpha_skirt","reason":"Undeclared contour implementation"},
		{"path":["ports","boundary"],"value":"wood_end","reason":"Wrong cross-section interface"},
		{"path":["ports","connection_mode"],"value":"stretch_to_fit","reason":"Undeclared connection operation"},
		{"path":["definition_sha256"],"value":"fake","reason":"Changed Definition source"}
	]:
		var broken:Dictionary=expression.duplicate(true)
		var target:Dictionary=broken
		var path:Array=mutation.path
		for index:int in range(path.size()-1):target=target[path[index]]
		target[path[-1]]=mutation.value
		check(not PlainsArtLanguage.expression_errors(broken).is_empty(),str(mutation.reason)+" is actually rejected")
	var moved:Dictionary=expression.duplicate(true)
	moved.ports.exit.position[0]+=1.0
	check(not PlainsArtLanguage.expression_errors(moved).is_empty(),"Art parameters cannot silently change existing gameplay exit")
	var changed_contact:Dictionary=expression.duplicate(true)
	changed_contact.assembly.platforms[0].contact_rect[2]+=1.0
	check(not PlainsArtLanguage.expression_errors(changed_contact).is_empty(),"Art parameters cannot relabel different collision contact as original")
	check(not PlainsArtLanguage.compatibility(expression,moved).get("ok",false),"Neighbor compatibility rejects invalid source ports")
	var altered:=definition.duplicate(true) as PlatformingModuleDefinition
	altered.world_bounds.size.x+=1.0
	check(not PlainsArtLanguage.plan_definition(altered,"fissure_banks","native/changed").get("ok",false),"Unregistered gameplay geometry redesign is refused before embedding")
	check(not PlainsArtLanguage.plan_definition(definition,"repair_masonry","native/wrong_material").get("ok",false),"A registered but wrong construction family cannot relabel recoil banks")
	for key:String in ["structural_role","support_requirement","visual_body_depth","collision_source"]:
		var broken:Dictionary=expression.duplicate(true)
		broken.assembly.platforms[0].erase(key)
		check(not PlainsArtLanguage.expression_errors(broken).is_empty(),"Deleted actual surface construction requirement is rejected: "+key)
	for field:String in ["pieces","joints","root_interface","contact_span"]:
		var broken:Dictionary=expression.duplicate(true)
		broken.assembly.platforms[0].assembly_plan.erase(field)
		check(not PlainsArtLanguage.expression_errors(broken).is_empty(),"Deleted source-owned finite part relation is rejected: "+field)
	check(not PlainsArtLanguage.plan_recipe({"id":"unknown","modules":["plains_missing_module"]},"creek_well","native/unknown").get("ok",false),"Unknown operation never falls through to arbitrary art family")

func generated_floor(width:float,module_id:String="region_connection")->Dictionary:
	var generator:=PlainsRegionGenerator.new()
	var manifest:Dictionary={"nodes":[]}
	var definition:=generator._floor_definition(module_id,Rect2(0.0,18.0,width,32.0))
	generator._add_inline(manifest,"native/generated",Vector2.ZERO,definition)
	return manifest.nodes[0]

func verify_generated_negatives()->void:
	var source:=generated_floor(480.0)
	var expression:=PlainsArtLanguage.plan_generated(source)
	check(expression.get("ok",false) and PlainsArtLanguage.expression_errors(expression,source).is_empty(),"Generated connector art expression is bound to real external node geometry")
	if not expression.get("ok",false):return
	check(PlainsArtLanguage.expression_errors(JSON.parse_string(JSON.stringify(expression)),JSON.parse_string(JSON.stringify(source))).is_empty(),"Generated expression and real source survive independent JSON roundtrip")
	check(not PlainsArtLanguage.expression_errors(expression).is_empty(),"Generated expression cannot self-authorize without external source node")
	var other:=generated_floor(300.0)
	var other_expression:=PlainsArtLanguage.plan_generated(other)
	check(other_expression.get("ok",false) and PlainsArtLanguage.expression_errors(other_expression,other).is_empty(),"Different legitimate generated width uses finite parts")
	check(expression.assembly.platforms[0].assembly_plan.pieces!=other_expression.assembly.platforms[0].assembly_plan.pieces,"Changing real source width changes actual finite assembly rather than a label")
	check(not PlainsArtLanguage.expression_errors(other_expression,source).is_empty(),"Fully self-consistent counterfeit expression is refused against different real source")
	var narrow:=generated_floor(70.0)
	check(PlainsRegionGenerator.definition(narrow).is_valid(),"Narrow art counterexample retains a legal original physical Definition")
	check(not PlainsArtLanguage.plan_generated(narrow).get("ok",false),"Physically legal but unexpressible generated bank is rejected before scene instantiation")
	check(not PlainsArtLanguage.plan_generated(generated_floor(100.25)).get("ok",false),"Generated source cannot hide off-grid artwork length")
	var unknown:Dictionary=source.duplicate(true);unknown.module_id="region_stairs"
	check(not PlainsArtLanguage.plan_generated(unknown).get("ok",false),"Unowned inline structure is not silently reclassified as plain bank")
	var bad_source:Dictionary=source.duplicate(true);bad_source.geometry.platforms="fake"
	check(not PlainsArtLanguage.plan_generated(bad_source).get("ok",false),"Invalid generated geometry input returns explicit refusal")
	var moved:Dictionary=source.duplicate(true);moved.offset[0]+=1.0
	check(not PlainsArtLanguage.expression_errors(expression,moved).is_empty(),"Source relocation invalidates old world attachment expression")

func verify_world(manifest:Dictionary,plan:Dictionary)->void:
	var world:Dictionary=manifest.art_language_world
	check(world.intent.source_order=="topology_recipe_and_art_intent_before_world_coordinates","World art intent is recorded before coordinate embedding")
	check(world.coverage.whole_region_art_admitted==false,"Structural validation never signs whole-region art")
	check(world.finite_landforms.size()>1 and world.open_valleys.size()>0,"Full map expresses multiple finite masses and exterior air")
	for edge:Dictionary in manifest.connections:
		if edge.kind!="horizontal":continue
		check(edge.has("art_language") and edge.art_language.get("ok",false),"Every horizontal recipe was screened for art expression before embedding")
		if not edge.has("art_language"):continue
		for expression:Dictionary in edge.art_language.modules:
			check(PlainsArtLanguage.expression_errors(expression).is_empty(),"Recorded module has exact source-backed finite size and construction")
	var generated_count:=0
	for node:Dictionary in manifest.nodes:
		if node.module_id not in ["region_junction","region_connection"]:continue
		generated_count+=1
		check(node.has("art_expression") and PlainsArtLanguage.expression_errors(node.get("art_expression",{}),node).is_empty(),"Expanded generated junction or connector has source-verified part grammar")
	check(generated_count>0 and manifest.art_language_coverage.unresolved_inline_or_tutorial_node_ids.size()<40,"Tested inline expansion actually reduces unresolved geometry rather than adding unused schema")
	var counterfeit:Dictionary=manifest.duplicate(true)
	for node:Dictionary in counterfeit.nodes:
		if node.module_id not in ["region_junction","region_connection"]:continue
		node.art_expression.source_geometry_hash="counterfeit"
		break
	check(not PlainsRegionArtPlan.compile(counterfeit).get("ok",false),"Actual regional compiler rejects inline expression source forgery")
	var broken:Dictionary=manifest.duplicate(true)
	broken.art_language_world.finite_landforms[0].points=world.open_valleys[0].points.duplicate(true)
	check(not PlainsRegionArtPlan.compile(broken).get("ok",false),"Actual compiler rejects mountain geometry occupying registered exterior air")
	var tight:Dictionary=world.intent.duplicate(true)
	tight.open_valleys[0].minimum_width=1000000.0
	var before_modules:Dictionary=manifest.duplicate(true)
	before_modules.nodes=[]
	before_modules.areas=before_modules.areas.filter(func(area:Dictionary)->bool:return area.has("col") and area.has("row"))
	var source_ids:Array=before_modules.areas.map(func(area:Dictionary)->String:return str(area.id))
	before_modules.connections=before_modules.connections.filter(func(edge:Dictionary)->bool:return str(edge.a) in source_ids and str(edge.b) in source_ids)
	var impossible:=PlainsArtLanguage.resolve_world(tight,before_modules)
	check(not impossible.get("ok",false) and str(impossible.get("error","")).contains("valley width"),"Embedding rejects impossible valley width specifically rather than stretching assets")
	check(PlainsArtLanguage.resolve_world(world.intent,before_modules).get("ok",false),"Original embedded area positions express the same world before instantiation")
	check(not PlainsArtLanguage.plan_world_intent(manifest).get("ok",false),"Cannot backfill world art intent after gameplay nodes exist")
	check(not PlainsArtLanguage.plan_world_intent(before_modules).get("ok",false),"Cannot backfill world art intent after area coordinates exist")
	var before_coordinates:Dictionary=before_modules.duplicate(true)
	for area:Dictionary in before_coordinates.areas:area.position=[0.0,0.0]
	check(PlainsArtLanguage.plan_world_intent(before_coordinates).get("ok",false),"Actual topology and recipe data suffice for art intent before any coordinates")
	check(not PlainsArtLanguage.resolve_world(world.intent,before_coordinates).get("ok",false),"Overlapping column embeddings are rejected before instantiating terrain")
	var missing_column:Dictionary=before_modules.duplicate(true)
	missing_column.areas[0].erase("col")
	check(not PlainsArtLanguage.resolve_world(world.intent,missing_column).get("ok",false),"Missing topology column is an explicit refusal, not native exception")
	check(plan.has("layer_belts") and plan.layer_belts.is_empty(),"Bounded world never consumes old whole-map rectangular painted belts")

func verify_consumer(generated:Dictionary,tuning:PlayerTuning)->Dictionary:
	var stage:=NativeArtStage.new();root.add_child(stage)
	stage.assembler=PlainsRegionAssembler.new();stage.assembler.region_state=PlainsRegionState.new();stage.add_child(stage.assembler)
	var assembled:=stage.assembler.build(generated.manifest,tuning)
	check(assembled.get("ok",false),"Actual original assembler accepts new language Manifest")
	for module:PlatformingModule in stage.assembler.modules:
		for index:int in module.definition.platforms.size():
			var node:=module.get_node_or_null("Platform%d/CollisionShape2D"%index) as CollisionShape2D
			var contact:Rect2=module.definition.platforms[index]
			check(node!=null and node.shape is RectangleShape2D and (node.shape as RectangleShape2D).size==contact.size and module.to_local(node.global_position)==contact.get_center() and not node.disabled,"Art-aware layout preserves actual collision contact of "+str(module.definition.module_id))
	var composer:=PlainsRegionalComposer.new();stage.add_child(composer)
	composer.install(stage,generated.regional_art_plan)
	var facts:=composer.measured_nodes()
	check(facts.get("omitted",[]).is_empty(),"Actual complete regional consumer has no omitted source geometry")
	check(facts.get("art_status","")=="design_debug_not_art_admission","Missing new painted families never acquire art admission")
	var expressions:Dictionary={}
	for item:Dictionary in generated.regional_art_plan.module_art_expressions:expressions[item.node_id]=item.expression
	var binding_count:=0
	for receipt:Dictionary in facts.get("terrain",[]):
		var node:=composer.get_node_or_null(str(receipt.node_path)) as Polygon2D
		check(node!=null,"Existing front projection receipt resolves actual visible polygon")
		check(receipt.asset_status=="legacy_material_probe_pending_family_assets","Bound parameters do not claim new painted parts were instantiated")
		for binding:Dictionary in receipt.get("art_unit_bindings",[]):
			binding_count+=1
			check(expressions.has(binding.node_id) and binding.expression==expressions[binding.node_id],"Actual front consumer retains exact requested family, finite pieces and root interfaces")
			check(binding.source_ids.size()==binding.actual_source_rects.size(),"Actual binding retains source domain ownership")
			for index:int in binding.source_ids.size():
				check(binding.source_ids[index] in receipt.source_ids,"Binding names source owned by this visible projection")
				var raw:Array=binding.actual_source_rects[index]
				var rect:=Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
				var polygon:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
				check(node!=null and not Geometry2D.intersect_polygons(node.polygon,polygon).is_empty(),"Bound source domain genuinely intersects this installed visible mesh chunk")
				var consumed:Dictionary={}
				for domain:Dictionary in binding.get("actual_consumed_domains",[]):
					if domain.source_id==binding.source_ids[index]:consumed=domain
				var actual_clip:Array=[]
				if node!=null:
					for part:PackedVector2Array in Geometry2D.intersect_polygons(node.polygon,polygon):actual_clip.append(arrays(part))
				check(not consumed.is_empty() and consumed.polygons==actual_clip,"Source receipt records actual installed chunk intersection, not remote module labels")
	check(binding_count>0,"Actual front mesh consumes module language rather than leaving it only in Manifest")
	var world:Dictionary=generated.manifest.art_language_world
	check(facts.get("finite_landforms",[]).size()==world.finite_landforms.size(),"All finite source landforms installed, with no extra world wall")
	for body:Dictionary in world.finite_landforms:
		var receipt:Dictionary={}
		for row:Dictionary in facts.get("finite_landforms",[]):
			if row.id==body.id:receipt=row
		check(not receipt.is_empty(),"Source finite landform has actual consumer receipt: "+str(body.id))
		if receipt.is_empty():continue
		var node:=composer.get_node_or_null(str(receipt.node_path)) as Polygon2D
		check(node!=null,"Receipt resolves actual Polygon2D")
		if node==null:continue
		var source:=packed(body.points)
		check(node.polygon==source and receipt.actual_world_points==arrays(source),"Actual installed closed contour is exactly source finite polygon, no appended bottom")
		var uv:=PackedVector2Array()
		for point:Vector2 in source:uv.append(point*float(receipt.pixels_per_world_unit))
		check(node.uv==uv and receipt.actual_uv==arrays(uv),"Actual world UV consumes registered paint density without rectangle stretching")
		check(node.z_index==-30 and node.texture!=null and node.texture.resource_path==str(receipt.source),"Actual rear depth and source texture are bound")
		check(FileAccess.get_sha256(str(receipt.source))==receipt.source_sha256,"Actual paint bytes match consumer source SHA")
		for valley:Dictionary in world.open_valleys:
			check(Geometry2D.intersect_polygons(source,packed(valley.points)).is_empty(),"Actual finite painting keeps source exterior air open")
	stage.queue_free();await process_frame;await process_frame
	return facts

func run()->void:
	var tuning:=PlayerTuning.load_default()
	verify_baselines(tuning)
	verify_language_negatives()
	verify_generated_negatives()
	check(not PlainsRegionArtPlan.generate("invalid_profile",tuning,"intro","",false,"unknown_profile").get("ok",false),"Unknown profile cannot fall back to legacy generation")
	check(not PlainsRegionArtPlan.generate("mixed_profile",tuning,"intro","",true,"bounded_plains_v1").get("ok",false),"Legacy joint profile and new bounded world cannot share ambiguous consumers")
	var rows:Array=[]
	var prior_topologies:Array=[]
	var prior_landforms:Array=[]
	for root_seed:String in ["joint-recoil-01","joint-recoil-07","language-valley-03","language-valley-04"]:
		var seed:=PlainsRegionCampaign.seed_for(root_seed,1)
		var generated:=PlainsRegionArtPlan.generate(seed,tuning,"intro","",false,"bounded_plains_v1")
		check(generated.get("ok",false),root_seed+": actual bounded full-region candidate generation")
		if not generated.get("ok",false):rows.append({"root_seed":root_seed,"generation_failure":generated});continue
		var manifest:Dictionary=generated.manifest
		if rows.is_empty():
			var diagnostic:=FileAccess.open(output_path+".first_full_precision.json",FileAccess.WRITE)
			if diagnostic!=null:diagnostic.store_string(JSON.stringify(RandomStageGenerator.new()._canonical(manifest),"",true,true));diagnostic.close()
			var ordinary_json:=FileAccess.open(output_path+".first_default_json.json",FileAccess.WRITE)
			if ordinary_json!=null:ordinary_json.store_string(JSON.stringify(manifest));ordinary_json.close()
			var canonical_source:=FileAccess.open(output_path+".canonical_source.json",FileAccess.WRITE)
			if canonical_source!=null:canonical_source.store_string(JSON.stringify(RandomStageGenerator.new()._canonical(manifest),"",true));canonical_source.close()
			var canonical_replay:=FileAccess.open(output_path+".canonical_replay.json",FileAccess.WRITE)
			if canonical_replay!=null:canonical_replay.store_string(JSON.stringify(RandomStageGenerator.new()._canonical(JSON.parse_string(JSON.stringify(manifest))),"",true));canonical_replay.close()
		check(PlainsRegionGenerator.new().validate(JSON.parse_string(JSON.stringify(manifest)),tuning),"New Manifest has real JSON replay validation")
		check(PlainsRegionArtPlan.validate_recorded(JSON.parse_string(JSON.stringify(generated.regional_art_plan)),manifest),"Companion plan has real source-bound JSON replay validation")
		verify_world(manifest,generated.regional_art_plan)
		var embedding_counterfactual:Dictionary={}
		if root_seed in PRIOR_MANIFESTS:embedding_counterfactual=verify_embedding_counterfactual(manifest)
		var topology:Array=manifest.connections.map(func(edge:Dictionary)->Array:return [edge.a,edge.b,edge.kind])
		if topology not in prior_topologies:prior_topologies.append(topology)
		var shapes:Array=manifest.art_language_world.finite_landforms.map(func(body:Dictionary)->Array:return body.points)
		if shapes not in prior_landforms:prior_landforms.append(shapes)
		var facts:Dictionary=await verify_consumer(generated,tuning)
		rows.append({"root_seed":root_seed,"manifest":manifest,"plan":generated.regional_art_plan,"actual_consumer":facts,"embedding_counterfactual":embedding_counterfactual})
	check(prior_topologies.size()>1,"Preregistered Seed sample changes actual area connectivity, not only phases or labels")
	check(prior_landforms.size()>1,"Preregistered Seed sample changes actual finite mass polygons, not only hashes")
	var file:=FileAccess.open(output_path,FileAccess.WRITE)
	if file==null:check(false,"Can preserve original native evidence")
	else:file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"actual":rows})+"\n");file.close()
	print("PLAINS ART LANGUAGE: %d assertions, %d failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
