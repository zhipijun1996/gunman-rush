extends Node2D
## Isolated A/B composition consumer. Real Motor, Router, projectiles, damage,
## shot energy, one-way platforms and ShotLatch; no campaign/save promotion.
const REVIEW_SEED := "plains-golden-01/review-01"
const PLAYER := preload("res://scenes/player/player.tscn")
const ENEMY := preload("res://scenes/enemies/patrol_drone.tscn")
var candidate := "A"
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var camera: StageCameraRig
var latch: ShotLatch
var enemy: EnemyMotor
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var segment: SegmentRespawn
var wallet: RunWallet
var hud: ActorResourcesHud
var caption: Label
var status: Label
var reward: Sprite2D
var chest_position := Vector2.ZERO
var finish_position := Vector2.ZERO
var claimed := false
var reached_finish := false
var changing := false
var ticks := 0
var events: Array[Dictionary] = []
var solids: Array[Rect2] = []
var bridges: Array[Rect2] = []
var _spawn := Vector2(80,462)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if get_tree().get_first_node_in_group(&"game_audio") == null:
		add_child(GameAudio.new())
	var backdrop := UnderworldParallax.new()
	backdrop.name = "SharedUnderworldParallax"
	add_child(backdrop)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(14,10)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size",16)
	column.add_child(caption)
	var row := HBoxContainer.new()
	column.add_child(row)
	for choice: String in ["A","B"]:
		var button := Button.new()
		button.text = "A · BROKEN BRIDGE" if choice == "A" else "B · RETURN GANTRY"
		button.pressed.connect(launch.bind(choice))
		row.add_child(button)
	var retry := Button.new()
	retry.text = "NEW ATTEMPT"
	retry.pressed.connect(func() -> void: launch(candidate))
	row.add_child(retry)
	var pause := Button.new()
	pause.text = "PAUSE / RESUME"
	pause.pressed.connect(toggle_pause)
	row.add_child(pause)
	status = Label.new()
	status.position = Vector2(16,660)
	status.add_theme_font_size_override("font_size",15)
	layer.add_child(status)
	hud = ActorResourcesHud.new()
	hud.position = Vector2(0,40)
	layer.add_child(hud)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--candidate=B": candidate = "B"
	launch.call_deferred(candidate)

