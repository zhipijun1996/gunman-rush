class_name ThornForestRegionStage
extends PlainsRegionStage
## Forest formal consumer, retaining shared reward/ledger/map/respawn contracts.
var chest_art_layer: ChestArtLayer
var _forest_draw_clock := 0.0
var _gate_hint: Label
var discoveries: ForestBibleDiscoveries
var ambience: ForestBibleAmbience
var forest_terrain: UnderworldTerrain
var near_scenery: ForestBibleNearScenery
var _web_phase_seen: Dictionary = {}

func _has_canopy_boss() -> bool:
	var content: Variant=generated.manifest.get("boss_content")
	return content is Dictionary and content.get("contract")=="forest-queen-canopy-v3"

func _canopy_point(key: String) -> Vector2:
	var geometry: Variant=generated.manifest.get("boss_geometry")
	if not geometry is Dictionary: return Vector2.INF
	var value: Variant=geometry.get(key)
	if not value is Array or value.size()!=2: return Vector2.INF
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)): return Vector2.INF
	return Vector2(value[0],value[1])

func forest_boss_entry_position() -> Vector2:
	return _canopy_point("safe_return") if _has_canopy_boss() else Vector2(boss_arena.position.x+70,boss_arena.end.y-18)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if region_state == null: region_state = PlainsRegionState.new()
	if not region_state.bind_map(str(generated.manifest.manifest_hash)):
		push_error("Forest map state belongs to another manifest")
		return
	assembler = ThornForestRegionAssembler.new()
	(assembler as ThornForestRegionAssembler).region_state = region_state
	add_child(assembler)
	var built := assembler.build(generated.manifest,tuning)
	if not built.ok:
		push_error(str(built.error))
		return
	if ForestBiblePresentation.enabled(generated.manifest):
		var solids: Array[Rect2] = []
		for row: Dictionary in generated.manifest.platforms:
			if not bool(row.one_way): solids.append(ThornForestRegionGenerator._rect(row.rect))
		forest_terrain = UnderworldTerrain.build(solids)
		if forest_terrain == null:
			push_error("Shared forest terrain boundary build rejected")
			return
		if not ForestBibleTerrainMaterial.install_on(forest_terrain):
			forest_terrain.free()
			forest_terrain = null
			push_error("Forest shared-family material installation rejected")
			return
		# Same tile topology and exact-boundary adapter as formal Plains. Draw
		# behind the assembler's real signals and actors, after our background.
		add_child(forest_terrain)
		move_child(forest_terrain,0)
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
	for row: Dictionary in encounter_plan.enemies:
		var sources := {"forest_bark_beetle":"res://scenes/enemies/forest_bark_beetle.tscn","forest_swing_pod":"res://scenes/enemies/forest_swing_pod.tscn","forest_crossbranch":"res://scenes/enemies/forest_crossbranch.tscn","forest_lantern":"res://scenes/enemies/forest_lantern.tscn","forest_seed_sentry":"res://scenes/enemies/forest_seed_sentry.tscn","forest_thread_spider":"res://scenes/enemies/forest_thread_spider.tscn","forest_bible_weaver":"res://scenes/enemies/forest_bible_weaver.tscn","charger":"res://scenes/enemies/patrol_drone.tscn"}
		if not sources.has(row.behavior_id):
			assembly_ok = false
			push_error("Unknown recorded forest enemy behavior")
			return
		var scene: PackedScene = load(sources[row.behavior_id])
		var creature := scene.instantiate() as EnemyMotor
		creature.position = Vector2(row.position[0],row.position[1])
		var actor := creature.get_node("Actor") as EnemyActor
		actor.definition = preload("res://resources/enemies/plains_charger.tres").duplicate(true) if row.behavior_id == "charger" else actor.definition.duplicate(true)
		if row.behavior_id=="forest_bark_beetle" and row.has("initial_direction"):
			if not row.initial_direction is int or row.initial_direction not in [-1,1]:
				assembly_ok=false;push_error("Recorded bark facing rejected");return
			actor.definition.initial_direction=int(row.initial_direction)
		actor.definition.patrol_half_width = float(row.patrol_radius)
		add_child(creature)
		if region_state.actors.has(row.id):
			if row.behavior_id in ["forest_crossbranch","forest_bark_beetle","forest_swing_pod","forest_bible_weaver"]:
				var record: Variant=region_state.actors[row.id]
				if not record is Dictionary or not record.get("depth_state") is Dictionary or not record.get("position") is Array or record.position.size()!=2:
					assembly_ok=false;push_error("Recorded migration actor shape rejected");return
				for value: Variant in [record.get("health")]+record.position:
					if not (value is int or value is float) or not is_finite(float(value)):
						assembly_ok=false;push_error("Recorded migration actor number rejected");return
			if row.behavior_id in ["forest_bark_beetle","forest_swing_pod","forest_bible_weaver"]:
				var record: Dictionary=region_state.actors[row.id]
				if not record.get("state") is String or not record.get("home") is Array or record.home.size()!=2 or record.get("direction") not in [-1,1] or not record.get("serial") is int or record.serial<0:
					assembly_ok=false;push_error("Recorded rooted actor phase rejected");return
				for value: Variant in [record.get("state_time"),record.get("cooldown")]+record.home:
					if not (value is int or value is float) or not is_finite(float(value)):
						assembly_ok=false;push_error("Recorded rooted actor phase number rejected");return
				if record.state_time<0 or record.cooldown<0:
					assembly_ok=false;push_error("Recorded rooted actor phase debt rejected");return
			var saved: Dictionary = region_state.actors[row.id]
			if not actor.restore_instance_health(float(saved.health)): assembly_ok = false
			creature.position = Vector2(saved.position[0],saved.position[1])
			if actor.health.terminal: creature.hide()
		enemies.append(creature)
		enemy_manifest.append(row.duplicate(true))
	if not enemies.is_empty(): enemy = enemies[0]
	var forest_version: String = generated.manifest.version
	if _has_canopy_boss() and (not _canopy_point("safe_return").is_finite() or not _canopy_point("reward_position").is_finite()):
		assembly_ok=false;push_error("Recorded canopy entry or reward point rejected");return
	var boss_path := ThornForestRegionGenerator.boss_scene_path(forest_version,map_index,generated.manifest)
	if boss_path.is_empty():
		assembly_ok=false;push_error("Recorded forest Boss content is not in the version whitelist");return
	var boss_scene: PackedScene = load(boss_path)
	boss = boss_scene.instantiate()
	var boss_point: Array = generated.manifest.get("boss_geometry",{}).get("boss_position",[boss_arena.get_center().x,boss_arena.end.y-100])
	boss.position = Vector2(boss_point[0],boss_point[1])
	add_child(boss)
	var encounter := boss.get_node("Encounter") as ThornForestEncounter
	if not region_state.boss_state.is_empty():
		restored_boss = region_state.boss_state.duplicate(true)
		# Duels own extra physical targets. App validates/restores them only after
		# configure_arena + bind_duel; restoring here would discard their ledger.
		if not encounter.has_method("bind_duel"):
			var restored := encounter.definition.health_definition.duplicate(true) as HealthDefinition
			restored.initial_current = float(restored_boss.health)
			encounter.health.configure(restored)
			encounter.damageable.bind_health(encounter.health)
			encounter.restore_combat_state(restored_boss)
	if bool(restored_boss.get("seal_closed",false)) and encounter.health.current > 0:
		spawn = forest_boss_entry_position()
	reward_position = _canopy_point("reward_position") if _has_canopy_boss() else Vector2(boss_arena.get_center().x,boss_arena.end.y-18)
	for row: Dictionary in generated.manifest.pickups:
		pickups.append({"id":row.id,"kind":row.kind,"amount":int(row.amount),"position":Vector2(row.position[0],row.position[1]),"claimed":region_state.claimed.has(row.id)})
	for id: String in region_state.drops:
		var drop: Dictionary = region_state.drops[id]
		if drop.kind == "none": continue
		pickups.append({"id":"drop_"+id,"kind":drop.kind,"amount":int(drop.amount),"position":Vector2(drop.position[0],drop.position[1]),"claimed":region_state.claimed.has("drop_"+id),"source":id})
	for row: Dictionary in generated.manifest.rewards:
		var chest := row.duplicate(true)
		chest.id = "thorn_forest/map_%s/" % map_index+str(row.id)
		chest.position = Vector2(row.position[0],row.position[1])
		chest.claimed = region_state.claimed.has(chest.id)
		chests.append(chest)
	chest_art_layer = ChestArtLayer.new()
	chest_art_layer.name = "ChestArtLayer"
	chest_art_layer.configure(chests)
	add_child(chest_art_layer)
	var map_layer := CanvasLayer.new()
	map_layer.layer = 1
	add_child(map_layer)
	map_view = PlainsRegionMap.new()
	map_view.stage = self
	map_view.region_chip = true
	map_view.position = Vector2(1098,14)
	map_layer.add_child(map_view)
	_context_sign(spawn+Vector2(-90,-82),"THORN FOREST / AIM + GRAPPLE\nPull near, kick away, recoil to change lane",290)
	for hint: Dictionary in generated.manifest.get("expedition_hints",[]):
		var hint_text := str(hint.text)
		if generated.manifest.get("layout_version")==ForestTargetHosts.LAYOUT:
			hint_text=hint_text.replace("Right: recoil toward the hanging ring, then fire down.","Right: recoil toward the hanging fruit, then fire down.")
		_context_sign(Vector2(hint.position[0],hint.position[1]),hint_text,float(hint.radius))
	_context_sign(merchant_position+Vector2(-100,-82),"ROOT CAMP / INTERACT TO TRADE",180)
	# This old sign describes v1's branch fork. On the shared v2 trunk it also
	# covers the upper thorn boundary; the cache has its own real prompt/map icon.
	if forest_version == ThornForestRegionGenerator.LEGACY_VERSION:
		_context_sign(Vector2(generated.manifest.areas[1].position[0]-100,generated.manifest.areas[1].position[1]-85),"TWO BOUGHS / CROWN CACHE IS OPTIONAL",200)
	var app := get_parent() as DemoApp
	if app != null and is_instance_valid(app.controller):
		app.controller.traversal.action_changed.connect(_accepted_forest_action)
	var ring: Dictionary = generated.manifest.hook_anchors.filter(func(row: Dictionary) -> bool: return row.id == generated.manifest.vine_gate.key_anchor)[0]
	var gate_target: Node2D = (assembler as ThornForestRegionAssembler).hook_targets.get(str(ring.id))
	var target_name := "RIPE FRUIT" if gate_target is ForestFruitAnchor else "BRASS RING"
	_context_sign(Vector2(ring.position[0]-100,ring.position[1]-65),"HOOK THE %s / UNFURL THE VINE GATE" % target_name,230)
	_gate_hint=context_signs[-1].label
	queue_redraw()

