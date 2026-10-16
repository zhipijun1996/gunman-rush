extends SceneTree
## Real consumers; static camera/actor poses below are explicitly composition fixtures, not route traversal.
var assertions:=0
var failures:=0
var output:=""
var rows:Array[Dictionary]=[]
var pixels:Array[Dictionary]=[]
func _initialize()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run.call_deferred()
func check(ok:bool,label:String)->void:
	assertions+=1
	if not ok:failures+=1;printerr("TERRAIN FAMILY FAIL: ",label)
func wait_stage(app:DemoApp)->void:
	for unused:int in 120:
		await physics_frame;await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage:return
func rect_values(rect:Rect2)->Array:return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func pair(p:Vector2)->Array:return [p.x,p.y]
func check_live(app:DemoApp,seed_value:String,map_index:int,thorough:bool)->void:
	var stage:=app.stage as PlainsRegionStage
	var manifest:=JSON.stringify(stage.generated.manifest)
	var art:=stage.terrain_art.art
	check(art.has_meta("family_entries"),"actual default has family composite")
	var entries:Array=art.get_meta("family_entries",[])
	var data:=PlainsTerrainFamilySampler.inventory(stage)
	check(not entries.is_empty(),"actual representative source is consumed")
	var has_panel_form:bool=data.floating.any(func(f:Dictionary)->bool:return f.rect.size==Vector2(24,110))
	if seed_value=="level-design-v2-baseline/08":check(entries.any(func(e:Dictionary)->bool:return e.kind=="suspended_panel"),"actual suspended24x110 consumer is covered on representative map")
	check(entries.any(func(e:Dictionary)->bool:return e.kind=="suspended_panel")==has_panel_form,"matching real panel form consumed; absent form remains baseline without invented24x110")
	check(entries.filter(func(e:Dictionary)->bool:return e.kind=="rooted_union").size()<=1,"unreviewed whole-region bank promotion remains off")
	check(PlainsTerrainFamilySampler.actual_issues(art).is_empty(),"actual source/contract/Atlas/standing-root diagnostics pass")
	var count:=0
	for module:PlatformingModule in stage.assembler.modules:count+=module.definition.platforms.size()
	check(data.rooted.size()-data.columns.size()+data.floating.size()+data.one_way.size()==count,"every actual platform classified exactly once")
	check(int(art.get_meta("one_way_baseline_count"))==data.one_way.size(),"all one-way retain real wood consumer")
	var measured:Array=[]
	for e:Dictionary in entries:
		var row:Dictionary={"kind":e.kind,"bounds":rect_values(e.bounds),"source":e.source,"source_sha256":e.source_sha256,"uniform_scale":e.uniform_scale}
		if e.kind=="rooted_union":
			check(e.parts.any(func(r:Rect2)->bool:return r in data.columns),"new bank actually attaches to generated solid foundation")
			var order:Array[Rect2]=e.parts.duplicate();order.reverse()
			check(PlainsTerrainFamilySampler.boundary(order)==e.faces,"same union input order independent")
			var split:Array[Rect2]=[]
			for r:Rect2 in e.parts:
				split.append(Rect2(r.position,Vector2(r.size.x/2,r.size.y)))
				split.append(Rect2(r.position+Vector2(r.size.x/2,0),Vector2(r.size.x/2,r.size.y)))
			check(PlainsTerrainFamilySampler.boundary(split)==e.faces,"same union repartition independent")
			row["faces"]=Array(e.faces).map(func(v:Vector4)->Array:return [v.x,v.y,v.z,v.w])
		else:
			check(data.floating.any(func(f:Dictionary)->bool:return f.rect==e.bounds),"new suspended panel attaches actual floating solid")
			check(e.bounds.size==Vector2(24,110),"panel keeps actual physical size")
			var gap:=INF
			for r:Rect2 in data.rooted:
				if r.position.x<=e.bounds.get_center().x and r.end.x>=e.bounds.get_center().x and r.position.y>=e.bounds.end.y:gap=minf(gap,r.position.y-e.bounds.end.y)
			row["actual_below_gap_world"]=gap
			check(gap>=3,"panel bottom cannot bridge actual below gap")
		measured.append(row)
	if thorough:
		for child:Node in art.get_children():
			if child is ColorRect and child.has_meta("expected_face_count"):
				var mat:=child.material as ShaderMaterial
				mat.set_shader_parameter("family_paint",PlainsTileComposer.PAINT)
				check("actual_family_texture_changed" in PlainsTerrainFamilySampler.actual_issues(art),"actual wrong source rejected")
				mat.set_shader_parameter("family_paint",PlainsTerrainFamilySampler.CLIFF)
				var faces:int=mat.get_shader_parameter("face_count");mat.set_shader_parameter("face_count",0)
				check("actual_union_boundaries_changed" in PlainsTerrainFamilySampler.actual_issues(art),"actual standing/boundary removal rejected")
				mat.set_shader_parameter("face_count",faces);break
		for child:Node in art.get_children():
			if not child.name.begins_with("SampledSuspendedStoneCopper"):continue
			var sprite:=child.get_child(0) as Sprite2D
			var atlas:=sprite.texture as AtlasTexture
			var source:=atlas.region;atlas.region.position.y-=16
			check("actual_panel_source_region_changed" in PlainsTerrainFamilySampler.actual_issues(art),"actual forbidden top source rejected")
			atlas.region=source;atlas.filter_clip=false
			check("actual_panel_atlas_unclipped" in PlainsTerrainFamilySampler.actual_issues(art),"actual unclipped sampler rejected")
			atlas.filter_clip=true;sprite.scale.x*=1.1
			check("actual_panel_scale_changed" in PlainsTerrainFamilySampler.actual_issues(art),"actual anisotropic scale rejected")
			sprite.scale=Vector2.ONE/9.0;child.position.y+=50
			check("actual_panel_detached_or_gap_fill" in PlainsTerrainFamilySampler.actual_issues(art),"actual panel fills50gap counterexample rejected")
			child.position.y-=50
	check(PlainsTerrainFamilySampler.actual_issues(art).is_empty(),"live negative mutations restored")
	check(JSON.stringify(stage.generated.manifest)==manifest,"presentation and tests preserve actual Manifest")
	rows.append({"seed":seed_value,"map_index":map_index,"manifest_hash":stage.generated.manifest.manifest_hash,"serialized_manifest_sha256":manifest.sha256_text(),"actual_entries":measured,"actual_rooted_rectangles":data.rooted.size(),"actual_floating_count":data.floating.size(),"actual_one_way_count":data.one_way.size(),"omissions":art.get_meta("family_omitted",[]).map(func(e:Dictionary)->Dictionary:return {"kind":e.kind,"bounds":rect_values(e.bounds),"reason":e.reason})})
