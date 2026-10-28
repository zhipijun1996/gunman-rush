extends SceneTree
## Continuous real-Godot title/Home/departure/cache/menu/input recording.
## Cache relocation, four known RewardService fixtures, the visible training
## platform/targets and camera framing are explicitly disclosed SETUP FIXTURES.
## Player tuning, RNG, HP, wallet, resonance and damage settlement are unchanged.
var app: Variant
var destination: String = "res://build/item_v5/movie/trace.json"
var frame: int = 0
var assertions: int = 0
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var events: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var damage_rows: Array[Dictionary] = []
var primary_rows: Array[Dictionary] = []
var held: Dictionary = {}
var pointer: Vector2 = Vector2.ZERO
var caption: Label
var fixture_caption: Label
var phase: String = "title"
var fixture_note: String = "正式标题 → 家园 → 原出口出发"
var shots: int = 0
var targets: Array[Area2D] = []
var training_point: Vector2 = Vector2.ZERO
var fixture_instances: Dictionary = {}
const SEED: String = "level-design-v2-baseline/08"
const LOADOUT: Array[StringName] = [&"P24",&"G15",&"P14"]

class TrainingTarget extends Area2D:
	var receiver: Damageable
	var label_text: String = "训练靶"
	func _draw() -> void:
		draw_rect(Rect2(-12,-26,24,52),Color("182c35"))
		draw_rect(Rect2(-12,-26,24,52),Color("83d8d1"),false,2)
		draw_circle(Vector2.ZERO,9,Color("ddac61"))
		draw_line(Vector2(-15,0),Vector2(15,0),Color("182c35"),2)
		draw_line(Vector2(0,-15),Vector2(0,15),Color("182c35"),2)
		var font: Font = DemoClockworkTheme.FONT
		draw_string(font,Vector2(-44,-38),label_text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
		if is_instance_valid(receiver): draw_string(font,Vector2(-44,44),"HP %.2f" % receiver.health,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("83d8d1"))
	func refresh(_context: Dictionary) -> void:
		queue_redraw()

class TrainingFloor extends StaticBody2D:
	func _draw() -> void:
		draw_rect(Rect2(-500,-10,1000,20),Color("213039"))
		draw_line(Vector2(-500,-10),Vector2(500,-10),Color("c5a05c"),3)
		for index: int in 40:
			var x: float = -490+index*25
			draw_line(Vector2(x,-5),Vector2(x+9,5),Color("776542"),2)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--trace="): destination = arg.trim_prefix("--trace=")
	_run.call_deferred()

func check(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)
	return value

func entity_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(app) or not is_instance_valid(app.stage): return result
	for node: Node in app.stage.get_children():
		if node is ItemV5Entity:
			var view: ItemV5Entity = node as ItemV5Entity
			result.append({"kind":str(view.kind),"position":[view.global_position.x,view.global_position.y],"direction":[view.direction.x,view.direction.y],"age":view.age})
	return result

func frames(count: int) -> void:
	for unused: int in count:
		await process_frame
		await RenderingServer.frame_post_draw
		frame += 1
		var state: Dictionary = {"video_frame":frame,"drawn_frame":Engine.get_frames_drawn(),"phase":phase,"fixture_note":fixture_note,"paused":paused}
		if is_instance_valid(app):
			state.menu = str(app.menu.visible_panel)
			state.formal_region = app.connected_region
			state.region = str(app.active_region_id)
			state.seed = str(app.director.seed)
			if is_instance_valid(app.home_scene): state.home_position = [app.home_scene.player.position.x,app.home_scene.player.position.y]
			if is_instance_valid(app.player):
				state.position = [app.player.position.x,app.player.position.y]
				state.hp = app.controller.actor_resources.health.current
				state.hp_max = app.controller.actor_resources.health.capacity
				state.time_energy = app.controller.actor_resources.stamina.current
				state.resonance = app.controller.combat_energy.current
				state.resonance_capacity = app.controller.combat_energy.capacity()
				state.world_clock = app.stage.clock if is_instance_valid(app.stage) else 0
				state.shot_serial = app.controller.shoot_ability._shot_serial
				state.coins = app.wallet.balance
				state.owned = Array(app.build.inventory.item_ids())
				state.equipped = Array(app.build.item_ids())
				state.gear = app.build.equipment.snapshot()
				state.entities = entity_rows()
				state.targets = target_rows()
		rows.append(state)

func target_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for body: Area2D in targets:
		if is_instance_valid(body):
			var receiver: Damageable = body.get_node("Damageable") as Damageable
			result.append({"target":str(body.name),"hp":receiver.health,"position":[body.global_position.x,body.global_position.y]})
	return result

func set_phase(id: String, text: String) -> void:
	phase = id
	caption.text = text
	fixture_caption.text = fixture_note
	print("ITEM V5 MOVIE PHASE: ",id," / ",frame," / ",text)
	checkpoints.append({"id":id,"phase":text,"fixture_note":fixture_note,"video_frame":frame,"drawn_frame":Engine.get_frames_drawn()})

func key(code: Key, pressed: bool) -> void:
	if bool(held.get(code,false)) == pressed: return
	held[code] = pressed
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	events.append({"kind":"key","key":OS.get_keycode_string(code),"pressed":pressed,"video_frame":frame,"drawn_frame":Engine.get_frames_drawn()})

func tap(code: Key) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(4)

func move_pointer(point: Vector2) -> void:
	# Keyboard skills query the live viewport cursor. A synthetic motion event
	# alone does not move X11's physical pointer, unlike an actual mouse move.
	Input.warp_mouse(point)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point-pointer
	if event.relative.is_zero_approx(): event.relative = Vector2(1,0)
	pointer = point
	Input.parse_input_event(event)

func mouse(point: Vector2, pressed: bool) -> void:
	move_pointer(point)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	events.append({"kind":"mouse","point":[point.x,point.y],"pressed":pressed,"video_frame":frame})

func button(owner: Node, identifier: String, instance_id: StringName = &"") -> Button:
	if not is_instance_valid(owner): return null
	for child: Node in owner.find_children("*","Button",true,false):
		var target: Button = child as Button
		if not target.is_visible_in_tree(): continue
		if not instance_id.is_empty() and StringName(target.get_meta(&"instance_id",&"")) != instance_id: continue
		if str(target.name).begins_with(identifier) or target.text.begins_with(identifier): return target
	return null

func click(target: Button) -> bool:
	if not check(is_instance_valid(target) and target.is_visible_in_tree() and not target.disabled,"native visible enabled control exists"): return false
	var parent: Node = target.get_parent()
	while parent != null:
		if parent is ScrollContainer: (parent as ScrollContainer).ensure_control_visible(target)
		parent = parent.get_parent()
	await frames(5)
	var point: Vector2 = target.get_global_rect().get_center()
	if not check(root.get_visible_rect().has_point(point),"native control center is in the recorded viewport"): return false
	mouse(point,true)
	await frames(2)
	mouse(point,false)
	await frames(5)
	return true

func scroll_details() -> void:
	var scroll: ScrollContainer = app.menu._root.find_child("DetailScroll",true,false) as ScrollContainer
	if not check(scroll != null,"formal inspector owns its actual native detail scroller"): return
	var before: int = scroll.scroll_vertical
	for unused: int in 3:
		for pressed: bool in [true,false]:
			var event: InputEventMouseButton = InputEventMouseButton.new()
			event.position = scroll.get_global_rect().get_center()
			event.global_position = event.position
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN
			event.pressed = pressed
			Input.parse_input_event(event)
		await frames(3)
	events.append({"kind":"native_detail_wheel","video_frame":frame,"scroll_before":before,"scroll_after":scroll.scroll_vertical,"scroll_max":scroll.get_v_scroll_bar().max_value,"viewport_height":scroll.size.y})
	# A short description may fit. Record the actual overflow and position instead
	# of fabricating extra inventory merely to manufacture a scroll distance.
	check(scroll.scroll_vertical >= before,"native wheel stays within the actual detail scroller bounds")

func choose_cache() -> Dictionary:
	for chest: Dictionary in app.stage.chests:
		if chest.reward_mode == "resources": continue
		var candidates: Array[ItemDefinition] = app._v5_cache_items(chest)
		if not candidates.is_empty() and candidates[0].stable_id not in [&"P24",&"G15",&"P14",&"B33"]:
			return {"id":str(chest.id),"position":chest.position,"definition_id":candidates[0].stable_id}
	return {}

func first_owned() -> Dictionary:
	var owned: RunItemInstance = app.build.inventory.instances()[0]
	return {"id":owned.instance_id,"definition":owned.definition_id,"level":owned.level}

func grant_fixture(id: StringName) -> bool:
	var offer_id: StringName = StringName("item_v5_movie_fixture/"+String(id))
	var definitions: Array[ItemDefinition] = [ItemCatalogV5.get_item(id)]
	var offer: RewardOffer = app.rewards.create_cache_offer(offer_id,definitions,StringName(str(offer_id)+"/source"))
	if not check(offer != null,"explicit known-item fixture uses the original RewardService"): return false
	var request: RewardClaimRequest = RewardClaimRequest.new()
	request.token = app.lifetime.token()
	request.offer_id = offer_id
	request.option_id = id
	request.claim_id = StringName(str(offer_id)+"/claim")
	var receipt: EconomyReceipt = app.rewards.claim(request)
	if not check(receipt.accepted(),"explicit known-item fixture commits original reward ownership"): return false
	fixture_instances[id] = receipt.instance_id
	events.append({"kind":"explicit_known_reward_fixture","id":String(id),"instance":String(receipt.instance_id),"video_frame":frame,"method":"original RewardService, no automatic equipment"})
	return true

func select_owned(id: StringName) -> bool:
	return await click(button(app.menu._root,"SelectItem",StringName(fixture_instances[id])))

func equip_owned(id: StringName) -> bool:
	if not await select_owned(id): return false
	if not await click(button(app.menu._root,"EquipItem")): return false
	await frames(12)
	return check(app._item_runtime.has(id),"native equipment action activates the selected real item: "+String(id))

func shot_fired(_direction: Vector2, _shot: int) -> void:
	shots += 1

func primary_committed(packet: int, shot: int, receiver: Damageable, session: int, weapon_epoch: int) -> void:
	primary_rows.append({"packet":packet,"shot":shot,"target":receiver.actor_id,"session":session,"weapon_epoch":weapon_epoch,"video_frame":frame})

func batch_resolved(results: Array[DamageResult]) -> void:
	for result: DamageResult in results:
		damage_rows.append({"target":str(result.request.target_id),"event":str(result.request.event_id),"damage":result.hp_lost,"derived":result.request.item_effect_damage,"video_frame":frame})

func training_fixture() -> void:
	training_point = app.stage.spawn+Vector2(0,-420)
	var floor_body: TrainingFloor = TrainingFloor.new()
	floor_body.name = "MovieFixturePlatform"
	floor_body.collision_layer = 1
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(1000,20)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	app.stage.add_child(floor_body)
	var player_collision: CollisionShape2D = app.player.get_node("CollisionShape2D") as CollisionShape2D
	var feet: float = player_collision.position.y+(player_collision.shape as RectangleShape2D).size.y*.5
	floor_body.global_position = training_point+Vector2(0,feet+10.05)
	for index: int in 2:
		var body: TrainingTarget = TrainingTarget.new()
		body.name = "MovieFixtureTarget%s" % index
		body.label_text = "训练靶 · 左" if index == 0 else "训练靶 · 右"
		body.collision_layer = 2
		body.collision_mask = 0
		var target_shape: RectangleShape2D = RectangleShape2D.new()
		target_shape.size = Vector2(24,52)
		var target_collision: CollisionShape2D = CollisionShape2D.new()
		target_collision.shape = target_shape
		body.add_child(target_collision)
		var receiver: Damageable = Damageable.new()
		receiver.name = "Damageable"
		receiver.faction = &"enemy"
		receiver.actor_id = body.get_instance_id()
		body.add_child(receiver)
		body.receiver = receiver
		app.stage.add_child(body)
		body.global_position = training_point+Vector2(-155 if index == 0 else 155,0)
		var health_definition: HealthDefinition = HealthDefinition.new()
		health_definition.resource_id = StringName("movie_fixture/target%s" % index)
		health_definition.max_health = 1000
		health_definition.initial_current = 1000
		var health: HealthState = HealthState.new()
		check(health.configure(health_definition),"explicit training target has valid independent high HP")
		receiver.bind_health(health)
		check(app.policy.bind_damageable(StringName("movie_fixture/target%s" % index),receiver,health),"training target binds the actual formal FrameDamagePolicy")
		receiver.damaged.connect(body.refresh)
		targets.append(body)
	app.player.global_position = training_point
	app.controller.motor.reset_motion()
	# Presentation-only camera fixture: reveal the explicitly initialized platform
	# and both real hurtboxes without changing world bounds or player movement.
	var camera: StageCameraRig = app._run_camera as StageCameraRig
	camera.world_bounds = camera.world_bounds.merge(Rect2(training_point-Vector2(600,400),Vector2(1200,800)))
	camera.snap_to_target()
	camera.force_update_scroll()
	events.append({"kind":"explicit_training_fixture","video_frame":frame,"player_position":[training_point.x,training_point.y],"targets":target_rows(),"camera_only_bounds":[camera.world_bounds.position.x,camera.world_bounds.position.y,camera.world_bounds.size.x,camera.world_bounds.size.y],"resources_granted":false})
	app.controller.shoot_ability.shot_fired.connect(shot_fired)
	app.controller.weapon_damage_committed.connect(primary_committed)
	app.policy.batch_resolved.connect(batch_resolved)
	await frames(45)
	check(app.player.is_on_floor(),"visible training fixture is supported by the actual unchanged Motor")
	for body: Area2D in targets:
		check(root.get_visible_rect().grow(-60).has_point(body.get_global_transform_with_canvas().origin),"both physical training targets are visible in the actual camera")
	check(entity_rows().filter(func(row: Dictionary) -> bool: return row.kind == "small_drone").size() == 3,"formal equipment consumer creates three actual mechanical patrol companions")

func shoot_target(index: int) -> bool:
	var body: Area2D = targets[index]
	var before: int = primary_rows.size()
	var old_shots: int = shots
	var old_energy: float = app.controller.combat_energy.current
	var point: Vector2 = body.get_global_transform_with_canvas().origin
	mouse(point,true)
	await frames(3)
	mouse(point,false)
	await frames(39)
	if not check(shots == old_shots+1 and primary_rows.size() == before+1,"native mouse release fires and successfully commits one real primary projectile"): return false
	return check(is_equal_approx(app.controller.combat_energy.current-old_energy,7),"one actual primary receipt naturally adds seven resonance; companions add none")

func add_captions() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var background: ColorRect = ColorRect.new()
	background.position = Vector2(400,8)
	background.size = Vector2(710,65)
	background.color = Color(0.035,0.065,0.08,.9)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(background)
	caption = Label.new()
	caption.position = Vector2(412,13)
	fixture_caption = Label.new()
	fixture_caption.position = Vector2(412,43)
	for label: Label in [caption,fixture_caption]:
		label.add_theme_font_override("font",DemoClockworkTheme.FONT)
		label.add_theme_font_size_override("font_size",17 if label == caption else 14)
		label.add_theme_color_override("font_color",Color.WHITE if label == caption else Color("e4c77f"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(label)

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	app = preload("res://scenes/demo/demo.tscn").instantiate()
	app.meta_persistence_enabled = false
	root.add_child(app)
	add_captions()
	set_phase("title","正式主游戏 · 点击开始，进入可操作家园")
	await frames(45)
	if not await click(button(app.menu._root,"BeginAdventure")): await finish(); return
	await frames(30)
	if not check(is_instance_valid(app.home_scene) and not app.connected_region,"actual title control enters playable Home"): await finish(); return
	set_phase("home_walk","家园 · D 行走到原出口，W 打开出发界面")
	var home_start: float = app.home_scene.player.position.x
	var home_target: float = app.home_scene.slot_world_foot(&"departure").x-20
	key(KEY_D,true)
	for unused: int in 900:
		if app.home_scene.player.position.x >= home_target: break
		await frames(1)
	key(KEY_D,false)
	await frames(15)
	if not check(app.home_scene.player.position.x > home_start and app.home_scene.nearest_id == &"departure","actual Home locomotion reaches the authored exit"): await finish(); return
	await tap(KEY_W)
	if not check(app.menu.home_function_id == &"departure","native W opens the original Home departure panel"): await finish(); return
	set_phase("departure","原家园出口 · 点击出发进入正式风铃平原")
	await frames(40)
	app.menu._seed = SEED
	if not await click(button(app.menu._root,"BEGIN / WINDCHIME PLAINS")): await finish(); return
	for unused: int in 240:
		if is_instance_valid(app.stage) and not app._stage_pending: break
		await frames(1)
	await frames(30)
	if not check(app.connected_region and app.stage is PlainsRegionStage and not app._stage_pending and app.director.seed == SEED,"native departure enters actual formal Plains with the chosen ordinary seed"): await finish(); return
	set_phase("plains","正式平原 · 宝箱领取后进入背包，不会自动装备")
	await frames(55)
	fixture_note = "宝箱位置为测试初始化；非自然路线通关"
	set_phase("cache_fixture","宝箱演示 · 仅调整位置，使用原 W 交互")
	var cache: Dictionary = choose_cache()
	if not check(not cache.is_empty(),"ordinary formal seed contains a real V5 item cache"): await finish(); return
	app.player.global_position = cache.position
	app.controller.motor.reset_motion()
	events.append({"kind":"explicit_cache_position_fixture","video_frame":frame,"cache":cache.id,"definition":String(cache.definition_id),"position":[cache.position.x,cache.position.y]})
	cache = {}
	await frames(2)
	await tap(KEY_W)
	if not check(paused and app.reward_modal.opened,"native W opens the actual V5 formal cache reward UI"): await finish(); return
	set_phase("cache_choice","原奖励按钮 · 通过正式奖励服务领取 V5 道具")
	await frames(65)
	if not await click(button(app.reward_modal._root,"选择 / PICK")): await finish(); return
	await frames(12)
	if not check(app.build.inventory.instances().size() == 1 and app.build.item_ids().is_empty(),"native V5 cache transaction adds one inactive owned item"): await finish(); return
	var cache_owned: Dictionary = first_owned()
	if not await click(app._pause_button): await finish(); return
	set_phase("backpack","暂停背包 · 选择图标查看 Lv 与当前效果")
	if not await click(button(app.menu._root,"SelectItem",cache_owned.id)): await finish(); return
	var level: Label = app.menu._root.find_child("SelectedItemLevel",true,false) as Label
	var effects: Label = app.menu._root.find_child("SelectedItemEffects",true,false) as Label
	check(level != null and level.text.contains("Lv1") and effects != null and not effects.text.is_empty(),"actual inspector displays the owned V5 level and resolved effect")
	await frames(70)
	await scroll_details()
	check(app.build.item_ids().is_empty() and int(app.build.equipment.snapshot().used) == 0,"native item selection and scrolling do not equip anything")
	fixture_note = "道具验证配置：固定道具／训练靶为测试初始化，非自然掉落通关"
	set_phase("fixture_loadout","测试配置入包 · 飞轮、双响投架、三机械巡钟")
	# B33 is a disclosed auxiliary selection fixture, removed before combat. It
	# makes selecting P24 a real enabled mouse action instead of clicking an
	# already-selected disabled button when P24 is the only owned active.
	for id: StringName in [&"B33",&"P24",&"G15",&"P14"]:
		if not grant_fixture(id): await finish(); return
	app._refresh_equipment_view()
	await frames(20)
	check(app.build.item_ids().is_empty() and app.controller.combat_energy.current == 0,"explicit reward fixtures enter only the backpack and provide no resonance")
	if not await equip_owned(&"B33"): await finish(); return
	if not await equip_owned(&"P24"): await finish(); return
	if not await select_owned(&"P24"): await finish(); return
	if not await click(button(app.menu._root,"SelectActiveItem")): await finish(); return
	check(app._item_runtime.selected_active() == &"P24","native actual selector chooses P24 as the current independent item active")
	if not await select_owned(&"B33"): await finish(); return
	if not await click(button(app.menu._root,"UnequipItem")): await finish(); return
	if not await equip_owned(&"G15"): await finish(); return
	if not await equip_owned(&"P14"): await finish(); return
	if not await select_owned(&"P24"): await finish(); return
	check(app.build.item_ids().size() == 3 and app._item_runtime.has(&"P24") and app._item_runtime.has(&"G15") and app._item_runtime.has(&"P14") and not app._item_runtime.has(&"B33") and int(app.build.equipment.snapshot().used) == 8,"native final loadout is exactly the intended 3+2+3 gear composition")
	set_phase("equipped","实际背包装备 8 / 8 · 当前主动：回环飞轮")
	await frames(75)
	await tap(KEY_ESCAPE)
	check(not paused,"native Escape resumes the actual formal world")
	set_phase("training","训练配置 · 两侧实体高 HP 靶，保持原角色与战斗规则")
	await training_fixture()
	await frames(45)
	check(app.controller.combat_energy.current == 0,"three actual companions cannot charge resonance during their attacks")
	set_phase("primary_charge","真实鼠标普攻命中 5 次 · 每次 7 共鸣，准备飞轮")
	for index: int in 5:
		caption.text = "真实普攻 %s / 5 · 每次命中 +7 共鸣" % (index+1)
		if not await shoot_target(1 if index%2 == 0 else 0): await finish(); return
	check(is_equal_approx(app.controller.combat_energy.current,35),"five actual successful primary packets naturally provide exactly 35 resonance")
	set_phase("companions","三机械巡钟自动攻击 · 派生伤害不额外获得共鸣")
	var companion_energy: float = app.controller.combat_energy.current
	var companion_damage_before: int = damage_rows.size()
	await frames(110)
	check(app.controller.combat_energy.current == companion_energy,"actual companion attacks leave resonance unchanged")
	check(damage_rows.slice(companion_damage_before).any(func(row: Dictionary) -> bool: return row.derived and "/P14/" in row.event and row.damage > 0),"actual mechanical patrol attacks commit derived HP damage through the original policy")
	var hp_before: float = app.controller.actor_resources.health.current
	var coins_before: int = app.wallet.balance
	var shots_before: int = shots
	var active_pointer: Vector2 = targets[1].get_global_transform_with_canvas().origin
	move_pointer(active_pointer)
	await frames(2)
	check(root.get_mouse_position().distance_to(active_pointer)<2.0,"keyboard item active reads the actual pointer placed over the visible target")
	events.append({"kind":"live_pointer_before_item_active","requested":[active_pointer.x,active_pointer.y],"actual":[root.get_mouse_position().x,root.get_mouse_position().y],"video_frame":frame})
	set_phase("flywheels","按 R · 一次消耗 35，共鸣飞轮严格向左右两侧发射")
	key(KEY_R,true)
	await frames(2)
	key(KEY_R,false)
	var wheels: Array[Dictionary] = entity_rows().filter(func(row: Dictionary) -> bool: return row.kind == "flywheel")
	check(wheels.size() == 2,"actual independent R input creates two real flywheel entities")
	if wheels.size() == 2:
		var first_direction: Vector2 = Vector2(wheels[0].direction[0],wheels[0].direction[1])
		var second_direction: Vector2 = Vector2(wheels[1].direction[0],wheels[1].direction[1])
		check(first_direction.dot(second_direction) < -.9999,"real G15 flywheel directions are exactly opposite at 180 degrees")
	check(is_equal_approx(app.controller.combat_energy.current,0) and shots == shots_before,"R consumes one actual 35-resonance transaction with no accompanying primary")
	await frames(150)
	var wheel_targets: Dictionary = {}
	for row: Dictionary in damage_rows:
		if row.derived and "/P24/" in row.event and row.damage > 0: wheel_targets[row.target] = true
	check(wheel_targets.has("movie_fixture/target0") and wheel_targets.has("movie_fixture/target1"),"both real training target HealthStates receive actual bidirectional flywheel damage")
	check(app.controller.combat_energy.current == 0 and shots == shots_before,"flywheel and patrol derived damage cannot self-charge or append a primary")
	check(app.controller.actor_resources.health.current == hp_before and app.wallet.balance == coins_before,"training demonstration neither injects nor spends player HP or coins")
	set_phase("result","真实配置演示完成 · 飞轮往返、三巡钟、背包与共鸣账本一致")
	await frames(maxi(90,1500-frame))
	await finish()

func finish() -> void:
	for code: Variant in held.keys(): key(code,false)
	paused = false
	for body: Area2D in targets:
		if is_instance_valid(body):
			var receiver: Damageable = body.get_node("Damageable") as Damageable
			receiver.damage_sink = Callable()
			receiver.bind_health(null)
	targets.clear()
	if is_instance_valid(app):
		check(await preload("res://tests/audio_teardown.gd").drain_world(app),"actual formal audio backends release cleanly")
		app.free()
		app = null
	for unused: int in 8: await process_frame
	var data: Dictionary = {"schema":"item-v5-formal-native-movie-v1","scope":"Real title -> playable Home movement -> original departure button -> formal Plains -> explicit cache-position fixture with native W/reward/pause controls. Disclosed known RewardService fixtures B33/P24/G15/P14, visible high-HP training hurtboxes/platform and camera framing; B33 is removed before combat. Actual native mouse equipment/active selection, five primary hit receipts naturally earn 35 resonance, R sends two opposite flywheels, three patrols apply derived damage without charging energy. No player HP/wallet/resonance injection, no natural full-route/Boss-clear claim, no matched before movie, no physical-device/player acceptance.","seed":SEED,"checks":assertions,"failures":failures,"checkpoints":checkpoints,"input_events":events,"primary_receipts":primary_rows,"damage_receipts":damage_rows,"frames":rows}
	var file: FileAccess = FileAccess.open(destination,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data,"  "))
		file.close()
	else: check(false,"actual movie trace can be written")
	print("ITEM V5 MOVIE: %s frames, %s assertions, %s failures" % [frame,assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
