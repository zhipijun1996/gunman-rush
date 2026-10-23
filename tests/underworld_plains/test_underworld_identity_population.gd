extends SceneTree
## Actual 10 root seeds x both formal maps; no fake inventory rows.
var checks := 0
var failures := 0
var rows: Array[Dictionary] = []
var audio_observations: Array[Dictionary] = []

func live_playbacks(references: Array[WeakRef]) -> int:
	var count := 0
	for reference: WeakRef in references:
		if reference.get_ref()!=null:count+=1
	return count

func borrow_owned_playback(world: Node) -> AudioStreamPlayback:
	for service: Node in get_nodes_in_group(&"game_audio"):
		if not world.is_ancestor_of(service):continue
		for voice: AudioStreamPlayer in service.find_children("*","AudioStreamPlayer",true,false):
			if voice.has_stream_playback():return voice.get_stream_playback()
		# A real existing service/real clip is used only by the refusal probe.
		service.call("play",&"confirm")
		for voice: AudioStreamPlayer in service.find_children("*","AudioStreamPlayer",true,false):
			if voice.has_stream_playback():return voice.get_stream_playback()
	return null
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: "+label)
func run() -> void:
	var map_hashes: Dictionary = {}
	var scenery_spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(UnderworldScenery.BUILD_PATH)).decor
	var source_regions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://"+str(scenery_spec.regions_metadata))).regions
	for number: int in 10:
		for map_index: int in [1,2]:
			var seed_text := "underworld-formal/"+str(number)
			var app := DemoApp.new()
			app.meta_persistence_enabled=false
			root.add_child(app)
			await process_frame
			app.start_plains(seed_text)
			if map_index==2:
				app.director.stage_index=2;app.director.region_map_index=2
				app._load_stage()
			for n: int in 3: await physics_frame
			var stage := app.stage as PlainsRegionStage
			check(stage.map_index == map_index and app.director.region_map_index == map_index and str(stage.generated.manifest.seed) == PlainsRegionCampaign.seed_for(app.director.seed,map_index) and str(stage.generated.manifest.manifest_hash).length() == 64,"actual formal map, derived seed and hash match the requested consumer")
			var actual_hash := str(stage.generated.manifest.manifest_hash)
			check(not map_hashes.has(actual_hash),"requested formal map owns a distinct actual Manifest hash")
			map_hashes[actual_hash] = true
			check(stage!=null and stage.assembly_ok,seed_text+" map"+str(map_index)+" actual assembly")
			var scenery := stage.get_node("PixelRegionScenery") as UnderworldScenery
			var actual_identities: Array[String] = []
			var rays: Array[Dictionary] = []
			for sprite: Node in scenery.get_children():
				if not sprite is Sprite2D or not sprite.has_meta("landmark"): continue
				var item: Dictionary=sprite.get_meta("landmark")
				actual_identities.append(str(item.identity))
				var actual := Rect2(sprite.global_position,sprite.texture.get_size()*sprite.global_scale)
				var b: Array=item.display_bounds
				check(actual.is_equal_approx(Rect2(b[0],b[1],b[2],b[3])),"actual grounded node equals metadata")
				# The last visible source row is now shallowly planted in soil.
				# Derive it from the actual Sprite transform and original asset
				# region, then find the real surface above that rendered base.
				# AABB.end can be inside the ground and is not the support line.
				var source: Dictionary=source_regions[str(item.asset_id)]
				var render_foot: Vector2=(sprite as Sprite2D).to_global(Vector2(source.foot[0],source.foot[1]))
				var hit := app.player.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(render_foot-Vector2(0,12),render_foot+Vector2(0,3),1))
				var valid := not hit.is_empty() and hit.collider is StaticBody2D
				check(valid,"actual source-root ray reaches static solid above planted render base")
				if valid:
					var surface: Vector2=hit.position
					var inset:=render_foot.y-surface.y
					check(inset>=0.0 and inset<=8.0,"render base stays within one-quarter tile of the real surface, never floating or deeply buried")
					check(absf(surface.y-float(item.foot[1]))<.01,"independent collision hit matches unchanged logical support foot")
					var recorded_render: Array=item.render_root
					check(render_foot.is_equal_approx(Vector2(recorded_render[0],recorded_render[1])),"recorded render root matches real source transform")
					for edge_x: float in [actual.position.x+1,actual.end.x-1]:
						var support_hit:=app.player.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(edge_x,surface.y-1),Vector2(edge_x,surface.y+3),1))
						check(not support_hit.is_empty() and support_hit.collider is StaticBody2D,"both actual display-span ends have static support")
					rays.append({"identity":item.identity,"hit_static":valid,"height":actual.size.y,"render_foot":[render_foot.x,render_foot.y],"surface_foot":[surface.x,surface.y],"visible_base_inset_wu":inset})
				else:rays.append({"identity":item.identity,"hit_static":false,"height":actual.size.y})
				for keepout: Rect2 in scenery.protected_regions:check(not actual.grow(8).intersects(keepout),"actual foreground retains whole keepout")
			var local := scenery.get_node_or_null("PlainsRegionComposition") as UnderworldLocalComposition
			if local!=null:
				check(local.actual_issues().is_empty(),"actual local backdrop remains low contrast and nonphysical")
				for item: Dictionary in local.compositions:
					check(local.has_node(str(item.node)),"local composition row has actual sprite")
					actual_identities.append(str(item.identity))
			for identity: String in ["windmill_plateau","clock_court","repair_gallery","creek_well"]:
				check(identity in actual_identities,seed_text+" map"+str(map_index)+" actual "+identity)
			rows.append({"seed":seed_text,"map":map_index,"manifest_hash":stage.generated.manifest.manifest_hash,"identities":actual_identities,"grounded_items":scenery.identity_items.duplicate(true),"grounded_rays":rays,"local_compositions":local.compositions.duplicate(true) if local!=null else [],"identity_omissions":scenery.omitted.filter(func(x:Dictionary)->bool:return x.has("identity")),"local_omissions":local.omitted.duplicate(true) if local!=null else []})
			var held: AudioStreamPlayback
			if "--retain-owned-audio" in OS.get_cmdline_user_args() and number==9 and map_index==2:
				held=borrow_owned_playback(app)
				if held==null:check(false,"refusal probe acquires actual world-owned playback")
			var pending: Array[WeakRef] = []
			var owners: Array[Dictionary] = []
			for service: Node in get_nodes_in_group(&"game_audio"):
				if not app.is_ancestor_of(service):continue
				pending.append_array(service.get("_playbacks"))
				owners.append({"node":str(service.get_path()),"script":service.get_script().resource_path,"played":service.get("played").duplicate(true)})
			var pending_before := live_playbacks(pending)
			var borrowed := held!=null
			var released: bool=await load("res://tests/audio_teardown.gd").drain_world(app)
			check(released,"actual owned audio releases before freeing population world")
			var pending_after := live_playbacks(pending)
			var recovered := true
			if held!=null:
				held=null
				recovered=await load("res://tests/audio_teardown.gd").drain_world(app)
				if not recovered:check(false,"actual borrowed playback releases after refusal probe")
			audio_observations.append({"seed":seed_text,"map":map_index,"owners":owners,"pending_before":pending_before,"pending_after":pending_after,"released":released,"borrowed_for_refusal_probe":borrowed,"recovered_after_borrower_release":recovered})
			app.free()
			for n: int in 4: await process_frame
	var file := FileAccess.open("res://build/underworld_plains/identity_population.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":"underworld-formal-identity-population-v1","checks":checks,"failures":failures,"cases":rows,"audio_observations":audio_observations},"\t"))
	file.close()
	print("Underworld identity population: %d cases, %d checks, %d failures" % [rows.size(),checks,failures])
	quit(1 if failures else 0)