func _accepted_forest_action(action: StringName) -> void:
	var app := get_parent() as DemoApp
	if action != &"hook_kick" or app == null or not is_instance_valid(app.controller) or not app.controller.active or app.controller.actor_resources.health.terminal: return
	if app.controller.traversal.hook_target is ForestPracticeBell:
		(app.controller.traversal.hook_target as ForestPracticeBell).accepted_contact()
	if is_instance_valid(ambience) and app.controller.traversal.hook_target is ForestFruitAnchor:
		ambience.notify_fruit(app.controller.traversal.hook_target.global_position)
	(assembler as ThornForestRegionAssembler).resolve_hook_action(app.controller.traversal)

func _physics_process(delta: float) -> void:
	clock += delta
	_forest_draw_clock += delta
	if is_instance_valid(ambience):
		for body: EnemyMotor in enemies:
			var actor := body.get_node("Actor") as EnemyActor
			if not actor.attack_behavior is ForestThreadSpiderBehavior: continue
			var phase := str(actor.attack_behavior.state)
			if _web_phase_seen.get(body.get_instance_id(), "") != phase:
				_web_phase_seen[body.get_instance_id()] = phase
				if phase == "extend": ambience.notify_web(body.global_position)
	capture_state()
	_update_context_signs()
	queue_redraw()

