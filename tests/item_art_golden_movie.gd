extends "res://tests/item_v5_movie.gd"
## A continuous formal golden using the original real-input V5 movie route.
## Extra known-item rewards, the cache relocation and training targets are
## disclosed setup fixtures. HP/resonance are never injected; only the final
## upgrade demonstration explicitly initializes quoted coins through RunWallet.
const GOLDEN_IDS: Array[StringName] = [&"B01",&"B03",&"B11",&"P24",&"P14",&"G14",&"G16",&"N01"]
const EXTRA_GOLDENS: Array[StringName] = [&"B01",&"B03",&"B11",&"G14",&"G16",&"N01"]
var _goldens_added := false
var _judgment_done := false
var _art_observer_connected := false
var art_cues: Array[Dictionary] = []
var golden_icons: Array[Dictionary] = []
var judgment: Dictionary = {}
var equipment_delivery: Dictionary = {}

func frames(count: int) -> void:
	for unused: int in count:
		await super.frames(1)
		if not rows.is_empty(): rows[-1].artist = artist_snapshot()

func entity_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(app) or not is_instance_valid(app.stage): return result
	for node: Node in app.stage.get_children():
		if node is ItemV5Entity:
			var entity := node as ItemV5Entity
			result.append({"kind":str(entity.kind),"position":[entity.global_position.x,entity.global_position.y],"direction":[entity.direction.x,entity.direction.y],"age":entity.age,"progress":entity.progress,"artist":entity.visual_snapshot()})
	return result

func artist_snapshot() -> Dictionary:
	var result := {"library":ItemArtLibrary.diagnostics(),"view":{}}
	if not is_instance_valid(app) or not is_instance_valid(app.stage): return result
	for node: Node in app.stage.get_children():
		if node is ItemEffectView:
			result.view = (node as ItemEffectView).snapshot()
			break
	return result

func _observe_art(kind: StringName, point: Vector2, detail: Dictionary) -> void:
	var origin := StringName(str(detail.get("definition_id",detail.get("origin",detail.get("item",&"")))))
	origin = ItemArtLibrary.cue_source(kind,origin)
	var direction: Variant = detail.get("direction",Vector2.ZERO)
	art_cues.append({"kind":str(kind),"origin":str(origin),"point":[point.x,point.y],"direction":[direction.x,direction.y] if direction is Vector2 else [],"event_id":str(detail.get("event_id",&"")),"clip":str(ItemArtLibrary.cue_clip(kind,origin)),"video_frame":frame,"drawn_frame":Engine.get_frames_drawn(),"index":detail.get("index",-1)})

func grant_fixture(id: StringName) -> bool:
	var accepted := super.grant_fixture(id)
	if not accepted: return false
	if not _art_observer_connected:
		app._item_runtime.effect_cued.connect(_observe_art)
		_art_observer_connected = true
	if id != &"P14" or _goldens_added: return true
	_goldens_added = true
	for extra: StringName in EXTRA_GOLDENS:
		var existing: RunItemInstance = app.build.inventory.instance_for_definition(extra)
		if existing != null:
			fixture_instances[extra] = existing.instance_id
			events.append({"kind":"golden_icon_already_owned","id":str(extra),"instance":str(existing.instance_id),"source":str(existing.source_id),"video_frame":frame,"method":"existing original cache ownership; no duplicate reward or growth"})
		elif not super.grant_fixture(extra): return false
	for golden: StringName in GOLDEN_IDS:
		var definition := ItemCatalogV5.get_item(golden)
		var texture := ItemPresentation.icon(definition.icon_key) as AtlasTexture
		if not check(texture != null and texture.atlas != null and texture.filter_clip,"golden icon uses the actual safe common UI texture route: "+str(golden)): return false
		golden_icons.append({"id":str(golden),"icon_key":str(definition.icon_key),"source":texture.atlas.resource_path,"region":[texture.region.position.x,texture.region.position.y,texture.region.size.x,texture.region.size.y],"instance":str(fixture_instances[golden])})
	events.append({"kind":"golden_icon_inventory","icons":golden_icons.duplicate(true),"video_frame":frame,"method":"known original RewardService fixtures or original naturally claimed cache; only backpack ownership"})
	return true

