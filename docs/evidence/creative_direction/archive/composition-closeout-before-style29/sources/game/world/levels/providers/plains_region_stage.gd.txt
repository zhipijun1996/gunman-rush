class_name PlainsRegionStage
extends GeneratedDemoStage
var region_state: PlainsRegionState
var chests: Array[Dictionary] = []
var merchant_position := Vector2.ZERO
var visited_area := ""
var restored_boss: Dictionary = {}
var map_index := 1
var map_view: PlainsRegionMap
var terrain_art: PlainsTerrainStudy
var context_signs: Array[Dictionary] = []
var boss_seal:BossArenaSeal
var regional_art_renderer: Node2D

func _prepare_level_plan(forest_region: bool) -> bool:
	if level_plan!=null: return true
	# Existing standalone/experimental callers keep configure_generated().
	var converted := LegacyRegionPlanAdapter.generated(generated,tuning,map_index,forest_region)
	if not converted.accepted():
		push_error(converted.error)
		return false
	level_plan=converted.plan
	return true

func _ready() -> void:
	if not _prepare_level_plan(false): return
	set_meta("pixel_formal_style",not generated.has("regional_art_plan"))
	set_meta("underworld_formal_style",not generated.has("regional_art_plan"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if region_state == null: region_state = PlainsRegionState.new()
	if not region_state.bind_map(level_plan.map_hash): return
	var assembled := LevelRuntime.assemble(self,level_plan,region_state,generated.manifest)
	assembler=assembled.assembler as RandomStageAssembler
	if not assembled.ok:
		push_error("Region assembly failed: " + str(assembled.get("error")))
		return
	assembly_ok = true
	bounds = assembler.bounds
	spawn = assembler.world_entry()
	anchors = assembler.world_anchors()
	anchor_position = spawn
	boss_arena = level_plan.boss_arena
	exits.clear()
	exit_positions.clear()
	merchant_position = level_plan.merchant_position
	supply_position = merchant_position
	encounter_plan = generated.encounter_plan
	_spawn_enemies_from_plan()
	for index: int in enemies.size():
		var id: String = enemy_manifest[index].id
		if region_state.actors.has(id):
			var actor := enemies[index].get_node("Actor") as EnemyActor
			var saved: Dictionary = region_state.actors[id]
			if not actor.restore_instance_health(float(saved.health)):
				assembly_ok=false
				push_error("Invalid region actor snapshot")
				return
			if saved.has("position"): enemies[index].position=Vector2(saved.position[0],saved.position[1])
			# Terminal actors keep their drop receipt and stay terminal on reload.
			if float(saved.health) <= 0: enemies[index].hide()
	boss = LevelRuntime.create_boss(level_plan.boss)
	add_child(boss)
	if not region_state.boss_state.is_empty():
		restored_boss=region_state.boss_state.duplicate(true)
		var encounter := boss.get_node("Encounter") as WindkeeperEncounter
		encounter.restore_region_entry(region_state.boss_state)
	if restored_boss.get("seal_closed",false) and float(restored_boss.get("health",0))>0:spawn=Vector2(boss_arena.position.x+70,boss_arena.end.y-18)
	reward_position = boss.position
	pickups.append_array(LevelRuntime.restore_pickups(level_plan.pickups,region_state.claimed))
	for id: String in region_state.drops:
		var p: Dictionary=region_state.drops[id]
		restore_drop_pickups(p,id,region_state.claimed)
		if id == BellstriderRewards.source_id(self): BellstriderRewards.restore_pickup_lock(self,p)
	chests.append_array(LevelRuntime.restore_caches(level_plan.caches,region_state.claimed))
	install_visual_layer(VISUAL_LAYER.new())
	var scenery: UnderworldScenery
	if not generated.has("regional_art_plan"):
		scenery = UnderworldScenery.new()
		scenery.name = "PixelRegionScenery"
		scenery.configure(self)
		add_child(scenery)
	_context_sign(spawn+Vector2(20,-100), "HOLD JUMP  ·  AIM BACK TO RECOIL", 220)
	_context_sign(merchant_position+Vector2(-115,-112), "REPAIR CAMP  ·  INTERACT", 220)
	var creek: Dictionary = generated.manifest.get("creek_discovery", {})
	if not creek.is_empty():
		var hint_area := PlainsRegionGenerator.new()._area(generated.manifest, str(creek.get("hint_from", "area_1_1")))
		_context_sign(Vector2(hint_area.position[0]-120,hint_area.position[1]+45), "↓ CREEK  ·  PARK THE FERRY TO EXPLORE", 170)
	for connection: Dictionary in generated.manifest.connections:
		if connection.kind == "challenge":
			var entrance := PlainsRegionGenerator.new()._area(generated.manifest, str(connection.a))
			_context_sign(Vector2(entrance.position[0]-110,entrance.position[1]-135), "↑ OPTIONAL TRIAL  ·  RARE CACHE", 170)
		if connection.condition == "backside":
			_context_sign(Vector2(connection.control[0]-110,connection.control[1]-75), "SHORTCUT  ·  SHOOT THE UPPER BELL", 190)
	for chest: Dictionary in chests:
		if chest.tier in ["high", "region_top"]:
			_context_sign(chest.position+Vector2(-95,-80), "CACHE  ·  ↓ + JUMP TO RETURN", 170)
	for c: Dictionary in chests:
		var sprite:=Sprite2D.new()
		UnderworldObjects.place_chest(sprite,c.position+Vector2(0,21),bool(c.claimed),StringName(str(c.tier)))
		add_child(sprite)
		c.sprite=sprite
	var merchant:=Sprite2D.new()
	if generated.has("regional_art_plan"):
		merchant.texture=PixelFormalActors.icon_texture(&"merchant")
		merchant.scale=Vector2(95,90)/merchant.texture.get_size()
		merchant.position=merchant_position+Vector2(0,-30)
	else:
		merchant.name = "UnderworldMerchant"
		merchant.texture=UnderworldActors.icon_texture(&"merchant")
		UnderworldActors.place_humanoid(merchant, merchant_position + Vector2(0,18))
	add_child(merchant)
	var map_layer:=CanvasLayer.new()
	map_layer.layer=1
	add_child(map_layer)
	var map:=PlainsRegionMap.new()
	map_view=map
	map.stage=self
	map.region_chip = true
	map.position=Vector2(1098,14)
	map_layer.add_child(map)
	if generated.has("regional_art_plan"):
		var joint := not (generated.regional_art_plan.get("joint_modules",[]) as Array).is_empty()
		var script := load("res://game/presentation/world/art/plains_joint_recoil_composer.gd" if joint else "res://game/presentation/world/art/plains_regional_composer.gd") as Script
		regional_art_renderer = script.new() as Node2D
		add_child(regional_art_renderer)
		regional_art_renderer.call("install",self,generated.regional_art_plan)
	else:
		terrain_art = PlainsTerrainStudy.new()
		terrain_art.stage = self
		add_child(terrain_art)
		terrain_art.geometry_changed.connect(func() -> void:
			scenery.configure(self)
			scenery.queue_redraw())
		PixelFormalActors.install(self)
		UnderworldActors.install(self)
	# Health restoration intentionally leaves terminal Motors hidden. Their
	# stage-owned pixels restore only after the real presentation installer exists.
	for index: int in enemies.size():
		var saved: Dictionary = region_state.actors.get(enemy_manifest[index].id,{})
		var remains := _enemy_remains(enemies[index])
		if is_instance_valid(remains) and saved.has("presentation_remains"):
			var pose: Variant = saved.presentation_remains
			var support: Node2D = _resolve_remains_support(pose.support) if EnemyFeedback01Remains.valid_presentation_snapshot(pose) else null
			remains.restore_presentation(pose,support)
	queue_redraw()

func _enemy_remains(motor: EnemyMotor) -> EnemyFeedback01Remains:
	var presentation := motor.get_node_or_null("Presentation")
	return EnemyPresentationBinding.remains(presentation)

func _remains_support_identity(support: Node2D) -> Dictionary:
	if not is_instance_valid(support) or support.is_queued_for_deletion(): return {}
	for module: PlatformingModule in assembler.modules:
		if support.get_parent() == module and not String(support.name).contains("@"):
			return {"kind":"module","module":String(module.name),"body":String(support.name)}
	if is_instance_valid(assembler.ground_supports) and support.get_parent() == assembler.ground_supports:
		for column: Rect2 in assembler.ground_supports.columns:
			if support.position.is_equal_approx(column.get_center()):
				return {"kind":"ground","rect":[column.position.x,column.position.y,column.size.x,column.size.y]}
	if assembler is PlainsRegionAssembler:
		for id: String in (assembler as PlainsRegionAssembler).shortcut_bodies:
			if (assembler as PlainsRegionAssembler).shortcut_bodies[id] == support: return {"kind":"shortcut","id":id}
	return {}

func _resolve_remains_support(identity: Dictionary) -> Node2D:
	match identity.kind:
		"module":
			for module: PlatformingModule in assembler.modules:
				if String(module.name) == identity.module: return module.get_node_or_null(NodePath(identity.body)) as PhysicsBody2D
		"ground":
			if not is_instance_valid(assembler.ground_supports): return null
			var r: Array = identity.rect
			var column := Rect2(r[0],r[1],r[2],r[3])
			if column not in assembler.ground_supports.columns: return null
			for body: Node in assembler.ground_supports.get_children():
				if body is StaticBody2D and body.position.is_equal_approx(column.get_center()): return body
		"shortcut":
			if assembler is PlainsRegionAssembler: return (assembler as PlainsRegionAssembler).shortcut_bodies.get(identity.id) as Node2D
	return null

func get_regional_art_snapshot() -> Dictionary:
	var art: Dictionary = {}
	if is_instance_valid(regional_art_renderer):
		art = regional_art_renderer.call("measured_nodes")
	return {"ready":assembly_ok and not art.is_empty() and art.get("omitted",[]).is_empty() and art.get("installed_foundations_valid",false),"manifest_hash":generated.manifest.get("manifest_hash",""),"art_plan":generated.get("regional_art_plan",{}),"art":art,"production_pool":false,"actual_modules":assembler.modules.size() if assembler!=null else 0,"actual_enemies":enemies.size(),"actual_chests":chests.size(),"actual_boss":is_instance_valid(boss)}

func get_joint_recoil_snapshot() -> Dictionary:
	var result := get_regional_art_snapshot()
	var collisions: Array = []
	if assembler != null and assembler.has_method("joint_collision_snapshot"):
		collisions = assembler.call("joint_collision_snapshot")
	result["joint_collisions"] = collisions
	result["joint_candidate"] = generated.manifest.get("joint_recoil_profile",false)
	var expected: Array[String] = []
	for program: Dictionary in result.art_plan.get("joint_modules",[]):
		for volume: Dictionary in program.get("terrain_bodies",[]):
			expected.append(str(program.node_id).replace("/","_")+":"+str(volume.source_role))
	var physical: Array[String] = []
	for collider: Dictionary in collisions:
		if collider.get("disabled",true) or collider.get("one_way",true) or collider.get("collision_layer",0)!=1 or collider.get("build_mode",-1)!=CollisionPolygon2D.BUILD_SOLIDS:
			continue
		physical.append(str(collider.module)+":"+str(collider.source.get("source_role","")))
	var painted: Array[String] = []
	for volume: Dictionary in result.art.get("joint_terrain",[]):
		painted.append(str(volume.module_id).replace("/","_")+":"+str(volume.source_role))
	expected.sort(); physical.sort(); painted.sort()
	var unique: Dictionary = {}
	for identity: String in expected: unique[identity]=true
	result["joint_ready"] = result.ready and result.joint_candidate and not expected.is_empty() and unique.size()==expected.size() and physical==expected and painted==expected
	return result

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	capture_state()
	_update_context_signs()

func _record_claim(id: Variant) -> void:
	region_state.claimed[id] = true

func commit_cache_claim(chest: Dictionary) -> void:
	chest.claimed = true
	_record_claim(chest.id)
	_after_cache_claim()

func _after_cache_claim() -> void:
	pass

func _persist_pickup_motion() -> void:
	if region_state != null: _save_pickup_units(region_state.drops)

func _context_sign(at: Vector2, text: String, radius: float) -> void:
	var label := _sign(at, text, Color("e7d9ac"))
	label.add_theme_font_override("font",preload("res://assets/fonts/foundry_notes.otf"))
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_shadow_color", Color("182c29"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	context_signs.append({"label": label, "radius": radius, "origin": at + Vector2(100,75)})

func _update_context_signs() -> void:
	if not is_instance_valid(bound_player) or not is_instance_valid(bound_player.motor): return
	var player := bound_player.motor
	for row: Dictionary in context_signs:
		var label: Label = row.label
		label.visible = player.is_on_floor() and player.global_position.distance_to(row.origin) < float(row.radius)
		if label.visible:
			var actor_rect := Rect2(player.global_position-Vector2(25,50),Vector2(50,65))
			if Rect2(label.global_position,label.size).intersects(actor_rect): label.hide()

func composition_focus() -> Vector2:
	var position := global_player_position()
	for module: PlatformingModule in assembler.modules:
		if module.definition.module_id != &"plains_windchime_well":continue
		var local := position-module.global_position
		if local.x>=120 and local.x<=650 and absf(local.y-module.definition.entry_port.position.y)<480:
			return module.world_exit()
	var discovery: Dictionary = generated.manifest.get("creek_discovery",{})
	if discovery.is_empty(): return Vector2.INF
	var actor := global_player_position()
	for index: int in generated.manifest.nodes.size():
		if str(generated.manifest.nodes[index].id) != str(discovery.get("bank","")): continue
		var module := assembler.modules[index]
		var slab: Rect2 = module.definition.platforms[0]
		var point := module.global_position+slab.get_center()
		# At the dock the island is a visible choice. The main fork 700 above
		# still uses a truthful downward hint, never an impossible box preview.
		if absf(actor.y-point.y)<250 and absf(actor.x-point.x)<650:return point
	return Vector2.INF

func capture_state() -> void:
	if not assembly_ok: return
	PlainsMapExploration.reveal(region_state,global_player_position())
	for a: Dictionary in generated.manifest.areas:
		if Vector2(a.position[0],a.position[1]).distance_to(global_player_position()) < 180:
			region_state.visited[a.id] = true
			visited_area = "TUTORIAL" if a.role=="tutorial" else area_label(a)
	for c: Dictionary in chests:
		if c.has("sprite"):
			UnderworldObjects.place_chest(c.sprite as Sprite2D,c.position+Vector2(0,21),bool(c.claimed),StringName(str(c.tier)))
	for p: Dictionary in pickups:
		if p.claimed: region_state.claimed[p.id] = true
	for index: int in assembler.modules.size():
		region_state.clocks[level_plan.modules[index].instance_id] = assembler.modules[index].clock
	for index: int in enemies.size():
		var actor := enemies[index].get_node("Actor") as EnemyActor
		region_state.actors[enemy_manifest[index].id] = actor.region_snapshot()
		var remains := _enemy_remains(enemies[index])
		if actor.health.terminal and is_instance_valid(remains):
			var pose := remains.presentation_snapshot(_remains_support_identity(remains.support_node()))
			if not pose.is_empty(): region_state.actors[enemy_manifest[index].id].presentation_remains = pose
	var encounter := boss.get_node("Encounter") as WindkeeperEncounter
	region_state.boss_state = encounter.region_snapshot()
	region_state.boss_state.seal_closed=is_instance_valid(boss_seal) and boss_seal.closed
	for i: int in shot_latches.size():
		var latch := shot_latches[i]
		region_state.mechanisms[generated.manifest.shot_latch_plan.latches[i].id]=latch.region_snapshot()
		if shot_latches[i].is_open and shot_latches[i].open_seconds == 0 and not shot_latches[i].motion_mode:
			region_state.opened[generated.manifest.shot_latch_plan.latches[i].id] = true

func global_player_position() -> Vector2:
	return bound_player.motor.global_position if is_instance_valid(bound_player) and is_instance_valid(bound_player.motor) else Vector2.INF

func area_label(area: Dictionary) -> String:
	if map_index==1 and area.role=="boss": return "BELLSTRIDER / MINI BOSS"
	if map_index==1 and area.role=="prep": return "BELLSTRIDER APPROACH"
	return str(area.label)

func setup_shot_latches(controller: PlayerController, lifetime: DemoLifetime) -> bool:
	if not super.setup_shot_latches(controller,lifetime): return false
	(assembler as PlainsRegionAssembler).install_attack_shortcuts(controller,lifetime)
	for latch: ShotLatch in shot_latches: latch.set_region_presentation(true)
	for i: int in shot_latches.size():
		var id: String=generated.manifest.shot_latch_plan.latches[i].id
		if region_state.mechanisms.has(id):
			var data: Dictionary=region_state.mechanisms[id]
			shot_latches[i].restore_region_state(data)
		shot_latches[i].restore_region_opened(region_state.opened.has(id))
	return true

func nearby_chest(location: Vector2) -> int:
	for i: int in chests.size():
		if not chests[i].claimed and location.distance_to(chests[i].position) < 80: return i
	return -1

func show_boss_reward_portal() -> void:
	if map_index==1:
		_sign(reward_position+Vector2(-110,-75),"MINI BOSS CLEAR / ENTER MAP 2\nKEEP COINS, HEALTH AND ITEMS",Color("ebd087"))
		queue_redraw()
	else: super.show_boss_reward_portal()

func nearby_shortcut(_location: Vector2) -> String:
	# Backside shortcuts are now accepted-shot mechanisms, never W actions.
	# Keep the query for existing HUD callers; it offers no interaction target.
	return ""

func cancel_shot_latch_requests(permanent: bool = false) -> void:
	super.cancel_shot_latch_requests(permanent)
	if is_instance_valid(assembler):
		(assembler as PlainsRegionAssembler).cancel_attack_shortcuts(permanent)

# Chests are owned by their explicit-tier Sprite2D consumers in every art branch.
# No rectangle fallback can mask an invalid/missing admitted art recipe.
