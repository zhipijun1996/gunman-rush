extends SceneTree
## Actual 10 root seeds x both formal maps; no fake inventory rows.
var checks := 0
var failures := 0
var rows: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: "+label)
func run() -> void:
	for number: int in 10:
		for map_index: int in [1,2]:
			var seed_text := "underworld-formal/"+str(number)
			var app := DemoApp.new()
			app.meta_persistence_enabled=false
			root.add_child(app)
			await process_frame
			app.start_plains(seed_text)
			if map_index==2:
				app.director.stage_index=2
				app._load_stage()
			for n: int in 3: await physics_frame
			var stage := app.stage as PlainsRegionStage
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
				var foot := Vector2(actual.get_center().x,actual.end.y)
				var hit := app.player.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(foot-Vector2(0,1),foot+Vector2(0,3),1))
				var valid := not hit.is_empty() and hit.collider is StaticBody2D
				check(valid,"actual grounded bottom-center ray reaches static solid")
				rays.append({"identity":item.identity,"hit_static":valid,"height":actual.size.y})
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
			app.free()
			for n: int in 4: await process_frame
	var file := FileAccess.open("res://build/underworld_plains/independent_review/formal_inventory_e/identity_population.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":"underworld-formal-identity-population-v1","checks":checks,"failures":failures,"cases":rows},"\t"))
	file.close()
	print("Underworld identity population: %d cases, %d checks, %d failures" % [rows.size(),checks,failures])
	quit(1 if failures else 0)