func _native_unload(id: StringName) -> bool:
	if not await select_owned(id): return false
	if not await click(button(app.menu._root,"UnequipItem")): return false
	await frames(8)
	return check(not app._item_runtime.has(id),"native unload retracts old effect before the next golden active: "+str(id))

func _judgment_segment() -> void:
	_judgment_done = true
	check(golden_icons.size() == 8,"all eight independently illustrated golden icons were observed through actual UI resources")
	check(rows.any(func(row: Dictionary) -> bool:
		return row.get("entities",[]).any(func(entity: Dictionary) -> bool: return entity.kind == "flywheel" and int(entity.get("artist",{}).get("art_draws",0))>0)),"actual post-draw trace contains authored flywheel texture draws")
	check(rows.any(func(row: Dictionary) -> bool:
		return row.get("entities",[]).filter(func(entity: Dictionary) -> bool: return entity.kind == "small_drone" and int(entity.get("artist",{}).get("art_draws",0))>0).size() == 3),"actual post-draw trace contains all three authored patrol bodies")
	await tap(KEY_ESCAPE)
	if not check(paused and app.menu.visible_panel == &"build","native Escape opens the actual formal inventory for the G16 swap"): return
	set_phase("golden_swap","专用美术样板 · 原背包自由换装钟匠裁决")
	# G15 needs a projectile-active source, so unload it before P24.
	if not await _native_unload(&"G15"): return
	if not await _native_unload(&"P24"): return
	# B33 supplies an honest enabled native selection action; remove it again.
	if not await equip_owned(&"B33"): return
	if not await equip_owned(&"G16"): return
	if not await select_owned(&"G16"): return
	if not await click(button(app.menu._root,"SelectActiveItem")): return
	check(app._item_runtime.selected_active() == &"G16","native actual selector chooses judgment instead of relying on a disabled preselected button")
	if not await _native_unload(&"B33"): return
	if not await select_owned(&"G16"): return
	check(app.build.item_ids().size()==2 and app._item_runtime.has(&"G16") and app._item_runtime.has(&"P14") and int(app.build.equipment.snapshot().used)==7,"actual G16 and P14 loadout consumes seven gear with old flywheel/split effects removed")
	set_phase("judgment_equipped","钟匠裁决 + 三巡钟 · 实际负荷 7 / 8")
	await frames(45)
	await tap(KEY_ESCAPE)
	if not check(not paused,"native Escape resumes the formal world for the second golden active"): return
	var hp_before: float = app.controller.actor_resources.health.current
	var coins_before: int = app.wallet.balance
	var params: Dictionary = ItemCatalogV5.get_item(&"G16").parameters_for_level(1)
	var energy_before: float = app.controller.combat_energy.current
	check(is_zero_approx(energy_before),"second active begins with the actually spent zero resonance, not an initialized grant")
	set_phase("judgment_charge","真实普攻 10 次积攒 70 共鸣 · 施放花费 65")
	for index: int in 10:
		caption.text = "裁决供能：真实普攻 %s / 10 · 每次命中 +7 共鸣" % (index+1)
		# The first five shots left the actor west of the platform midpoint.
		# Fire toward that nearer side first so real recoil carries the actor
		# toward the center. Alternating fixed indices from the other side can
		# cross the left target, making both targets rightward thereafter.
		var center_x := (targets[0].global_position.x+targets[1].global_position.x)*0.5
		if not check(app.player.global_position.x>targets[0].global_position.x and app.player.global_position.x<targets[1].global_position.x,"real charge pose stays between the original targets without motion resets"): return
		if not await shoot_target(0 if app.player.global_position.x<center_x else 1): return
	check(is_equal_approx(app.controller.combat_energy.current,70),"ten actual primary HP receipts naturally supply seventy resonance")
	var shot_count_before := shots
	var first_damage := damage_rows.size()
	var first_cue := art_cues.size()
	var active_pointer: Vector2 = targets[1].get_global_transform_with_canvas().origin
	move_pointer(active_pointer)
	await frames(2)
	check(root.get_mouse_position().distance_to(active_pointer)<2,"judgment reads the real native viewport pointer over the actual right target")
	judgment = {"energy_before":app.controller.combat_energy.current,"cost":float(params.combat_energy_cost),"pulse_count":int(params.pulse_count),"ratio_D_each":float(params.damage_ratio_D_each),"base_damage_D":float(app._item_runtime.base_damage()),"start_video_frame":frame}
	set_phase("judgment_cast","按 R · 三段裁决钟波；命中特效读取真实扣血回执")
	key(KEY_R,true)
	await frames(2)
	key(KEY_R,false)
	await frames(105)
	var actual_damage: Array[Dictionary] = []
	for row: Dictionary in damage_rows.slice(first_damage):
		if row.derived and "/G16/" in row.event and float(row.damage)>0: actual_damage.append(row)
	var actual_casts: Array[Dictionary] = []
	var actual_impacts: Array[Dictionary] = []
	for cue: Dictionary in art_cues.slice(first_cue):
		if cue.kind == "item_clock_pulse" and cue.origin == "G16": actual_casts.append(cue)
		if cue.kind == "item_committed_impact" and cue.origin == "G16": actual_impacts.append(cue)
	check(actual_damage.size() == int(params.pulse_count),"each actual configured judgment pulse commits one real right-target HP receipt")
	for row: Dictionary in actual_damage:
		check(row.target == "movie_fixture/target1" and is_equal_approx(float(row.damage),float(params.damage_ratio_D_each)*float(judgment.base_damage_D)),"actual judgment target and damage follow configured D ratio")
	check(actual_casts.size()==int(params.pulse_count) and actual_impacts.size()==actual_damage.size(),"three cast cues and actual positive-HP reception cues remain distinct")
	for cue: Dictionary in actual_impacts:
		check(not str(cue.event_id).is_empty() and actual_damage.any(func(row: Dictionary) -> bool: return row.event == cue.event_id and float(row.damage)>0),"every judgment reception texture has its own actual positive-HP receipt")
	check(is_equal_approx(app.controller.combat_energy.current,70-float(params.combat_energy_cost)) and shots==shot_count_before,"one R pays the configured cost once, no accompanying primary or derived self-charge")
	check(app.controller.actor_resources.health.current==hp_before and app.wallet.balance==coins_before,"second golden neither grants nor spends player HP or run coins")
	check(rows.any(func(row: Dictionary) -> bool:
		return row.get("entities",[]).any(func(entity: Dictionary) -> bool: return entity.kind == "pulse" and str(entity.get("artist",{}).get("origin",""))=="G16" and int(entity.get("artist",{}).get("art_draws",0))>0)),"actual post-draw trace records the authored judgment wave")
	judgment["damage_receipts"] = actual_damage
	judgment["cast_cues"] = actual_casts
	judgment["impact_cues"] = actual_impacts
	judgment["energy_after"] = app.controller.combat_energy.current
	judgment["end_video_frame"] = frame
	set_phase("golden_result","样板完成 · 三类专用美术与真实资源、命中回执一致")
	await frames(60)

