extends SceneTree
## Actual default formal consumers; no substitute renderer or forged callbacks.
var checks := 0
var failures: Array[String] = []
var inventory: Array[Dictionary] = []
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
	var tuning_hash:=FileAccess.get_sha256("res://config/player_tuning.json")
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_plains("underworld-formal-integrated"),"ordinary formal entry accepted")
	for frame:int in 8:await physics_frame
	for map_index:int in [1,2]:
		if map_index==2:
			app.director.stage_index=2;app._load_stage()
			for frame:int in 8:await physics_frame
		var stage:=app.stage as PlainsRegionStage
		check(stage!=null and stage.assembly_ok,"formal map assembles")
		check(UnderworldActors.enabled(stage),"formal style bound before module ready")
		check(stage.terrain_art.art is UnderworldTerrain,"real default terrain")
		check(app.player.get_node("PixelPlainsActor") is UnderworldPlayer,"real player visual replacement")
		var bg:=app.get_node("PixelPlainsParallax") as UnderworldParallax
		check(bg!=null and bg.measured_nodes().size()==3,"actual compatible parallax consumer")
		var scene:=stage.get_node("PixelRegionScenery") as UnderworldScenery
		check(scene!=null,"formal decor consumer exists")
		check(scene.find_children("*","CollisionObject2D",true,false).is_empty(),"decor owns no hidden solid/damage objects")
		var atlas:Dictionary={}
		for row:Dictionary in bg.measured_nodes():atlas[row.texture_path]=true
		check(atlas.size()==3,"three genuinely distinct consumed sources")
		var kinds:Dictionary={}
		for enemy:EnemyMotor in stage.enemies:
			check(enemy.get_node("Presentation") is UnderworldEnemy,"every actual enemy gets matching skin")
			var actor:=enemy.get_node("Actor") as EnemyActor
			kinds[String(actor.definition.behavior_id)]=true
		var pickups:=0
		for child:Node in stage.get_children():
			if child is PlainsStageVisual:
				check(child._texture(&"coin")==UnderworldActors.icon_texture(&"coin"),"actual coin resource consumer")
				check(child._texture(&"heart")==UnderworldActors.icon_texture(&"heart"),"actual heart resource consumer")
				check(child._texture(&"door")==UnderworldActors.icon_texture(&"door"),"actual exit resource consumer")
				pickups+=1
		check(pickups==1,"single pickup visual layer")
		for chest:Dictionary in stage.chests:
			check(chest.sprite.texture==UnderworldActors.icon_texture(&"chest"),"actual reward chest no longer old flat placeholder")
		var old_manifest:=JSON.stringify(stage.generated.manifest)
		var old_actor_epoch:=app.lifetime.actor_epoch
		var old_stage_epoch:=app.lifetime.stage_epoch
		app.toggle_pause()
		check(paused,"normal pause enters")
		app.toggle_pause()
		check(not paused,"normal pause exits")
		check(old_manifest==JSON.stringify(stage.generated.manifest),"pause/cosmetics never alter generation")
		check(old_actor_epoch==app.lifetime.actor_epoch and old_stage_epoch==app.lifetime.stage_epoch,"presentation/pause retains current lifecycle")
		inventory.append({"map":map_index,"manifest_hash":stage.generated.manifest.manifest_hash,"enemy_behaviors":kinds.keys(),"enemies":stage.enemies.size(),"chests":stage.chests.size(),"decor":scene.placements.size(),"tilemap_cells":(stage.terrain_art.art as UnderworldTerrain).core_cells.size(),"backgrounds":bg.measured_nodes(),"scope":"actual consumers and lifecycle, not complete human traversal or commercial animation"})
	check(tuning_hash==FileAccess.get_sha256("res://config/player_tuning.json"),"unique physics source unchanged")
	app.abandon_run()
	check(await load("res://tests/audio_teardown.gd").drain_world(app),"complete consumer teardown drains audio")
	app.free()
	for frame:int in 6:await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/underworld_plains")
	FileAccess.open("res://build/underworld_plains/formal_integration.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"inventory":inventory},"  "))
	print("UNDERWORLD_FORMAL checks=%d failures=%d maps=2"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