func golden(app:DemoApp)->void:
	var stage:=app.stage as PlainsRegionStage
	var art:=stage.terrain_art.art
	var original:=PlainsTileComposer.build_rectangles(stage.terrain_art.collect_solids())
	original.z_index=-1;stage.terrain_art.add_child(original);original.visible=false
	var entries:Array=art.get_meta("family_entries",[])
	for e:Dictionary in entries:
		var position:Vector2
		if e.kind=="rooted_union":
			var best:=INF
			for edge:Vector4 in e.faces:
				if edge.z<=edge.x:continue
				var candidate:=Vector2((edge.x+edge.z)/2,edge.y)
				if candidate.distance_to(e.bounds.position)<best:position=candidate;best=candidate.distance_to(e.bounds.position)
		else:
			position=e.bounds.position+Vector2(-52,e.bounds.size.y+50)
		# Explicit static visual fixture. No traversal/route/ability completion claim.
		app.player.reset_at(position-Vector2(0,24))
		for unused:int in 36:await physics_frame;await process_frame
		paused=true
		for unused:int in 2:await process_frame
		var camera:=root.get_camera_2d()
		var snapshot:Dictionary={"kind":e.kind,"source_rect":rect_values(e.bounds),"actor_actual_position":pair(app.player.global_position),"camera_actual_position":pair(camera.global_position),"camera_zoom":pair(camera.zoom),"scope":"Actual formal scene, static actor reset fixture; native camera follows actual actor, not route traversal"}
		for variant:String in ["baseline","candidate"]:
			art.visible=variant=="candidate";original.visible=variant=="baseline"
			await RenderingServer.frame_post_draw
			var file:=output.get_base_dir()+"/"+str(e.kind)+"_"+variant+".png"
			check(root.get_texture().get_image().save_png(file)==OK,"actual GPU image saved")
			snapshot[variant]=file
		pixels.append(snapshot)
		original.visible=false;art.visible=true;paused=false
	original.free()
func run()->void:
	root.size=Vector2i(1280,720)
	var seeds:Array[String]=["level-design-v2-baseline/08"]
	if "--all-maps" in OS.get_cmdline_user_args():
		seeds=["level-design-v2-baseline","level-design-v2-baseline/01","level-design-v2-baseline/02","level-design-v2-baseline/03","level-design-v2-baseline/04","level-design-v2-baseline/05","level-design-v2-baseline/06","level-design-v2-baseline/07","level-design-v2-baseline/08","level-design-v2-baseline/09"]
	for seed_value:String in seeds:
		var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
		check(app.start_plains(seed_value),"real formal map starts");await wait_stage(app)
		check_live(app,seed_value,1,true)
		app.lifetime.stage_epoch+=1;app.lifetime.actor_epoch+=1;app.director._enter_stage(2,&"boss");app._stage_entered(DemoRunResult.new());await wait_stage(app)
		check_live(app,seed_value,2,true)
		if "--gpu" in OS.get_cmdline_user_args():await golden(app)
		if not "--prove-skip-drain" in OS.get_cmdline_user_args():
			var audio := get_first_node_in_group(&"game_audio") as GameAudio
			check(audio != null and await audio.shutdown(), "audio playback actually releases before host exit")
		app.free();app=null
		for unused:int in 3:await physics_frame;await process_frame
	if "--prove-failure" in OS.get_cmdline_user_args():check(false,"intentional harness guard rejection")
	var report:Dictionary={"assertions":assertions,"failures":failures,"rows":rows,"gpu_static_fixtures":pixels,"scope":"Actual source consumer/union semantics/negative diagnostics; static fixture pixels never traversal or commercial art acceptance"}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir());var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report)+"\n");file.close()
	print("TERRAIN FAMILY: %s assertions, %s failures"%[assertions,failures]);quit(0 if failures==0 else 1)