func _equipment_delivery_segment() -> void:
	set_phase("equipment_retraction","原生背包 · 卸下战斗道具，检查属性撤销与扩容")
	await tap(KEY_ESCAPE)
	if not check(paused and app.menu.visible_panel == &"build","final native inventory opens for reversible HP and capacity demonstration"): return
	if not await _native_unload(&"G16"): return
	if not await _native_unload(&"P14"): return
	var health: HealthState = app.controller.actor_resources.health
	var base_max := health.capacity
	var current_before := health.current
	if not await equip_owned(&"B11"): return
	var hp_gain: float = ItemCatalogV5.get_item(&"B11").parameters_for_level(1).get("max_hp_add",0.0)
	check(is_equal_approx(health.capacity,base_max+hp_gain) and health.current == current_before,"native B11 equips its actual configured HP maximum without healing")
	var equipped_max := health.capacity
	set_phase("hp_equipped","木心匣已装备 · 生命上限 %s → %s；当前生命不补充" % [base_max,health.capacity])
	await frames(30)
	set_phase("hp_removing","原生点击卸下木心匣 · 撤销生命上限效果")
	if not await _native_unload(&"B11"): return
	check(is_equal_approx(health.capacity,base_max) and health.current == current_before,"native B11 unload fully retracts its maximum HP without a free heal")
	set_phase("hp_removed","卸下木心匣 · 生命上限恢复 %s；效果完整撤销" % base_max)
	await frames(30)
	var quote: Dictionary = app.shop.gear_quote()
	var coin_before: int = app.wallet.balance
	var capacity_before: int = app.build.equipment.snapshot().capacity
	var price: int = int(quote.price)
	fixture_note = "测试初始化：已知道具/训练靶；扩容金币+%s，非自然收益" % price
	if not check(app.wallet.grant(price,&"item_art_movie/upgrade_coin_fixture"),"explicit quoted-coin setup uses original idempotent RunWallet grant ledger"): return
	events.append({"kind":"explicit_upgrade_coin_fixture","amount":price,"before":coin_before,"after":app.wallet.balance,"event_id":"item_art_movie/upgrade_coin_fixture","video_frame":frame,"method":"explicit setup only, original RunWallet ledger; not natural earnings"})
	app._refresh_equipment_view()
	set_phase("gear_upgrade_fixture","扩容测试初始化 +%s 金币（非自然收益）· 正式按钮报价 %s" % [price,price])
	await frames(30)
	var coins_for_purchase: int = app.wallet.balance
	if not await click(button(app.menu._root,"PurchaseGearUpgrade")): return
	check(int(app.build.equipment.snapshot().capacity)==int(quote.next_capacity) and app.wallet.balance==coins_for_purchase-price,"actual native capacity button commits configured upgrade and exact wallet debit")
	check(app.build.item_ids().is_empty() and is_equal_approx(health.capacity,base_max) and health.current==current_before,"capacity upgrade does not autoequip, heal or revive unloaded item effects")
	equipment_delivery = {"base_hp_max":base_max,"equipped_hp_max":equipped_max,"removed_hp_max":health.capacity,"hp_current":health.current,"capacity_before":capacity_before,"capacity_after":app.build.equipment.snapshot().capacity,"price":price,"coin_fixture":price,"coins_before_fixture":coin_before,"coins_before_purchase":coins_for_purchase,"coins_after_purchase":app.wallet.balance}
	set_phase("gear_expanded","已扩容 %s → %s · 扣除 %s 金币；未装备道具仍不生效" % [capacity_before,app.build.equipment.snapshot().capacity,price])
	await frames(45)
	var shots_before_close := shots
	await tap(KEY_ESCAPE)
	await frames(10)
	check(not paused and shots == shots_before_close,"closing upgraded inventory resumes without an accidental primary shot")

