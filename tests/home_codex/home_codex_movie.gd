extends "res://tests/item_v5_movie.gd"
## Continuous actual DemoApp/Home/menu/input proof. Known B11 RewardService
## ownership,50notes and two Home positions are disclosed setup fixtures.
## Never writes discovery/unlock/selection/HP or emits UI/economy signals.
const DISCLOSURE := "已知B11/音符50/家园站位为测试初始化，非自然掉落"
var ownership_receipts: Array[Dictionary] = []
var profile_steps: Array[Dictionary] = []
var delivery: Dictionary = {}
var fixture_notes: Dictionary = {}
var first_run: String = ""
var second_run: String = ""

func add_captions() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var backing: ColorRect = ColorRect.new()
	backing.position = Vector2(18,650)
	backing.size = Vector2(1244,66)
	backing.color = Color(.025,.045,.055,.94)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(backing)
	caption = Label.new()
	caption.position = Vector2(30,653)
	fixture_caption = Label.new()
	fixture_caption.position = Vector2(30,684)
	for label: Label in [caption,fixture_caption]:
		label.add_theme_font_override("font",DemoClockworkTheme.FONT)
		label.add_theme_font_size_override("font_size",19 if label == caption else 14)
		label.add_theme_color_override("font_color",Color.WHITE if label == caption else Color("e4c77f"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(label)

func frames(count: int) -> void:
	for unused: int in count:
		await super.frames(1)
		if rows.is_empty() or not is_instance_valid(app): continue
		rows[-1].meta = app.meta.snapshot()
		rows[-1].director_state = app.director.state
		rows[-1].run_id = app._run_receipt_prefix
		rows[-1].codex_opened = is_instance_valid(app._home_codex) and app._home_codex.opened
		if is_instance_valid(app.home_scene):
			rows[-1].home_nearest = str(app.home_scene.nearest_id)
			rows[-1].home_grounded = app.home_scene.player.is_on_floor()
			rows[-1].home_input_blocked = app.home_scene.input_blocked
		if rows[-1].codex_opened:
			rows[-1].codex_focused = str(app._home_codex._focused_id)
			rows[-1].codex_selected = str(app._home_codex._selected_id)
			rows[-1].codex_revision = app._home_codex._profile_revision
		if is_instance_valid(app.controller):
			rows[-1].shot_serial = app.controller.shoot_ability._shot_serial
			rows[-1].inventory = inventory_rows()

func _start_transition(id: String, text: String) -> void:
	# The original completed/display checkpoints stay unchanged. Actual pointer,
	# pause and lifecycle actions may change state over several recorded frames.
	# Label those frames as transitions rather than the preceding stable state.
	phase = id
	caption.text = text
	fixture_caption.text = fixture_note
	events.append({"kind":"phase_transition_started","id":id,"video_frame":frame,"drawn_frame":Engine.get_frames_drawn()})

func inventory_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if app.build == null: return result
	for item: RunItemInstance in app.build.inventory.instances():
		result.append({"id":str(item.definition_id),"instance":str(item.instance_id),"source":str(item.source_id),"level":item.level,"equipped":item.instance_id in app.build.equipment.equipped_ids()})
	return result

func _ownership_committed(receipt: EconomyReceipt) -> void:
	ownership_receipts.append({"status":receipt.status,"event_id":str(receipt.event_id),"item_id":str(receipt.item_id),"instance_id":str(receipt.instance_id),"run_id":app._run_receipt_prefix,"video_frame":frame,"drawn_frame":Engine.get_frames_drawn(),"meta_after_original_observer":app.meta.snapshot()})

func record_profile(label: String) -> void:
	var receipts: Dictionary = {}
	for id: String in app.meta._receipts:
		var payload: Dictionary = app.meta._receipts[id]
		if payload.get("kind","") in ["notes","item_discovery","home_unlock","home_select"]: receipts[id] = payload.duplicate(true)
	profile_steps.append({"label":label,"video_frame":frame,"drawn_frame":Engine.get_frames_drawn(),"snapshot":app.meta.snapshot(),"actual_backend_receipts":receipts})

func pose_home(id: StringName) -> bool:
	if not check(is_instance_valid(app.home_scene) and not app.home_scene.input_blocked,"real Home is unblocked before disclosed position initialization"): return false
	var foot: Vector2 = app.home_scene.slot_world_foot(id)
	if not check(foot.is_finite(),"original Home service has an authored foot: "+str(id)): return false
	app.home_scene.player.position = foot-Vector2(0,18.1)
	app.home_scene.controller.motor.reset_motion()
	events.append({"kind":"explicit_home_position_fixture","slot":str(id),"position":[foot.x,foot.y-18.1],"video_frame":frame,"method":"one initial actor position at existing original service; no HP/abilities/currency mutation"})
	await frames(18)
	return check(app.home_scene.player.is_on_floor() and app.home_scene.nearest_id == id,"original Home motor settles on the real service floor: "+str(id))

func native_codex_button(name: String) -> bool:
	if not check(is_instance_valid(app._home_codex) and app._home_codex.opened,"actual codex is open for native "+name): return false
	return await click(button(app._home_codex,name))

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	fixture_note = DISCLOSURE
	app = preload("res://scenes/demo/demo.tscn").instantiate()
	app.meta_persistence_enabled = false
	root.add_child(app)
	add_captions()
	if not check(app.start_plains(SEED),"original DemoApp starts actual formal Plains for the known reward demonstration"): await finish(); return
	for unused: int in 180:
		if is_instance_valid(app.stage) and not app._stage_pending: break
		await frames(1)
	await frames(24)
	first_run = app._run_receipt_prefix
	check(app.meta.snapshot().discovered_items.is_empty() and app.meta.snapshot().unlocked_home_items.is_empty(),"isolated memory-only fixture starts with no discovered or unlocked items")
	fixture_notes = app.meta.grant_notes(50,&"home_codex_movie/explicit_notes50")
	if not check(bool(fixture_notes.get("accepted",false)) and int(app.meta.snapshot().notes) == 50,"explicit50note fixture uses the original notes transaction, once"): await finish(); return
	events.append({"kind":"explicit_notes_fixture","amount":50,"receipt":"home_codex_movie/explicit_notes50","video_frame":frame,"method":"original MetaProgression.grant_notes; isolated memory-only profile"})
	set_phase("formal_known_reward","正式平原 · 已知奖励样本B11，非自然随机掉落")
	await frames(60)
	app.rewards.claimed.connect(_ownership_committed)
	if not grant_fixture(&"B11"): await finish(); return
	app.item_toast.show_item(ItemCatalogV5.get_item(&"B11"),1)
	if not check(app.build.inventory.instances().size() == 1 and app.build.item_ids().is_empty(),"actual committed known reward enters inactive inventory"): await finish(); return
	if not check("B11" in app.meta.snapshot().discovered_items and app.meta.snapshot().unlocked_home_items.is_empty(),"original acquisition observer discovers B11 without unlocking it"): await finish(); return
	record_profile("discovered_from_committed_reward")
	set_phase("reward_committed","正式奖励已入包 · 自动记录发现，尚未永久解锁")
	await frames(120)
	_start_transition("transition_reward_to_journey","打开原暂停旅途页，准备返回家园")
	await tap(KEY_ESCAPE)
	if not await click(button(app.menu._root,"PausePage")): await finish(); return
	set_phase("return_home","原旅途菜单 · 结束本局后返回真实家园")
	await frames(45)
	_start_transition("transition_journey_to_home","原结束/确认按钮处理 · 等待真实家园")
	if not await click(button(app.menu._root,"LeaveAdventure")): await finish(); return
	await frames(30)
	if not await click(button(app.menu._root,"LEAVE RUN")): await finish(); return
	for unused: int in 180:
		if is_instance_valid(app.home_scene) and app.menu.visible_panel == &"run_end": break
		await frames(1)
	if not await click(button(app.menu._root,"ENTER HOME")): await finish(); return
	if not await pose_home(&"relics"): await finish(); return
	set_phase("home_relics","真实家园遗物台 · W打开道具图鉴")
	await frames(60)
	_start_transition("transition_home_to_unknown","原W打开图鉴，选择未发现条目")
	await tap(KEY_W)
	if not check(is_instance_valid(app._home_codex) and app._home_codex.opened and paused and app.home_scene.input_blocked,"original relics W opens the real blocking Home codex"): await finish(); return
	if not await native_codex_button("CodexTile_B03"): await finish(); return
	if not check(app._home_codex.find_child("CodexUnknownDetail",true,false) != null and app._home_codex.find_child("CodexDetailCard",true,false) == null,"other undiscovered item remains? without identity/effects"): await finish(); return
	set_phase("unknown","其他道具仍显示? · 仅实际获得的B11已发现")
	await frames(90)
	_start_transition("transition_unknown_to_discovered","选择已发现B11 · 等待实际详情刷新")
	if not await native_codex_button("CodexTile_B11"): await finish(); return
	var detail: ItemCard = app._home_codex.find_child("CodexDetailCard",true,false) as ItemCard
	if not check(detail != null and detail.item.stable_id == &"B11" and detail.level == 1,"actual discovered B11 detail reuses its original Lv1 ItemCard"): await finish(); return
	set_phase("discovered","B11已发现 · 独立图标、齿轮和Lv1效果")
	await frames(105)
	var quote: Dictionary = app.meta.home_item_quote(&"B11")
	var price: int = int(quote.price)
	var before_notes: int = int(app.meta.snapshot().notes)
	_start_transition("transition_discovered_to_unlocked","点击永久解锁 · 等待正式音符交易")
	if not await native_codex_button("CodexUnlock"): await finish(); return
	if not check(bool(app.meta.home_item_quote(&"B11").unlocked) and int(app.meta.snapshot().notes) == before_notes-price,"actual native unlock commits configured permanent-note price exactly once"): await finish(); return
	record_profile("native_unlock")
	delivery.unlock_price = price
	delivery.notes_before = before_notes
	delivery.notes_after = app.meta.snapshot().notes
	set_phase("unlocked","永久解锁完成 · 音符 %s → %s，扣除配置价格%s" % [before_notes,app.meta.snapshot().notes,price])
	await frames(120)
	_start_transition("transition_unlocked_to_selected","选择下次携带 · 等待正式档案提交")
	if not await native_codex_button("CodexSelect"): await finish(); return
	if not check(app.meta.snapshot().selected_home_item == "B11" and int(app.meta.snapshot().notes) == before_notes-price,"native carry selection chooses one item without another charge"): await finish(); return
	record_profile("native_select_carry")
	set_phase("selected","已选择B11 · 每局1件Lv1，出发后入包仍需装备")
	await frames(105)
	_start_transition("transition_selected_to_departure","关闭图鉴，回到原家园出发点")
	if not await native_codex_button("CodexClose"): await finish(); return
	if not check(not app._home_codex.opened and not paused and not app.home_scene.input_blocked,"native codex close releases Home input"): await finish(); return
	if not await pose_home(&"departure"): await finish(); return
	set_phase("departure","原家园出口 · 新一局将携带1件Lv1道具")
	await frames(60)
	_start_transition("transition_departure_to_new_run","原W/出发按钮处理 · 等待新局背包")
	await tap(KEY_W)
	if not check(app.menu.home_function_id == &"departure","actual original Home W opens departure"): await finish(); return
	app.menu._seed = SEED
	if not await click(button(app.menu._root,"BEGIN / WINDCHIME PLAINS")): await finish(); return
	for unused: int in 180:
		if is_instance_valid(app.stage) and not app._stage_pending: break
		await frames(1)
	await frames(18)
	second_run = app._run_receipt_prefix
	if not check(second_run != first_run and app.connected_region and app.stage is PlainsRegionStage,"actual Home departure creates a new formal run"): await finish(); return
	var owned: RunItemInstance = app.build.inventory.instance_for_definition(&"B11")
	if not check(owned != null and owned.level == 1 and app.build.inventory.instances().size() == 1 and app.build.item_ids().is_empty(),"new run contains exactly one inactive Lv1 Home carry instance"): await finish(); return
	if not check(String(owned.source_id).begins_with("home_carry/") and String(owned.instance_id) != str(fixture_instances[&"B11"]),"new Home carry has its own real source and stable instance identity"): await finish(); return
	fixture_instances[&"B11"] = owned.instance_id
	delivery.carry = inventory_rows()
	delivery.run_manifest = app.director.manifest.snapshot()
	var health: HealthState = app.controller.actor_resources.health
	var current_before: float = health.current
	if not check(health.capacity == 5 and current_before == 5,"new run's actual un-equipped baseline is5HP"): await finish(); return
	set_phase("carried_in_bag","新局B11已入背包、未装备 · 当前生命5 / 上限5")
	await frames(90)
	_start_transition("transition_carry_to_backpack","原暂停按钮打开背包，选择B11")
	await tap(KEY_ESCAPE)
	if not await select_owned(&"B11"): await finish(); return
	set_phase("backpack","暂停背包 · B11 Lv1在背包中，尚未生效")
	await frames(90)
	_start_transition("transition_backpack_to_equipped","点击装备 · 等待原子装备提交")
	if not await click(button(app.menu._root,"EquipItem")): await finish(); return
	await frames(12)
	if not check(health.capacity == 6 and health.current == current_before and app.build.item_ids() == [&"B11"],"native equip raises maxHP5to6 without any free currentHP heal"): await finish(); return
	delivery.base_hp_max = 5
	delivery.equipped_hp_max = health.capacity
	delivery.equipped_hp_current = health.current
	set_phase("equipped","装备生效 · 生命上限5 → 6，当前HP仍5，不免费回血")
	await frames(150)
	_start_transition("transition_equipped_to_removed","点击卸下 · 等待效果撤销提交")
	if not await click(button(app.menu._root,"UnequipItem")): await finish(); return
	await frames(12)
	if not check(health.capacity == 5 and health.current == current_before and app.build.item_ids().is_empty(),"native removal retracts maxHP6to5 and preserves actualHP"): await finish(); return
	delivery.removed_hp_max = health.capacity
	delivery.removed_hp_current = health.current
	set_phase("removed","卸下撤销效果 · 生命上限6 → 5，道具仍留在背包")
	await frames(150)
	var shots_before: int = app.controller.shoot_ability._shot_serial
	_start_transition("transition_removed_to_result","关闭背包恢复玩法 · 检查无误射")
	await tap(KEY_ESCAPE)
	await frames(8)
	check(not paused and app.controller.shoot_ability._shot_serial == shots_before,"closing real inventory cannot leak a primary shot")
	record_profile("final_permanent_state")
	set_phase("result","永久解锁/携带保留 · 本局装备与效果仍独立管理")
	await frames(45)
	await finish()

func finish() -> void:
	for code: Variant in held.keys(): key(code,false)
	paused = false
	var final_meta: Dictionary = app.meta.snapshot() if is_instance_valid(app) else {}
	if is_instance_valid(app):
		check(await preload("res://tests/audio_teardown.gd").drain_world(app),"actual original game audio backends release cleanly")
		app.free()
		app = null
	ItemArtLibrary.clear_cache()
	for unused: int in 8: await process_frame
	var data: Dictionary = {"schema":"home-codex-native-movie-v1","scope":"Continuous original formal RewardService B11 known acquisition and toast (explicit fixture, not RNG drop), original pause/journey/end/Home/relicsW/codex native UI unlock and carry, original Home departure into a new formal run, Lv1inactivebag/nativeequip/nativeunequip.50notes and two existing Home service positions are explicitly initialized; no direct discovery/unlock/select/HP writes. Memory-only isolated profile, no physical device/listening or natural traversal claim.","fixture_note":DISCLOSURE,"seed":SEED,"checks":assertions,"failures":failures,"checkpoints":checkpoints,"input_events":events,"ownership_receipts":ownership_receipts,"profile_steps":profile_steps,"notes_fixture_result":fixture_notes,"first_run":first_run,"second_run":second_run,"delivery":delivery,"final_meta":final_meta,"frames":rows}
	var file: FileAccess = FileAccess.open(destination,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(data,"  ")); file.close()
	else: check(false,"actual Home codex movie trace can be written")
	print("HOME CODEX MOVIE: %s frames, %s assertions, %s failures" % [frame,assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
