extends SceneTree
## Actual default formal consumers; no substitute renderer or forged callbacks.
var checks := 0
var failures: Array[String] = []
var inventory: Array[Dictionary] = []
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func opaque_height(texture: Texture2D, region: Rect2i = Rect2i()) -> int:
	var image := texture.get_image()
	if image == null: return 0
	if region.size == Vector2i.ZERO: region = Rect2i(Vector2i.ZERO,image.get_size())
	var top := region.end.y
	var bottom := region.position.y-1
	for y: int in range(region.position.y,region.end.y):
		for x: int in range(region.position.x,region.end.x):
			if image.get_pixel(x,y).a >= .5:
				top=mini(top,y);bottom=maxi(bottom,y)
	return maxi(0,bottom-top+1)
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
		var player_art := app.player.get_node("PixelPlainsActor") as UnderworldPlayer
		var merchant := stage.get_node_or_null("UnderworldMerchant") as Sprite2D
		check(merchant != null and merchant.texture==UnderworldActors.icon_texture(&"merchant"),"actual formal merchant consumes the matching human image")
		if merchant != null:
			var idle: Dictionary = player_art._frames_by_state.idle[0]
			var r: Array = idle.rect
			var idle_pixels := opaque_height(UnderworldPlayer.STATES_SHEET,Rect2i(r[0],r[1],r[2],r[3]))
			check(is_equal_approx(float(idle_pixels),float(player_art._build.standing_body_source_height)),"actual opaque standing frame agrees with the human scale calibration")
			var player_height := idle_pixels*UnderworldActors.HUMANOID_HEIGHT/float(player_art._build.standing_body_source_height)
			var merchant_height := opaque_height(merchant.texture)*absf(merchant.global_scale.y)
			check(absf(merchant_height-player_height)<1.0,"actual merchant and courier standing bodies have matching world stature")
			check(is_equal_approx(merchant.scale.x,merchant.scale.y),"merchant source aspect ratio is preserved")
			var merchant_bounds := merchant.global_transform*merchant.get_rect()
			var foot := Vector2(merchant_bounds.get_center().x,merchant_bounds.end.y)
			check(foot.is_equal_approx(stage.merchant_position+Vector2(0,18)),"actual merchant feet remain at the unchanged interaction ground anchor")
			var hit := stage.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(foot-Vector2(0,1),foot+Vector2(0,3),1))
			check(not hit.is_empty() and hit.collider is StaticBody2D,"merchant foot is supported by real formal terrain")
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