func finish() -> void:
	if not _judgment_done and failures.is_empty() and phase == "result" and is_instance_valid(app):
		await _judgment_segment()
		if failures.is_empty(): await _equipment_delivery_segment()
	for code: Variant in held.keys(): key(code,false)
	paused = false
	var final_artist := artist_snapshot()
	for body: Area2D in targets:
		if is_instance_valid(body):
			var receiver := body.get_node("Damageable") as Damageable
			receiver.damage_sink = Callable()
			receiver.bind_health(null)
	targets.clear()
	if is_instance_valid(app):
		check(await preload("res://tests/audio_teardown.gd").drain_world(app),"actual formal audio backends release cleanly")
		app.free()
		app = null
	ItemArtLibrary.clear_cache()
	for unused: int in 8: await process_frame
	var data := {"schema":"item-art-golden-native-movie-v1","scope":"Continuous actual title/Home/departure/formal cache/inventory. Eight golden icons use original reward ownership (natural N01 cache or explicitly known RewardService fixtures). Disclosed cache relocation and high-HP training targets/platform/camera. Native P24+G15+P14 equipment, five primary hits naturally35resonance, realR opposite flywheels and patrol art; native G16/P14 swap, ten further primary hits naturally70resonance, realR configured65cost and three actual0.9D pulses. ActorHP/resonance never injected. Final native B11 maximumHP equip/unload and capacity purchase; explicitly disclosed quoted coins initialized via original RunWallet ledger only for expansion, not natural earnings. Not natural fullroute, full72art, listening, physicaldevice or humanacceptance; no matched before movie.","seed":SEED,"checks":assertions,"failures":failures,"checkpoints":checkpoints,"input_events":events,"primary_receipts":primary_rows,"damage_receipts":damage_rows,"frames":rows,"golden_icons":golden_icons,"art_cues":art_cues,"judgment":judgment,"equipment_delivery":equipment_delivery,"final_artist":final_artist}
	var file := FileAccess.open(destination,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data,"  "))
		file.close()
	else: check(false,"actual golden trace can be written")
	print("ITEM ART GOLDEN MOVIE: %s frames, %s assertions, %s failures" % [frame,assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
