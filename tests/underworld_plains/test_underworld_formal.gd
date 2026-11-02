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
	var map_hashes: Dictionary = {}
	var tuning_hash:=FileAccess.get_sha256("res://config/player_tuning.json")
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_plains("underworld-formal-integrated"),"ordinary formal entry accepted")
	for frame:int in 8:await physics_frame
	for map_index:int in [1,2]:
		if map_index==2:
			app.director.stage_index=2;app.director.region_map_index=2;app._load_stage()
			for frame:int in 8:await physics_frame
		var stage:=app.stage as PlainsRegionStage
		check(stage.map_index == map_index and app.director.region_map_index == map_index and str(stage.generated.manifest.seed) == PlainsRegionCampaign.seed_for(app.director.seed,map_index) and str(stage.generated.manifest.manifest_hash).length() == 64,"actual formal map, derived seed and hash match the requested consumer")
		var actual_hash := str(stage.generated.manifest.manifest_hash)
		check(not map_hashes.has(actual_hash),"requested formal map owns a distinct actual Manifest hash")
		map_hashes[actual_hash] = true
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
			check(foot.is_equal_approx(stage.merchant_position+Vector2(0,18)),"actual merchant feet remain at the unchanged interaction ground anchor actual=%s expected=%s"%[foot,stage.merchant_position+Vector2(0,18)])
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
			var expected: AtlasTexture=ChestArtLibrary.texture(StringName(str(chest.tier)),bool(chest.claimed))
			check(expected!=null and chest.sprite.texture==expected and chest.sprite.has_meta("underworld_chest_open") and bool(chest.sprite.get_meta("underworld_chest_open"))==bool(chest.claimed) and chest.sprite.modulate==Color.WHITE and chest.sprite.position==chest.position+Vector2(0,21),"actual reward chest uses its tier and claimed recipe at the unchanged world foot")
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
	await deferred_presentation_contract(app)
	check(tuning_hash==FileAccess.get_sha256("res://config/player_tuning.json"),"unique physics source unchanged")
	app.abandon_run()
	check(await load("res://tests/audio_teardown.gd").drain_world(app),"complete consumer teardown drains audio")
	app.free()
	for frame:int in 6:await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/underworld_plains")
	FileAccess.open("res://build/underworld_plains/formal_integration.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"inventory":inventory},"  "))
	print("UNDERWORLD_FORMAL checks=%d failures=%d maps=2"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func deferred_presentation_contract(app: DemoApp) -> void:
	var stage: Node=app.stage
	var presentation:=stage.get_node("FineWorldPresentation") as UnderworldPresentation
	check(presentation!=null,"actual formal presentation owns deferred additions")
	if presentation==null:return
	var other:=Node2D.new();root.add_child(other)
	var live:=Sprite2D.new();stage.add_child(live)
	check(live.material==null,"late live node retains deferred installation timing")
	var retired:=Sprite2D.new();stage.add_child(retired)
	var retired_id:=retired.get_instance_id()
	retired.free()
	var foreign:=Sprite2D.new();other.add_child(foreign)
	var moved:=Sprite2D.new();stage.add_child(moved);moved.reparent(other)
	await process_frame
	check(live.material==presentation._sprite_material,"live late sprite receives original formal material")
	check(not presentation._seen.has(retired_id),"freed pending node never enters typed installer")
	check(foreign.material==null and moved.material==null,"foreign and moved-out nodes are not installed by original world")
	var previous_context:=Sprite2D.new();stage.add_child(previous_context)
	previous_context.reparent(other)
	presentation.world=other
	var current_context:=Sprite2D.new();other.add_child(current_context)
	await process_frame
	check(previous_context.material==null,"old queued context cannot install after world replacement even when node is now in new world")
	check(current_context.material==presentation._sprite_material,"new current world additions still install normally")
	var disappearing:=Sprite2D.new();other.add_child(disappearing)
	var disappearing_id:=disappearing.get_instance_id()
	other.free()
	await process_frame
	check(not presentation._seen.has(disappearing_id),"freed world and pending child drain without typed-object calls")
	presentation.world=stage
	live.free()