func capture_state() -> void:
	if not assembly_ok: return
	if is_instance_valid(chest_art_layer): chest_art_layer.queue_redraw()
	var forest_assembler := assembler as ThornForestRegionAssembler
	for target: Node2D in forest_assembler.hook_targets.values():
		if target is ForestPracticeBell:
			region_state.mechanisms["practice_bell/"+str(target.name)] = target.snapshot_state()
	var point := global_player_position()
	PlainsMapExploration.reveal(region_state,point)
	for area: Dictionary in generated.manifest.areas:
		if point.distance_to(Vector2(area.position[0],area.position[1])) < 160:
			region_state.visited[area.id] = true
			visited_area = str(area.label)
	for pickup: Dictionary in pickups:
		if pickup.claimed: region_state.claimed[pickup.id] = true
	for i: int in enemies.size():
		var actor := enemies[i].get_node("Actor") as EnemyActor
		var attack := actor.attack_behavior
		var at := enemies[i].position
		region_state.actors[enemy_manifest[i].id] = {"health":actor.health.current,"position":[at.x,at.y],"state":String(attack.state) if attack else "idle","state_time":attack.state_time if attack else 0.0,"cooldown":attack.cooldown if attack else 0.0,"serial":attack._serial if attack else 0,"home":[attack.home.x,attack.home.y] if attack else [at.x,at.y],"direction":actor.brain.direction}
		if attack != null and attack.has_method("depth_snapshot"):
			region_state.actors[enemy_manifest[i].id].depth_state = attack.call("depth_snapshot")
	if is_instance_valid(boss):
		var encounter := boss.get_node("Encounter") as ThornForestEncounter
		region_state.boss_state = encounter.combat_snapshot()
		region_state.boss_state.health = encounter.health.current
		region_state.boss_state.active = encounter.active
		region_state.boss_state.direction = encounter.direction
		region_state.boss_state.position = [boss.position.x,boss.position.y]
		region_state.boss_state.seal_closed = is_instance_valid(boss_seal) and boss_seal.closed

