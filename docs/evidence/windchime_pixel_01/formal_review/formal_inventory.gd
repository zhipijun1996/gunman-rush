extends SceneTree
var checks:=0
var failures:Array[String]=[]
var observations:Array[Dictionary]=[]
var app:DemoApp
func _init() -> void:_run.call_deferred()
func check(ok:bool,msg:String)->void:
	checks+=1
	if not ok:failures.append(msg);printerr("FAIL: "+msg)
func frames(n:int)->void:
	for i:int in n:await physics_frame
func walk_nodes(node:Node,rows:Array)->void:
	if node is Sprite2D:
		var sprite:=node as Sprite2D
		if sprite.texture!=null: rows.append({"path":str(sprite.get_path()),"texture":sprite.texture.resource_path,"visible":sprite.is_visible_in_tree()})
	for child:Node in node.get_children():walk_nodes(child,rows)
func inspect_stage(label:String)->void:
	var stage:=app.stage as PlainsRegionStage
	check(stage!=null and stage.assembly_ok,"actual formal assembly "+label)
	if stage==null:return
	var info:Dictionary={"label":label,"map_index":stage.map_index,"manifest_hash":stage.generated.manifest.manifest_hash,"enemies":[],"modules":[],"sprites":[],"scenery":[]}
	check(PixelFormalActors.pixel_context(stage),"stage metadata owns new context "+label)
	check(app.get_node_or_null("PlainsBackground")==null,"retired backdrop absent "+label)
	var parallax:=app.get_node("PixelPlainsParallax") as PixelPlainsParallax
	check(parallax.panels.size()==9,"three independent layers each tiled three times "+label)
	info.parallax=parallax.measured_nodes()
	var actor_visual:=app.player.get_node_or_null("PixelPlainsActor")
	check(actor_visual is PixelPlainsActor and not app.player.get_node("CourierVisual").visible,"new actual player presentation "+label)
	for enemy:EnemyMotor in stage.enemies:
		var actor:=enemy.get_node("Actor") as EnemyActor
		var visual:=enemy.get_node_or_null("Presentation")
		check(visual is PixelPlainsEnemy,"enemy actual new presentation "+str(actor.definition.behavior_id))
		info.enemies.append({"path":str(enemy.get_path()),"behavior":str(actor.definition.behavior_id),"aerial":actor.definition.aerial,"size":str(actor.definition.collision_size),"visual":visual.get_script().resource_path,"attack_state":str(actor.attack_behavior.state) if actor.attack_behavior!=null else "none"})
	var boss_presentation:=stage.boss.get_node("Presentation")
	check(boss_presentation.get("pixel_style")==true,"actual Boss pixel consumer "+label)
	info.boss={"scene":stage.boss.scene_file_path,"presentation":boss_presentation.get_script().resource_path,"pixel_style":boss_presentation.pixel_style}
	check(stage.terrain_art.enabled and stage.terrain_art.art is PixelFormalTerrain,"actual static terrain consumer "+label)
	var one_way:=0
	var moving:=0
	for module:PlatformingModule in stage.assembler.modules:
		check(module.terrain_candidate_preview and module.pixel_mechanism_art,"module new static/mechanism presentation "+str(module.definition.module_id))
		for index:int in module.definition.platforms.size():
			var shape:=module.get_node("Platform%d/CollisionShape2D"%index) as CollisionShape2D
			check(shape.shape.size==module.definition.platforms[index].size,"actual platform physics dimensions unmodified")
			if index in module.definition.one_way_platform_indices:
				one_way+=1
				check(shape.one_way_collision,"one-way physical semantics retained")
		for ferry:ModuleMovingPlatform in module.moving_platforms:
			moving+=1
			check(ferry.pixel_art_enabled and is_instance_valid(ferry.painted_art) and ferry.painted_art.visible,"new actual moving consumer")
		info.modules.append({"id":str(module.definition.module_id),"platforms":module.definition.platforms.size(),"one_way":module.definition.one_way_platform_indices.size(),"moving":module.moving_platforms.size()})
	info.one_way_count=one_way;info.moving_count=moving
	var scenery:=stage.get_node_or_null("PixelRegionScenery") as PixelRegionScenery
	check(scenery!=null,"new decorative consumer "+label)
	if scenery!=null:
		info.scenery_count=scenery.placements.size()
		for item:Dictionary in scenery.placements:
			var supported:=false
			for support:Rect2 in scenery.supports:
				if absf(support.position.y-item.position.y)<.01 and item.position.x>=support.position.x and item.position.x<=support.end.x:supported=true
			check(supported,"actual ornament root has solid support")
			for blocked:Rect2 in scenery.protected_regions:check(not item.bounds.grow(6).intersects(blocked),"actual ornament full bounds avoid protected region")
			info.scenery.append({"position":str(item.position),"kind":item.kind,"bounds":str(item.bounds)})
	for child:Node in stage.get_children():
		if child is PlainsStageVisual:check(child.pixel_style,"actual pickups new style")
	walk_nodes(stage,info.sprites)
	for sprite:Dictionary in info.sprites:
		check(not sprite.visible or not str(sprite.texture).begins_with("res://assets/plains_"),"no visible legacy sprite path "+str(sprite.texture))
	check(app.controller.shoot_ability.try_fire(Vector2.UP,true),"actual formal shot accepted "+label)
	var projectiles:=app.controller.shoot_ability.get_projectiles()
	check(not projectiles.is_empty() and projectiles[-1].presentation is PixelPlainsProjectile,"actual new player projectile skin "+label)
	observations.append(info)
func _run()->void:
	root.size=Vector2i(1280,720)
	app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	# Ordinary menu signal dispatch, not a special Lab or alternate stage.
	app.menu.requested_plains.emit("level-design-v2-baseline/08")
	await frames(20)
	inspect_stage("ordinary_menu_map1")
	var before:String=app.stage.generated.manifest.manifest_hash
	app._load_stage()
	await frames(20)
	check(app.stage.generated.manifest.manifest_hash==before,"stage reload retains formal manifest")
	inspect_stage("reload_map1")
	# Explicit outcome fixture ONLY for second-map consumer coverage. This is
	# not a live route, earned Boss victory, normal loot or campaign completion.
	check(await load("res://tests/plains_campaign_fixture.gd").second_map(app,self),"explicit fixture reaches real second-map consumer")
	await frames(20)
	inspect_stage("explicit_outcome_fixture_map2")
	var file:=FileAccess.open("res://build/pixel-review/formal_inventory.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":"300d65c+dirty","scope":"actual consumers; second-map transition explicit outcome fixture, not route proof","checks":checks,"failures":failures,"observations":observations},"  "))
	check(await load("res://tests/audio_teardown.gd").drain_world(app),"owned actual audio drains")
	app.free();await frames(10)
	print("PIXEL_FORMAL_INVENTORY checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
