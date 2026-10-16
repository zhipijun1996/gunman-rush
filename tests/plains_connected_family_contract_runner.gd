extends SceneTree
## Actual family consumer counterexamples; no aesthetic or traversal verdict.
var assertions:=0
var failures:=0
var output:="res://build/production_repair/art/family_contract_01.json"
func _initialize()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run.call_deferred()
func check(value:bool,label:String)->void:
	assertions+=1
	if not value:failures+=1;printerr("CONNECTED FAMILY FAIL: ",label)
func wait_stage(app:DemoApp)->void:
	for unused:int in 120:
		await physics_frame;await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage:return
func run()->void:
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_plains("v3-root-bell-pilot-1"),"actual formal root starts")
	await wait_stage(app)
	app.lifetime.stage_epoch+=1;app.lifetime.actor_epoch+=1;app.director._enter_stage(2,&"boss");app._stage_entered(DemoRunResult.new());await wait_stage(app)
	for unused:int in 3:await process_frame
	var stage:=app.stage as PlainsRegionStage
	var manifest:=JSON.stringify(stage.generated.manifest)
	var consumer:=stage.find_child("ConnectedLandscape",true,false) as PlainsConnectedLandscape
	check(consumer!=null,"real formal scene owns connected family consumer")
	if consumer!=null:
		check(consumer._plant_nodes.size()>=2,"actual original rooted tree family produces two formal plants")
		check(consumer.actual_issues().is_empty(),"actual complete source/root/world/depth invariants clean: "+str(consumer.actual_issues()))
		for row:Dictionary in consumer.entries:
			if row.kind!="rooted_plant":continue
			var bounds:=PlainsSemanticLandscape.values_rect(row.world_bounds)
			check(not consumer._hard_protected.any(func(r:Rect2)->bool:return r.intersects(bounds)),"actual plant preserves live danger and encounter clearances")
			check(not row.actual_root_support_members.is_empty(),"complete root fan names actual static support bodies")
		if not consumer._plant_nodes.is_empty():
			var item:Dictionary=consumer._plant_nodes[0];var sprite:Sprite2D=item.sprite
			var position:=sprite.global_position;sprite.global_position.y-=40
			check("plant_root_collar_detached" in consumer.actual_issues(),"actual floating-root counterexample rejected");sprite.global_position=position
			var scale_value:=sprite.scale;sprite.scale.x*=1.3
			check("plant_source_stretched_or_enlarged" in consumer.actual_issues(),"actual stretched original painting rejected");sprite.scale=scale_value
			var atlas:=sprite.texture as AtlasTexture;var region:=atlas.region;atlas.region=region.grow(8)
			check("plant_source_region_or_filter_changed" in consumer.actual_issues(),"neighbor intrusion counterexample rejected");atlas.region=region
			var support:Dictionary=item.supports[0];var body:=consumer.get_node(str(support.node_path)) as Node2D;var prior:=body.position;body.position.y+=10
			check("plant_actual_root_support_changed" in consumer.actual_issues(),"changed actual foundation counterexample rejected");body.position=prior
			check(consumer.actual_issues().is_empty(),"restored actual consumer clean")
		check(JSON.stringify(stage.generated.manifest)==manifest,"family presentation leaves exact formal Manifest unchanged")
	var sources:Array[Dictionary]=[{"bounds":Rect2(0,100,200,32)}]
	var opaque:=Rect2(10,10,80,90);var anchor:=Vector2(50,90)
	var original:=PlainsConnectedLandscape.plan_rooted_plant(sources,[],100,100,opaque,anchor,1)
	var shifted_sources:Array[Dictionary]=[{"bounds":Rect2(320,-140,200,32)}]
	var shifted:=PlainsConnectedLandscape.plan_rooted_plant(shifted_sources,[],420,-140,opaque,anchor,1)
	check((shifted.foot as Vector2).is_equal_approx((original.foot as Vector2)+Vector2(320,-240)),"placement derives translated actual geometry rather than seed coordinates")
	var blocked:Array[Rect2]=[Rect2(0,0,200,200)]
	check(PlainsConnectedLandscape.plan_rooted_plant(sources,blocked,100,100,opaque,anchor,1).is_empty(),"fully blocked ground is omitted rather than force planted")
	var measured:Dictionary=consumer.measured_nodes() if consumer!=null else {}
	var audio:=get_first_node_in_group(&"game_audio") as GameAudio
	check(audio!=null and await audio.shutdown(),"actual audio thread drained before fixture exit")
	app.free();app=null
	for unused:int in 3:await physics_frame;await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir());var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"consumer":measured,"scope":"Actual formal consumer invariants and mutated real Nodes; no traversal/pixels/aesthetic/device acceptance."})+"\n");file.close()
	print("CONNECTED FAMILY CONTRACT: %s assertions, %s failures"%[assertions,failures]);quit(0 if failures==0 else 1)