func setup_shot_latches(_controller: PlayerController, _lifetime: DemoLifetime) -> bool:
	# Forest has fixed grapple rings, not plains' shooting gates. No fake latch success.
	return generated.manifest.shot_latch_plan.latches.is_empty()

func composition_focus() -> Vector2: return Vector2.INF

func _update_context_signs() -> void:
	# Keep each historical sign's wording and actor keepout, but show the
	# nearest applicable lesson once. Root-bay and old arrival hints overlap
	# in world space; drawing both is unreadable even if each passes its radius.
	super._update_context_signs()
	# A completed gate must not consume the nearest lesson slot.
	var forest_assembler := assembler as ThornForestRegionAssembler
	if is_instance_valid(_gate_hint) and is_instance_valid(forest_assembler) and forest_assembler.region_state != null and forest_assembler.region_state.opened.has("crown_vine"):
		_gate_hint.hide()
	var selected: Label
	var nearest := INF
	var at := global_player_position()
	for row: Dictionary in context_signs:
		var label: Label = row.label
		if not label.visible: continue
		var distance := at.distance_squared_to(row.origin)
		if distance < nearest:
			nearest = distance
			selected = label
	for row: Dictionary in context_signs:
		var label: Label = row.label
		if label != selected: label.hide()

func observation_composition_focus() -> Vector2:
	# Formal generated relations and historical candidate probes share the
	# same existing optional camera consumer. Ordinary regions remain INF.
	var windows: Array=generated.manifest.get("observation_windows",[])
	var candidate: Dictionary=generated.manifest.get("candidate_overlay",{})
	if candidate.has("observation_rect"):
		windows=windows.duplicate();windows.append({"rect":candidate.get("observation_rect",[]),"focus":candidate.get("observation_focus",[])})
	for window: Variant in windows:
		if not window is Dictionary:continue
		var rect: Variant=window.get("rect")
		var focus: Variant=window.get("focus")
		if not rect is Array or rect.size()!=4 or not focus is Array or focus.size()!=2:continue
		var valid := true
		for value: Variant in rect+focus:
			if not (value is int or value is float) or not is_finite(float(value)):valid=false
		if valid and Rect2(rect[0],rect[1],rect[2],rect[3]).has_point(global_player_position()):return Vector2(focus[0],focus[1])
	return Vector2.INF

