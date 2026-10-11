class_name PlainsRegionStage
extends GeneratedDemoStage
var region_state: PlainsRegionState
var chests: Array[Dictionary] = []
var merchant_position := Vector2.ZERO
var visited_area := ""
var restored_boss: Dictionary = {}
var map_index := 1
var map_view: PlainsRegionMap

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
	var scenery:=PlainsRegionScenery.new()
	scenery.configure(generated.manifest)
	add_child(scenery)
	for a: Dictionary in generated.manifest.areas:
		if a.id=="tutorial_jump": continue
		_sign(Vector2(a.position[0]-120,a.position[1]-75),area_label(a),Color("b9cf9a") if a.role != "challenge_reward" else Color("ebc968"))
	_sign(spawn+Vector2(50,-70),"Hold JUMP for height\nAim back, release to recoil",Color("e7cb79"))
	_sign(merchant_position+Vector2(-100,-115),"CAMP / 5 COINS / FINITE STOCK\n"+("MINI BOSS -> MAP 2" if map_index==1 else "WINDKEEPER -> PLAINS COMPLETE"),Color("e7cb79"))
	for e: Dictionary in generated.manifest.connections:
		if e.condition == "backside": _sign(Vector2(e.control[0]-130,e.control[1]-40),"SHORTCUT / INTERACT FROM THIS SIDE",Color("dcc887"))
	# Preview rewards above the entrance of hard climbs; player can decide to climb.
	for c: Dictionary in chests:
		if c.tier in ["high", "region_top"]:
			var trial:=PlainsRegionGenerator.new()._area(generated.manifest,c.area)
			for e: Dictionary in generated.manifest.connections:
				if e.b==trial.id and e.kind=="challenge":
					var entrance:=PlainsRegionGenerator.new()._area(generated.manifest,e.a)
					_sign(Vector2(entrance.position[0]-150,entrance.position[1]-160),"RARE CACHE ABOVE / STAIRS -> TWO FERRIES -> RECOIL
OPTIONAL / DROP RIGHT TO RETURN",Color("e4cb87"))
			_sign(c.position+Vector2(-110,-55),"RARE CACHE / DROP RIGHT TO RETURN",Color("ebce82"))
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
	for a: Dictionary in generated.manifest.areas:
		if a.role not in ["junction","prep","merchant"]: continue
		var clues: Array[String]=[]
		for e: Dictionary in generated.manifest.connections:
			if e.a!=a.id and e.b!=a.id: continue
			if e.b==a.id and not e.bidirectional: continue
			var other:=PlainsRegionGenerator.new()._area(generated.manifest,e.b if e.a==a.id else e.a)
			var v:=Vector2(other.position[0]-a.position[0],other.position[1]-a.position[1])
			var arrow: String="UP" if v.y<0 else "DOWN" if v.y>0 else "RIGHT" if v.x>0 else "LEFT"
			clues.append(arrow+": "+area_label(other)+( " / OPEN FROM OTHER SIDE" if e.condition=="backside" else ""))
		_sign(Vector2(a.position[0]-170,a.position[1]+60),"\n".join(clues),Color("b8c8a0"))
	var map_layer:=CanvasLayer.new()
	map_layer.layer=1
	add_child(map_layer)
	var map:=PlainsRegionMap.new()
	map_view=map
	map.stage=self
	map.position=Vector2(1018,180)
	map_layer.add_child(map)
	queue_redraw()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	capture_state()

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
		region_state.actors[enemy_manifest[index].id] = {"health":actor.health.current,"position":[pos.x,pos.y],"state":String(attack.state) if attack!=null else "idle","state_time":attack.state_time if attack!=null else 0.0,"cooldown":attack.cooldown if attack!=null else 0.0,"serial":attack._serial if attack!=null else 0,"home":[attack.home.x,attack.home.y] if attack!=null else [pos.x,pos.y],"direction":actor.brain.direction}
	var encounter := boss.get_node("Encounter") as WindkeeperEncounter
	region_state.boss_state={"health":encounter.health.current,"phase":encounter.stage_phase,"chase_segment":encounter.chase_segment,"mode":String(encounter.mode),"clock":encounter.clock,"position":[boss.position.x,boss.position.y],"active":encounter.active,"serial":encounter._attack_serial,"direction":encounter.direction,"pattern_index":encounter.pattern_index if encounter is BellstriderEncounter else 0}
	region_state.boss_state.merge(encounter.combat_snapshot(),true)
	for i: int in shot_latches.size():
		var latch := shot_latches[i]
		region_state.mechanisms[generated.manifest.shot_latch_plan.latches[i].id]={"clock":latch._clock,"opened_at":latch._opened_at,"is_open":latch.is_open,"sequence_step":latch.sequence_step,"open_count":latch.open_count}
		if shot_latches[i].is_open and shot_latches[i].open_seconds == 0:
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
	for i: int in shot_latches.size():
		var id: String=generated.manifest.shot_latch_plan.latches[i].id
		if region_state.mechanisms.has(id):
			var data: Dictionary=region_state.mechanisms[id]
			shot_latches[i]._clock=float(data.clock)
			shot_latches[i]._opened_at=float(data.opened_at)
			shot_latches[i].sequence_step=int(data.sequence_step)
			shot_latches[i].open_count=int(data.open_count)
			shot_latches[i].is_open=bool(data.is_open)
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