func launch(choice: String) -> void:
	if changing or choice not in ["A","B"]: return
	changing = true
	get_tree().paused = false
	hud.unbind()
	if is_instance_valid(world):
		controller.router.clear("candidate_unload")
		controller.air_focus_ability.stop()
		controller.shoot_ability.clear_projectiles()
		latch.cancel()
		lifetime.end()
		remove_child(world)
		world.queue_free()
		await get_tree().process_frame
	candidate = choice
	ticks = 0
	events.clear()
	claimed = false
	reached_finish = false
	wallet = RunWallet.new()
	lifetime = DemoLifetime.new()
	world = Node2D.new()
	world.name = "Candidate"+choice
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.set_meta("underworld_formal_style",true)
	add_child(world)
	solids.assign([Rect2(0,480,320,512),Rect2(320,528,96,464),Rect2(416,576,144,416),Rect2(496,496,64,496),Rect2(560,416,640,576)])
	bridges.clear()
	if choice == "A":
		solids.append(Rect2(880,336,320,656))
		chest_position = Vector2(1104,318)
		finish_position = Vector2(736,398)
	else:
		bridges.append(Rect2(320,304,528,12))
		chest_position = Vector2(384,286)
		finish_position = Vector2(1104,398)
	for rect: Rect2 in solids: _body(rect,false)
	for rect: Rect2 in bridges: _body(rect,true)
	world.add_child(UnderworldTerrain.build(solids))
	var wood := GantryArt.new()
	wood.bridge_rects = bridges.duplicate()
	world.add_child(wood)
	var scenery := UnderworldScenery.new()
	world.add_child(scenery)
	var protected: Array[Rect2] = [Rect2(200,240,720,360)]
	scenery.configure_geometry(solids,protected,REVIEW_SEED,{})
	player = PLAYER.instantiate() as PlayerMotor
	player.position = _spawn # Initial creation before first Motor step only.
	player.z_index = 5
	world.add_child(player)
	controller = player.get_node("Controller") as PlayerController
	if not controller.enable_shot_energy():
		push_error("Candidate requires original formal shot energy")
		return
	var art := UnderworldPlayer.new()
	art.motor = player
	art.controller = controller
	art.name = "PixelPlainsActor"
	player.add_child(art)
	player.get_node("PlayerVisualAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	(player.get_node("CourierVisual") as CanvasItem).hide()
	(player.get_node("PlayerFeedback") as CanvasItem).hide()
	var overlay := InputSetup.attach(player,controller.router)
	overlay.hide_reset_button = true
	overlay.pause_requested.connect(toggle_pause)
	overlay.reset_requested.connect(toggle_pause)
	var aim := DemoAimGuide.new()
	aim.controller = controller
	player.add_child(aim)
	var vignette := FocusVignette.new()
	vignette.ability = controller.air_focus_ability
	player.add_child(vignette)
	camera = StageCameraRig.new()
	camera.viewing_zoom = 1.6
	world.add_child(camera)
	camera.configure(player,Rect2(-100,-100,1500,1100))
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	world.add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	policy.register_player_controller(controller)
	policy.player_fatal.connect(_died)
	policy.environment_return_requested.connect(_environment_return)
	policy.batch_resolved.connect(_damage_committed)
	policy.protect_player()
	segment = SegmentRespawn.new()
	segment.configure(controller,lifetime)
	segment.add_anchor(&"entry",_spawn)
	latch = ShotLatch.new()
	latch.name = "AcceptedProjectileBell"
	latch.link_id = "RETURN" if choice == "B" else "CROSS"
	latch.prompt_text = "SHOOT / RECOIL TO THE HIGH ROUTE"
	world.add_child(latch)
	latch.setup(controller,lifetime,Vector2(360,460) if choice == "A" else Vector2(800,380),Rect2(1008,224,16,112) if choice == "A" else Rect2(464,192,16,112))
	latch.set_region_presentation(true)
	latch.opened.connect(func() -> void: _event("bell_opened",{"open_count":latch.open_count}))
	enemy = ENEMY.instantiate() as EnemyMotor
	enemy.position = Vector2(680,280) if choice == "A" else Vector2(1040,280)
	var actor := enemy.get_node("Actor") as EnemyActor
	actor.definition = preload("res://resources/enemies/plains_diver.tres")
	world.add_child(enemy)
	UnderworldActors.install(world)
	policy.bind_damageable(&"courier_intercept",actor.damageable,actor.health)
	var safe: Array[Vector2] = [_spawn,Vector2(464,558)]
	actor.bind_encounter(controller,policy,lifetime,&"courier_intercept",safe)
	var contact := DemoContactEmitter.new()
	contact.policy = policy
	contact.controller = controller
	contact.source_id = &"courier_intercept_contact"
	contact.half_size = actor.definition.collision_size/2.0+Vector2.ONE
	enemy.add_child(contact)
	var fall := DemoContactEmitter.new()
	fall.policy = policy
	fall.controller = controller
	fall.source_id = &"candidate_fall_plane"
	fall.kind = DamageRequest.Kind.ENVIRONMENT
	fall.half_size = Vector2(2000,30)
	fall.position = Vector2(600,950)
	fall.fall_plane = true
	world.add_child(fall)
	reward = Sprite2D.new()
	UnderworldObjects.place_chest(reward,chest_position+Vector2(0,18),false)
	world.add_child(reward)
	var flag := Sprite2D.new()
	flag.texture = UnderworldActors.icon_texture(&"door")
	flag.position = finish_position-Vector2(0,20)
	flag.scale = Vector2.ONE*44.0/flag.texture.get_height()
	world.add_child(flag)
	controller.jump_ability.jumped.connect(func() -> void: _event("jump_accepted"))
	controller.landed.connect(func() -> void: _event("landed"))
	controller.shoot_ability.shot_fired.connect(_shot_accepted)
	controller.shoot_ability.shot_rejected.connect(func(reason: StringName) -> void: _event("shot_rejected",{"reason":String(reason)}))
	controller.interact_requested.connect(_interact)
	hud.bind(controller.actor_resources,controller.air_focus_ability,controller)
	hud.set_region_compact(true)
	caption.text = "PLAINS · %s · %s  |  DEV / SESSION ONLY" % [choice,"cross then climb" if choice == "A" else "shoot ahead, recoil back"]
	await get_tree().physics_frame
	if not segment.activate_anchor(&"entry"):
		push_error("Candidate entry lacks real support")
	changing = false
	_event("candidate_ready",{"seed":REVIEW_SEED,"abilities":[],"initial_fixture_spawn_override":false})
	print("PLAINS_GOLDEN_READY candidate=",candidate," seed=",REVIEW_SEED," motor=PlayerMotor abilities=[]")

func _body(rect: Rect2,one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.one_way_collision = one_way
	if one_way: body.add_to_group("one_way_platform")
	body.add_child(shape)
	world.add_child(body)

func _physics_process(_delta: float) -> void:
	if changing or not is_instance_valid(controller) or get_tree().paused: return
	ticks += 1
	if not reached_finish and player.position.distance_to(finish_position)<40 and player.is_on_floor():
		reached_finish = true
		_event("main_route_reached")
	status.text = "A/D move · hold Space jump · aim + release mouse shoot · W interact | %s | Bell %s · cache %s · coins %d" % ["PAUSED" if get_tree().paused else "Main exit reached" if reached_finish else "Find the door; optional cache returns to entry", "OPEN" if latch.is_open else "closed", "claimed" if claimed else "optional",wallet.balance]
	if not controller.active: status.text = "Attempt ended · NEW ATTEMPT restarts this isolated candidate"

func _event(kind: String,extra: Dictionary = {}) -> void:
	var row := {"tick":ticks,"kind":kind,"candidate":candidate,"position":[player.position.x,player.position.y]}
	row.merge(extra)
	events.append(row)

func _shot_accepted(direction: Vector2,id: int) -> void:
	_event("shot_accepted",{"shot_id":id,"direction":[direction.x,direction.y],"energy":controller.actor_resources.stamina.current})
	for projectile: PlayerProjectile in controller.shoot_ability.get_projectiles():
		if projectile.shot_id == id and projectile.get_node_or_null("PixelPlainsProjectile") == null:
			var art := PixelPlainsProjectile.new()
			art.name = "PixelPlainsProjectile"
			projectile.add_child(art)

func _damage_committed(results: Array[DamageResult]) -> void:
	for result: DamageResult in results:
		_event("damage_committed",{"target":String(result.request.target_id),"event_id":String(result.request.event_id),"lethal":result.lethal})

func _interact() -> void:
	if not controller.active or claimed or player.position.distance_to(chest_position)>64: return
	if wallet.grant(6,&"plains_golden_cache"):
		claimed = true
		UnderworldObjects.place_chest(reward,chest_position+Vector2(0,18),true)
		_event("cache_claimed",{"coins":wallet.balance})
		GameAudio.cue(self,&"coin")

func _environment_return() -> void:
	if segment.return_to_anchor(): _event("environment_return")
	else: push_error("No safe candidate return anchor")

func _died() -> void:
	controller.die()
	_event("player_died")

func toggle_pause() -> void:
	if changing or not is_instance_valid(controller): return
	controller.router.clear("preview_pause")
	controller.air_focus_ability.stop()
	get_tree().paused = not get_tree().paused
	_event("pause",{"paused":get_tree().paused})

func snapshot() -> Dictionary:
	var actor := enemy.get_node("Actor") as EnemyActor
	return {"candidate":candidate,"seed":REVIEW_SEED,"tick":ticks,"position":[player.position.x,player.position.y],"grounded":player.is_on_floor(),"health":controller.actor_resources.health.current,"energy":controller.actor_resources.stamina.current,"air_shots":controller.action_resources.shot_charges,"jumps":controller.jump_ability.used_jumps,"bell_open":latch.is_open,"bell_open_count":latch.open_count,"enemy_hp":actor.health.current,"cache_claimed":claimed,"coins":wallet.balance,"main_route_reached":reached_finish,"events":events.duplicate(true),"capabilities":{"grapple":controller.traversal.hook_enabled,"wall":controller.traversal.wall_enabled,"double_jump":controller.traversal.double_enabled},"camera_center":[camera.get_screen_center_position().x,camera.get_screen_center_position().y],"zoom":camera.zoom.x,"formal_campaign_integration":false}

class GantryArt extends Node2D:
	var bridge_rects: Array[Rect2] = []
	func _ready() -> void:
		z_index = -2
	func _draw() -> void:
		for rect: Rect2 in bridge_rects:
			# Noncolliding thin supports recede behind the playable deck.
			UnderworldTerrain.draw_mechanism_beam(self,Rect2(576,rect.end.y,8,416-rect.end.y),.55)
			UnderworldTerrain.draw_mechanism_beam(self,Rect2(816,rect.end.y,8,416-rect.end.y),.55)
			UnderworldTerrain.draw_mechanism_beam(self,rect)