func area_label(area: Dictionary) -> String: return str(area.label)
func nearby_shortcut(_location: Vector2) -> String: return ""

func show_boss_reward_portal() -> void:
	_sign(reward_position+Vector2(-100,-90),"WARDEN CLEAR / INTERACT FOR MAP 2" if map_index == 1 else "QUEEN CLEAR / INTERACT FOR GOLD",Color("efd49a"))
	queue_redraw()

func _draw() -> void:
	if not assembly_ok: return
	if ForestBiblePresentation.enabled(generated.manifest):
		var camera := get_viewport().get_camera_2d()
		var center := camera.get_screen_center_position() if camera != null else bounds.get_center()
		var view_size := get_viewport_rect().size / camera.zoom if camera != null else get_viewport_rect().size
		ForestBiblePresentation.draw_background(self, generated.manifest, center, view_size, _forest_draw_clock)
	else:
		# Low-cost coherent silhouettes: gameplay supports are drawn by the assembler in front.
		draw_rect(bounds.grow(600),Color("142e2b"))
		for i: int in 14:
			var x := bounds.position.x+float(i)*bounds.size.x/13.0
			var sway := sin(_forest_draw_clock*0.35+float(i))*3
			draw_line(Vector2(x,bounds.end.y),Vector2(x+sway,bounds.position.y),Color("1c3930"),48+float(i%3)*20,true)
			for tier: int in 3:
				draw_circle(Vector2(x+sway,bounds.position.y+120+tier*380),100+float(i%3)*25,Color("1b3730"))
	for area: Dictionary in generated.manifest.areas:
		if area.role == "boss": continue
		var at := Vector2(area.position[0],area.position[1])
		if not generated.manifest.has("scene_language_version"):
			draw_arc(at+Vector2(0,70),160,PI,TAU,30,Color("254c3b"),25,true)
		if area.role == "merchant" and not ForestBiblePresentation.enabled(generated.manifest):
			draw_circle(at+Vector2(20,-42),38,Color("638063"))
			draw_circle(at+Vector2(20,-42),28,Color("203c2c"))
			draw_circle(at+Vector2(20,-35),6,Color("e8c97a"))
	if ForestBiblePresentation.enabled(generated.manifest):
		ForestBiblePresentation.draw_discoveries(self, generated.manifest, region_state, _forest_draw_clock)
	# Chests in both Bible and legacy backgrounds use the same dedicated layer.
	# Parent-stage draws never duplicate or grey the admitted tier recipe.
	for pickup: Dictionary in pickups:
		if pickup.claimed: continue
		var color := Color("e9c985") if pickup.kind == "coin" else Color("b8dc9a") if pickup.kind == "heart" else Color("ccb7ed")
		draw_circle(pickup.position,6,color)
	if reward_available:
		draw_circle(reward_position,24+sin(clock*3)*2,Color("d8bc77"),false,3,true)
