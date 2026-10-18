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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if region_state == null: region_state = PlainsRegionState.new()
	if not region_state.bind_map(str(generated.manifest.manifest_hash)): return
	assembler = PlainsRegionAssembler.new()
	(assembler as PlainsRegionAssembler).region_state = region_state
	add_child(assembler)
	var assembled := assembler.build(generated.manifest,tuning)
	if not assembled.ok:
		push_error("Region assembly failed: " + str(assembled.get("error")))
		return
	assembly_ok = true
	bounds = assembler.bounds
	spawn = assembler.world_entry()
	anchors = assembler.world_anchors()
	anchor_position = spawn
	boss_arena = generated.boss_arena
	exits.clear()
	exit_positions.clear()
	merchant_position = Vector2(generated.manifest.merchant_position[0],generated.manifest.merchant_position[1])
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
	boss = preload("res://scenes/bosses/bellstrider.tscn").instantiate() if map_index==1 else preload("res://scenes/bosses/windkeeper.tscn").instantiate()
	if map_index==2:
		(boss.get_node("Encounter") as WindkeeperEncounter).definition=preload("res://resources/bosses/windkeeper_storm.tres")
	boss.position = Vector2(boss_arena.get_center().x,boss_arena.end.y-65)
	add_child(boss)
	if not region_state.boss_state.is_empty():
		restored_boss=region_state.boss_state.duplicate(true)
		var encounter := boss.get_node("Encounter") as WindkeeperEncounter
		var data: Dictionary = region_state.boss_state
		var restored := encounter.definition.health_definition.duplicate(true) as HealthDefinition
		restored.initial_current=float(data.health)
		encounter.health.configure(restored)
		encounter.damageable.bind_health(encounter.health)
		encounter.stage_phase=int(data.phase)
		encounter.chase_segment=int(data.chase_segment)
		encounter.mode=StringName(data.mode)
		encounter.clock=float(data.clock)
		if encounter is BellstriderEncounter: encounter.pattern_index=int(data.get("pattern_index",0))
	if restored_boss.get("seal_closed",false) and float(restored_boss.get("health",0))>0:spawn=Vector2(boss_arena.position.x+70,boss_arena.end.y-18)
	reward_position = boss.position
	for p: Dictionary in generated.manifest.pickups:
		pickups.append({"id": p.id, "kind": p.kind, "amount": int(p.amount), "position": Vector2(p.position[0],p.position[1]), "claimed": region_state.claimed.has(p.id)})
	for id: String in region_state.drops:
		var p: Dictionary=region_state.drops[id]
		if p.kind=="none": continue
		pickups.append({"id":"drop_"+id,"kind":p.kind,"amount":int(p.amount),"position":Vector2(p.position[0],p.position[1]),"claimed":region_state.claimed.has("drop_"+id),"source":id})
	for c: Dictionary in generated.manifest.rewards:
		var chest := c.duplicate(true)
		chest.id=PlainsRegionCampaign.prefix(map_index)+c.id
		chest.position = Vector2(c.position[0],c.position[1])
		chest.claimed = region_state.claimed.has(chest.id)
		chests.append(chest)
	install_visual_layer(VISUAL_LAYER.new())
	if not generated.has("regional_art_plan"):
		var scenery:=PlainsRegionScenery.new()
		scenery.configure(generated.manifest, PlainsRegionScenery.solid_supports(self), PlainsRegionScenery.protection(self))
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
			_context_sign(Vector2(connection.control[0]-110,connection.control[1]-75), "SHORTCUT  ·  INTERACT", 130)
	for chest: Dictionary in chests:
		if chest.tier in ["high", "region_top"]:
			_context_sign(chest.position+Vector2(-95,-80), "CACHE  ·  ↓ + JUMP TO RETURN", 170)
	for c: Dictionary in chests:
		var sprite:=Sprite2D.new()
		sprite.texture=PlainsV3Assets.texture("objects.json","chest")
		sprite.scale=Vector2(58,48)/sprite.texture.get_size()
		sprite.position=c.position+Vector2(0,-3)
		sprite.modulate=Color("ddb1ff") if c.tier=="high" else Color("ffe7a0") if c.tier=="region_top" else Color.WHITE
		add_child(sprite)
		c.sprite=sprite
	var merchant:=Sprite2D.new()
	merchant.texture=PlainsV3Assets.texture("objects.json","shop")
	merchant.scale=Vector2(95,90)/merchant.texture.get_size()
	merchant.position=merchant_position+Vector2(0,-30)
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
		var script := load("res://scripts/art/plains_joint_recoil_composer.gd" if joint else "res://scripts/art/plains_regional_composer.gd") as Script
		regional_art_renderer = script.new() as Node2D
		add_child(regional_art_renderer)
		regional_art_renderer.call("install",self,generated.regional_art_plan)
	else:
		terrain_art = PlainsTerrainStudy.new()
		terrain_art.stage = self
		add_child(terrain_art)
	queue_redraw()

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

func _context_sign(at: Vector2, text: String, radius: float) -> void:
	var label := _sign(at, text, Color("e7d9ac"))
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_shadow_color", Color("182c29"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	context_signs.append({"label": label, "radius": radius, "origin": at + Vector2(100,75)})

func _update_context_signs() -> void:
	var app := get_parent() as DemoApp
	if app == null or not is_instance_valid(app.player): return
	for row: Dictionary in context_signs:
		var label: Label = row.label
		label.visible = app.player.is_on_floor() and app.player.global_position.distance_to(row.origin) < float(row.radius)
		if label.visible:
			var actor_rect := Rect2(app.player.global_position-Vector2(25,50),Vector2(50,65))
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
		if c.has("sprite"): (c.sprite as Sprite2D).modulate.a=0.35 if c.claimed else 1.0
	for p: Dictionary in pickups:
		if p.claimed: region_state.claimed[p.id] = true
	for index: int in assembler.modules.size():
		region_state.clocks[generated.manifest.nodes[index].id] = assembler.modules[index].clock
	for index: int in enemies.size():
		var actor := enemies[index].get_node("Actor") as EnemyActor
		var attack := actor.attack_behavior
		var pos := enemies[index].position
		region_state.actors[enemy_manifest[index].id] = {"health":actor.health.current,"position":[pos.x,pos.y],"state":String(attack.state) if attack!=null else "idle","state_time":attack.state_time if attack!=null else 0.0,"cooldown":attack.cooldown if attack!=null else 0.0,"serial":attack._serial if attack!=null else 0,"locked_direction":[attack.locked_direction.x,attack.locked_direction.y] if attack!=null else [1,0],"attack_goal":[attack.attack_goal.x,attack.attack_goal.y] if attack!=null else [pos.x,pos.y],"attack_origin":[attack.attack_origin.x,attack.attack_origin.y] if attack!=null else [pos.x,pos.y],"home":[attack.home.x,attack.home.y] if attack!=null else [pos.x,pos.y],"direction":actor.brain.direction}
	var encounter := boss.get_node("Encounter") as WindkeeperEncounter
	region_state.boss_state={"health":encounter.health.current,"phase":encounter.stage_phase,"chase_segment":encounter.chase_segment,"mode":String(encounter.mode),"clock":encounter.clock,"position":[boss.position.x,boss.position.y],"active":encounter.active,"serial":encounter._attack_serial,"direction":encounter.direction,"pattern_index":encounter.pattern_index if encounter is BellstriderEncounter else 0}
	region_state.boss_state.merge(encounter.combat_snapshot(),true)
	region_state.boss_state.seal_closed=is_instance_valid(boss_seal) and boss_seal.closed
	for i: int in shot_latches.size():
		var latch := shot_latches[i]
		region_state.mechanisms[generated.manifest.shot_latch_plan.latches[i].id]={"clock":latch._clock,"opened_at":latch._opened_at,"is_open":latch.is_open,"sequence_step":latch.sequence_step,"open_count":latch.open_count,"motion_clock":latch.motion_target.motion_clock if latch.motion_mode else 0.0,"motion_running":latch.motion_target.motion_running if latch.motion_mode else false}
		if shot_latches[i].is_open and shot_latches[i].open_seconds == 0 and not shot_latches[i].motion_mode:
			region_state.opened[generated.manifest.shot_latch_plan.latches[i].id] = true

func global_player_position() -> Vector2:
	var app := get_parent()
	return app.player.global_position if app is DemoApp and is_instance_valid(app.player) else Vector2.INF

func area_label(area: Dictionary) -> String:
	if map_index==1 and area.role=="boss": return "BELLSTRIDER / MINI BOSS"
	if map_index==1 and area.role=="prep": return "BELLSTRIDER APPROACH"
	return str(area.label)

func setup_shot_latches(controller: PlayerController, lifetime: DemoLifetime) -> bool:
	if not super.setup_shot_latches(controller,lifetime): return false
	for latch: ShotLatch in shot_latches: latch.set_region_presentation(true)
	for i: int in shot_latches.size():
		var id: String=generated.manifest.shot_latch_plan.latches[i].id
		if region_state.mechanisms.has(id):
			var data: Dictionary=region_state.mechanisms[id]
			shot_latches[i]._clock=float(data.clock)
			shot_latches[i]._opened_at=float(data.opened_at)
			shot_latches[i].sequence_step=int(data.sequence_step)
			shot_latches[i].restore_sequence_gate()
			shot_latches[i].open_count=int(data.open_count)
			shot_latches[i].is_open=bool(data.is_open)
			if shot_latches[i].motion_mode:
				shot_latches[i].motion_target.motion_clock=float(data.get("motion_clock",0))
				shot_latches[i].motion_target.motion_running=bool(data.get("motion_running",false))
				shot_latches[i].motion_target.restore_motion(shot_latches[i].motion_target.motion_clock,shot_latches[i].motion_target.motion_running)
		if region_state.opened.has(id) or shot_latches[i].is_open:
			shot_latches[i].is_open = true
			shot_latches[i].gate_shape.set_deferred("disabled",true)
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

func nearby_shortcut(location: Vector2) -> String:
	for e: Dictionary in generated.manifest.connections:
		if e.condition == "backside" and not region_state.opened.has(e.id) and location.distance_to(Vector2(e.control[0],e.control[1])) < 80: return e.id
	return ""

func _draw() -> void:
	super._draw()
	if not assembly_ok: return
	for c: Dictionary in chests:
		if c.has("sprite"): continue
		var color := Color("c7aa77") if c.tier == "medium" else Color("cfa2f3") if c.tier == "high" else Color("ffe186")
		if c.claimed: color = Color("647361")
		draw_rect(Rect2(c.position+Vector2(-18,-4),Vector2(36,22)),color)
		draw_rect(Rect2(c.position+Vector2(-18,-4),Vector2(36,8)),color.lightened(0.2))
		draw_line(c.position+Vector2(0,-4),c.position+Vector2(0,18),Color("635037"),3)
		if not c.claimed: draw_circle(c.position+Vector2(0,-10),3,color.lightened(0.4))
