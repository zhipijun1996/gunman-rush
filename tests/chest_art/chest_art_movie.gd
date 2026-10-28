extends "res://tests/item_v5_movie.gd"
## Real original chest ownership/movie, plus explicitly separate visual gallery.
## Never mutates original chest rows, rewards, tiers, HP, coins, AI or RNG.
const CLAIM_DISCLOSURE := "宝箱站位/镜头为测试初始化；正式原箱领取，非自然路线"
const GALLERY_DISCLOSURE := "六态仅美术显示初始化；非自然箱子分布或领取"
const TIERS: Array[StringName] = [&"medium",&"high",&"region_top"]
var mode: String = "plains"
var gallery_region: StringName = &"plains"
var active_chest_id: String = ""
var selected_ids: Array[String] = []
var committed: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var reload_state: Dictionary = {}
var original_manifest: String = ""
var original_run: String = ""
var original_actor_session: int = -1
var original_actor_epoch: int = -1
var gallery_rows: Array[Dictionary] = []
var gallery_sprites: Array[Sprite2D] = []
var gallery_images: Array[Dictionary] = []
var gallery_foot: Vector2 = Vector2.ZERO
var gallery_host: Node2D
var gallery_layer: ChestArtLayer
var gallery_destination: String = ""

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trace="): destination = argument.trim_prefix("--trace=")
		elif argument.begins_with("--mode="): mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--region="): gallery_region = StringName(argument.trim_prefix("--region="))
		elif argument.begins_with("--gallery-dir="): gallery_destination = argument.trim_prefix("--gallery-dir=")
	_run.call_deferred()

func frames(count: int) -> void:
	for unused: int in count:
		await super.frames(1)
		if rows.is_empty() or not is_instance_valid(app): continue
		rows[-1].active_chest_id = active_chest_id
		rows[-1].chests = chest_rows()
		rows[-1].receipt_count = committed.size()
		rows[-1].run_id = app._run_receipt_prefix
		rows[-1].actor_epoch = app.lifetime.actor_epoch
		rows[-1].stage_epoch = app.lifetime.stage_epoch
		rows[-1].reward_opened = app.reward_modal.opened
		rows[-1].pending_claim = app._region_pending_claim
		rows[-1].chest_art = ChestArtLibrary.diagnostics()
		rows[-1].forest_content_version = app.forest_content_version
		rows[-1].forest_layout_version = app._forest_layout_version
		if is_instance_valid(app.controller):
			rows[-1].session = app.controller.session_id
			rows[-1].player_grounded = app.player.is_on_floor()
		if is_instance_valid(app._run_camera):
			var point: Vector2 = app._run_camera.get_screen_center_position()
			rows[-1].camera = [point.x,point.y]
			rows[-1].camera_zoom = [app._run_camera.zoom.x,app._run_camera.zoom.y]
		if is_instance_valid(app.stage) and app.stage is ThornForestRegionStage:
			var layer: ChestArtLayer = app.stage.chest_art_layer
			rows[-1].forest_layer = {"instance_id":layer.get_instance_id(),"material_is_original":layer.material == ChestArtLibrary.world_material(),"bound_original_rows":is_same(layer.chests,app.stage.chests),"scope":"real layer binding; visual output verified by post-draw PNG, not an invented draw receipt"}

func chest_by_id(id: String) -> Dictionary:
	if not is_instance_valid(app) or not is_instance_valid(app.stage): return {}
	for row: Dictionary in app.stage.chests:
		if str(row.id) == id: return row
	return {}

func chest_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(app) or not is_instance_valid(app.stage): return result
	for row: Dictionary in app.stage.chests:
		var entry: Dictionary = {"id":str(row.id),"tier":str(row.tier),"claimed":bool(row.claimed),"position":[row.position.x,row.position.y],"in_claim_ledger":app.region_state.claimed.has(row.id)}
		if row.has("sprite") and is_instance_valid(row.sprite):
			var sprite: Sprite2D = row.sprite
			var texture: AtlasTexture = sprite.texture as AtlasTexture
			entry.actual_sprite = {"visible":sprite.is_visible_in_tree(),"managed":bool(sprite.get_meta("chest_art_managed",false)),"state": "open" if bool(sprite.get_meta("underworld_chest_open",false)) else "closed","matches_actual_state_texture":sprite.texture == ChestArtLibrary.texture(StringName(str(row.tier)),bool(row.claimed)),"material_is_original":sprite.material == ChestArtLibrary.world_material(),"foot":[sprite.position.x,sprite.position.y],"scale":[sprite.scale.x,sprite.scale.y],"modulate":[sprite.modulate.r,sprite.modulate.g,sprite.modulate.b,sprite.modulate.a],"source":texture.atlas.resource_path if texture != null else "","region":[texture.region.position.x,texture.region.position.y,texture.region.size.x,texture.region.size.y] if texture != null else []}
		result.append(entry)
	return result

func owned_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if app.build == null: return result
	for item: RunItemInstance in app.build.inventory.instances():
		result.append({"instance":str(item.instance_id),"id":str(item.definition_id),"source":str(item.source_id),"level":item.level})
	return result

func _on_committed(receipt: EconomyReceipt) -> void:
	# Original ownership commits before the caller updates claimed/coins. Record
	# that ordering, then inspect the actual following post-draw state separately.
	committed.append({"chest_id":active_chest_id,"event_id":str(receipt.event_id),"status":receipt.status,"item_id":str(receipt.item_id),"instance_id":str(receipt.instance_id),"video_frame":frame,"drawn_frame":Engine.get_frames_drawn(),"run_id":app._run_receipt_prefix,"claimed_at_signal":bool(chest_by_id(active_chest_id).get("claimed",false))})

func transition(id: String, text: String) -> void:
	phase = id
	caption.text = text
	fixture_caption.text = fixture_note
	events.append({"kind":"transition","id":id,"video_frame":frame,"drawn_frame":Engine.get_frames_drawn()})

func observed_phase(id: String, text: String, hold: int) -> void:
	phase = id
	caption.text = text
	fixture_caption.text = fixture_note
	await frames(1)
	var observed: Dictionary = rows[-1]
	check(observed.phase == id and int(observed.drawn_frame) == Engine.get_frames_drawn(),"checkpoint is backed by its actual completed post-draw frame: "+id)
	checkpoints.append({"id":id,"phase":text,"video_frame":frame,"drawn_frame":Engine.get_frames_drawn(),"active_chest_id":active_chest_id,"fixture_note":fixture_note,"observed_post_draw":true})
	print("CHEST ART PHASE: ",id," / ",frame)
	await frames(hold)

func supported_chest_position(chest: Dictionary) -> Dictionary:
	var collision: CollisionShape2D = app.player.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	if rectangle == null: return {}
	var feet_offset: float = collision.position.y+rectangle.size.y*.5
	for offset: float in [-65.0,65.0,-52.0,52.0,-40.0,40.0,0.0]:
		var x: float = chest.position.x+offset
		var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(Vector2(x,chest.position.y-2),Vector2(x,chest.position.y+95),app.player.collision_mask,[app.player.get_rid()])
		var hit: Dictionary = app.player.get_world_2d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y > -.7: continue
		var point: Vector2 = Vector2(x,hit.position.y-feet_offset-.2)
		if point.distance_to(chest.position) >= 78 or not app.segment.is_safe(point): continue
		var host: Node = hit.collider as Node
		return {"position":[point.x,point.y],"floor":[hit.position.x,hit.position.y],"host":str(host.get_path()) if host != null else "","original_segment_is_safe":true}
	return {}

func apply_fixture_position(point: Vector2) -> bool:
	if not check(not app.controller.has_pending_damage(),"position initialization cannot cancel genuinely pending player damage"): return false
	var before: Dictionary = {"hp":app.controller.actor_resources.health.current,"stamina":app.controller.actor_resources.stamina.current,"resonance":app.controller.combat_energy.current,"shots":app.controller.action_resources.shot_charges,"coins":app.wallet.balance,"session":app.controller.session_id,"actor_epoch":app.lifetime.actor_epoch}
	# Existing tests/demo_tests.gd locate protocol: invalidate contact history so
	# one disclosed fixture relocation is not treated as a swept traversal.
	# PlayerMotor.reset_at changes position/motion only; do not call the
	# Controller reset/segment-return APIs that restore action resources.
	app.lifetime.invalidate_actor()
	app.player.reset_at(point)
	original_actor_session = app.controller.session_id
	original_actor_epoch = app.lifetime.actor_epoch
	return check(app.controller.session_id == int(before.session) and app.controller.actor_resources.health.current == float(before.hp) and app.controller.actor_resources.stamina.current == float(before.stamina) and app.controller.combat_energy.current == float(before.resonance) and app.controller.action_resources.shot_charges == int(before.shots) and app.wallet.balance == int(before.coins),"declared fixture epoch/pose initialization changes no HP, resources, coins or actor session")

func pose_for_chest(id: String, purpose: String) -> bool:
	var chest: Dictionary = chest_by_id(id)
	if not check(not chest.is_empty(),"original chestID exists for "+purpose): return false
	active_chest_id = id
	transition("position/"+purpose,"原箱站位/镜头初始化 · 不改奖励或箱子位置")
	var support: Dictionary = supported_chest_position(chest)
	if not check(not support.is_empty(),"original floor ray and SegmentRespawn safety validate a supported point inside the real chest interaction radius"): return false
	var position: Vector2 = Vector2(support.position[0],support.position[1])
	if not apply_fixture_position(position): return false
	# The original camera's authored observation pair keeps the real chest left
	# of the centered680px reward panel. Never move UI or change camera zoom.
	app._run_camera.observation_focus = chest.position+Vector2(720,0)
	app._run_camera.snap_to_target()
	events.append({"kind":"explicit_chest_position_camera_fixture","id":id,"purpose":purpose,"position":[position.x,position.y],"supported_original_floor":support,"fixture_actor_epoch":original_actor_epoch,"fixture_actor_session":original_actor_session,"observation_focus":[app._run_camera.observation_focus.x,app._run_camera.observation_focus.y],"video_frame":frame,"method":"one supported actor pose with original locate/invalidate_actor protocol and observation_focus/snap; explicit contact-history discontinuity, unchanged chest, HP, abilities, collision and rewards"})
	await frames(36)
	return check(app.controller.session_id == original_actor_session and app.lifetime.actor_epoch == original_actor_epoch and not app.controller.actor_resources.health.terminal,"original actor survives and does not environment-return during chest setup")

func verify_art(chest: Dictionary, claimed: bool) -> bool:
	if not check(bool(chest.claimed) == claimed and app.region_state.claimed.has(chest.id) == claimed,"actual chest and claimed ledger agree"): return false
	if app.stage is ThornForestRegionStage:
		return check(is_instance_valid(app.stage.chest_art_layer) and is_same(app.stage.chest_art_layer.chests,app.stage.chests) and app.stage.chest_art_layer.material == ChestArtLibrary.world_material(),"default Forest draw layer still binds original claimed rows and chest material")
	var sprite: Sprite2D = chest.sprite
	return check(sprite.texture == ChestArtLibrary.texture(StringName(str(chest.tier)),claimed) and bool(sprite.get_meta("underworld_chest_open",false)) == claimed and sprite.position == chest.position+Vector2(0,21),"actual Plains Sprite2D selects the exact accepted closed/open pose at its original foot")

func claim_original_chest(id: String, tier: StringName, hold_closed: int, hold_open: int) -> bool:
	if not await pose_for_chest(id,"claim"): return false
	var chest: Dictionary = chest_by_id(id)
	if not check(StringName(str(chest.tier)) == tier and not chest.claimed,"natural original chest keeps its actual tier and starts closed"): return false
	if not verify_art(chest,false): return false
	await observed_phase(str(tier)+"_closed","%s原箱 · 关闭状态，尚未领取" % tier,hold_closed)
	transition("opening/"+str(tier),"真实W打开奖励界面 · 箱子仍应关闭")
	await tap(KEY_W)
	await frames(8)
	if not check(paused and app.reward_modal.opened and app._region_chest >= 0 and str(app.stage.chests[app._region_chest].id) == id,"native W opens the reward UI for this actual existing chest"): return false
	if not verify_art(chest,false): return false
	await observed_phase(str(tier)+"_offer","奖励界面已打开 · 尚未选择，箱盖不提前打开",90)
	var option: ItemDefinition = app._region_offer.candidates[0]
	if not check(option != null and not option is ResourceRewardChoice,"original unmodified offer contains a legal real item choice"): return false
	var before: Dictionary = {"wallet":app.wallet.balance,"owned":owned_rows(),"receipt_count":committed.size(),"hp":app.controller.actor_resources.health.current}
	transition("claiming/"+str(tier),"点击原合法奖励按钮 · 等待正式交易提交")
	if not await click(button(app.reward_modal._root,"选择 / PICK "+option.display_name)): return false
	await frames(8)
	if not check(not paused and not app.reward_modal.opened and committed.size() == int(before.receipt_count)+1,"actual original reward commits once and closes its own UI"): return false
	var receipt: Dictionary = committed[-1]
	if not check(receipt.status == EconomyReceipt.Status.COMMITTED and receipt.chest_id == id and receipt.event_id == id+"/claim" and receipt.item_id == str(option.stable_id),"accepted COMMITTED receipt matches this original chest and actual choice"): return false
	if not check(app.build.inventory.get_instance(StringName(receipt.instance_id)) != null and app.build.item_ids().is_empty(),"successful chest transaction adds actual inactive inventory ownership"): return false
	if not check(app.wallet.balance == int(before.wallet)+int(chest.coins) and int(app.wallet._grants.get(StringName(id+"/coins"),-1)) == int(chest.coins),"actual original chest coin ledger credits its unchanged configured amount once"): return false
	if not verify_art(chest,true): return false
	cases.append({"id":id,"tier":str(tier),"option_id":str(option.stable_id),"receipt":receipt.duplicate(true),"before":before,"after":{"wallet":app.wallet.balance,"owned":owned_rows(),"hp":app.controller.actor_resources.health.current},"configured_coins":int(chest.coins),"completed_post_draw":Engine.get_frames_drawn()})
	await observed_phase(str(tier)+"_open","领取已提交 · 原箱显示开启，道具先进入背包",hold_open)
	return true

func _start_original_region(region: StringName) -> bool:
	app = preload("res://scenes/demo/demo.tscn").instantiate()
	app.meta_persistence_enabled = false
	root.add_child(app)
	var started: bool = app.start_plains(SEED) if region == &"plains" else app.start_debug_region(&"thorn_forest",1,"forest-depth-hollow-00",ThornForestRegionGenerator.DEPTH_VERSION,ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT)
	if not check(started,"original DemoApp starts the actual requested formal region"): return false
	for unused: int in 180:
		if is_instance_valid(app.stage) and not app._stage_pending: break
		await frames(1)
	await frames(24)
	if not check(app.connected_region and app.stage is PlainsRegionStage and app.stage.assembly_ok and bool(ChestArtLibrary.diagnostics().valid),"actual formal stage and source04 chest registry are ready"): return false
	original_manifest = JSON.stringify(app.stage.generated.manifest)
	original_run = app._run_receipt_prefix
	original_actor_session = app.controller.session_id
	original_actor_epoch = app.lifetime.actor_epoch
	app.rewards.claimed.connect(_on_committed)
	return true

func _reload_and_observe(tiers: Array[StringName], hold: int) -> bool:
	transition("reloading","原生产关卡重建 · 保留本局状态与交易账本")
	reload_state = {"wallet":app.wallet.balance,"owned":owned_rows(),"receipts":committed.duplicate(true),"generated_manifest":original_manifest,"run_id":original_run}
	app._pause_for_menu()
	await app._load_stage()
	app._resume_from_menu()
	await frames(8)
	if not check(app._run_receipt_prefix == original_run and JSON.stringify(app.stage.generated.manifest) == original_manifest and app.wallet.balance == int(reload_state.wallet) and owned_rows() == reload_state.owned and committed == reload_state.receipts,"original reload retains map, run, inactive inventory and exact wallet/receipt state without re-awarding"): return false
	original_actor_session = app.controller.session_id
	original_actor_epoch = app.lifetime.actor_epoch
	active_chest_id = ""
	await observed_phase("reload_ready","重建已完成 · 地图、背包与金币未重复结算",30)
	for index: int in selected_ids.size():
		var id: String = selected_ids[index]
		if not await pose_for_chest(id,"reload_review"): return false
		if not verify_art(chest_by_id(id),true): return false
		await observed_phase(str(tiers[index])+"_reloaded","重载回看 · 真实已领原箱仍保持开启",hold)
	return check(app.wallet.balance == int(reload_state.wallet) and owned_rows() == reload_state.owned and committed == reload_state.receipts,"visiting reopened visual states cannot duplicate original rewards")

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	fixture_note = GALLERY_DISCLOSURE if mode == "gallery" else CLAIM_DISCLOSURE
	add_captions()
	transition("initializing","真实主游戏宝箱 · source04蓝/紫/金主体")
	if not check(mode in ["plains","forest","gallery"],"only explicit supported capture modes are accepted"): await finish(); return
	var region: StringName = gallery_region if mode == "gallery" else &"thorn_forest" if mode == "forest" else &"plains"
	if not await _start_original_region(region): await finish(); return
	if mode == "gallery":
		await _gallery()
		await finish()
		return
	var tiers: Array[StringName] = []
	if mode == "plains": tiers.assign(TIERS)
	else: tiers.assign([&"high"])
	for tier: StringName in tiers:
		var selected: String = ""
		for chest: Dictionary in app.stage.chests:
			if StringName(str(chest.tier)) != tier or str(chest.reward_mode) == "resources": continue
			if tier == &"medium" and not str(chest.id).ends_with("medium_0"): continue
			selected = str(chest.id)
			break
		if not check(not selected.is_empty(),"actual current Manifest naturally contains the required unmodified tier: "+str(tier)): await finish(); return
		selected_ids.append(selected)
	await observed_phase("plains_ready" if mode == "plains" else "forest_ready","正式平原三档原箱" if mode == "plains" else "正式森林high原箱 · 既有H初始化，不声称全三档自然生成",60)
	for index: int in selected_ids.size():
		if not await claim_original_chest(selected_ids[index],tiers[index],90 if mode == "plains" else 60,120): await finish(); return
	if not check(JSON.stringify(app.stage.generated.manifest) == original_manifest,"actual claims never rewrite source reward Manifest, tiers or RNG"): await finish(); return
	if not await _reload_and_observe(tiers,66 if mode == "plains" else 90): await finish(); return
	await finish()

func _surface_clear(point: Vector2) -> bool:
	for record: Dictionary in app.stage.assembler.world_static_hazard_records():
		if record.get("role","") == "fall_plane": continue
		var rect: Rect2 = record.rect
		if rect.grow(44).has_point(point): return false
	for chest: Dictionary in app.stage.chests:
		if point.distance_to(chest.position) < 80: return false
	return true

func _gallery_floor() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for module: PlatformingModule in app.stage.assembler.modules:
		for local: Rect2 in module.definition.platforms:
			if local.size.x < 540: continue
			var rect: Rect2 = Rect2(module.to_global(local.position),local.size)
			var center: Vector2 = Vector2(rect.get_center().x,rect.position.y)
			var valid: bool = true
			for offset: float in [-240.0,-180.0,-108.0,-36.0,36.0,108.0,180.0]:
				var point: Vector2 = center+Vector2(offset,0)
				var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(point+Vector2(0,-12),point+Vector2(0,4),1)
				var hit: Dictionary = app.player.get_world_2d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or absf(hit.position.y-center.y) > .1 or hit.normal.y > -.7 or not _surface_clear(point): valid = false; break
			if valid: candidates.append({"foot":[center.x,center.y],"distance":center.distance_to(app.stage.spawn),"host_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"module":str(module.definition.module_id)})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	return candidates[0] if not candidates.is_empty() else {}

func _gallery() -> void:
	var host_floor: Dictionary = _gallery_floor()
	if not check(not host_floor.is_empty(),"six-state display fixture finds an actual long hazard-clear authored floor without adding terrain"): return
	gallery_foot = Vector2(host_floor.foot[0],host_floor.foot[1])
	transition("gallery_setup","六态为视觉显示初始化 · 保留真实场景/玩家/HUD")
	var player_position: Vector2 = gallery_foot+Vector2(-240,-18.2)
	if not check(app.segment.is_safe(player_position),"visual gallery player position passes original floor/hazard/collision safety"): return
	if not apply_fixture_position(player_position): return
	app._run_camera.observation_focus = gallery_foot+Vector2(200,-18)
	app._run_camera.snap_to_target()
	events.append({"kind":"explicit_gallery_fixture","region":str(gallery_region),"host":host_floor,"player_position":[app.player.global_position.x,app.player.global_position.y],"no_original_rows_mutated":true,"reward_claim":false,"video_frame":frame})
	gallery_host = Node2D.new()
	gallery_host.name = "ExplicitChestGalleryDisplay"
	app.stage.add_child(gallery_host)
	for index: int in 6:
		var tier: StringName = TIERS[index >> 1]
		var claimed: bool = index%2 == 1
		var foot: Vector2 = gallery_foot+Vector2(-180+index*72,0)
		if gallery_region == &"thorn_forest":
			gallery_rows.append({"id":"visual-gallery/"+str(tier)+("/open" if claimed else "/closed"),"tier":str(tier),"claimed":claimed,"position":foot-Vector2(0,18)})
		else:
			var sprite: Sprite2D = Sprite2D.new()
			gallery_host.add_child(sprite)
			check(ChestArtLibrary.place_sprite(sprite,foot,tier,claimed),"gallery uses the actual admitted Sprite2D recipe")
			gallery_sprites.append(sprite)
		var label: Label = Label.new()
		label.text = (["蓝","紫","金"][index >> 1])+ ("开" if claimed else "闭")
		label.add_theme_font_override("font",DemoClockworkTheme.FONT)
		label.add_theme_font_size_override("font_size",10)
		label.add_theme_color_override("font_color",Color.WHITE)
		label.add_theme_constant_override("outline_size",2)
		label.position = foot+Vector2(-15,7)
		gallery_host.add_child(label)
	if gallery_region == &"thorn_forest":
		gallery_layer = ChestArtLayer.new()
		gallery_layer.name = "ExplicitGalleryForestLayer"
		gallery_layer.configure(gallery_rows)
		gallery_host.add_child(gallery_layer)
	await frames(60)
	if not check(app.player.is_on_floor() and app.controller.session_id == original_actor_session and app.lifetime.actor_epoch == original_actor_epoch,"real gallery player stands on the original floor without environment return"): return
	# This is explicitly a static visual comparison, not an input/AI proof.
	app._pause_for_menu()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await observed_phase("gallery_%sx%s" % [dimensions.x,dimensions.y],"六态美术对照 · %s · 原世界尺寸，不代表自然生成" % gallery_region,8)
		var image: Image = root.get_texture().get_image()
		var path: String = ProjectSettings.globalize_path(gallery_destination).path_join("six-poses-%sx%s.png" % [dimensions.x,dimensions.y])
		check(image != null and image.get_size() == dimensions and image.save_png(path) == OK,"actual post-draw six-state region viewport is saved")
		var poses: Array[Dictionary] = []
		for index: int in 6:
			var tier: StringName = TIERS[index >> 1]
			var claimed: bool = index%2 == 1
			var foot: Vector2 = gallery_foot+Vector2(-180+index*72,0)
			var pose: Dictionary = ChestArtLibrary.pose(tier,claimed)
			var texture: AtlasTexture = ChestArtLibrary.texture(tier,claimed)
			var scale: float = float(pose.world_size[0])/float(pose.region[2])
			var world_rect: Rect2 = Rect2(foot-Vector2(pose.foot_pivot_source_px[0],pose.foot_pivot_source_px[1])*scale,Vector2(pose.world_size[0],pose.world_size[1]))
			var transform: Transform2D = app.player.get_canvas_transform()
			var screen_rect: Rect2 = Rect2(transform*world_rect.position,world_rect.size*transform.get_scale().abs())
			check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(screen_rect),"entire untrimmed admitted ROI remains on screen: "+str(tier))
			poses.append({"tier":str(tier),"claimed_visual_fixture":claimed,"source":texture.atlas.resource_path,"region":[texture.region.position.x,texture.region.position.y,texture.region.size.x,texture.region.size.y],"foot_world":[foot.x,foot.y],"world_rect":[world_rect.position.x,world_rect.position.y,world_rect.size.x,world_rect.size.y],"screen_rect":[screen_rect.position.x,screen_rect.position.y,screen_rect.size.x,screen_rect.size.y],"factor":scale,"actual_renderer":"ChestArtLayer" if gallery_region == &"thorn_forest" else "Sprite2D"})
		gallery_images.append({"file":path.get_file(),"sha256":FileAccess.get_sha256(path),"viewport":[dimensions.x,dimensions.y],"watermark":GALLERY_DISCLOSURE,"poses":poses,"real_original_chest_count":app.stage.chests.size(),"original_manifest_unchanged":JSON.stringify(app.stage.generated.manifest) == original_manifest,"actual_reward_receipts":committed.size(),"visual_only":true})
	check(committed.is_empty() and app.build.inventory.instances().is_empty() and JSON.stringify(app.stage.generated.manifest) == original_manifest,"gallery changes no original reward rows, ownership or Manifest")

func finish() -> void:
	for code: Variant in held.keys(): key(code,false)
	paused = false
	var final_owned: Array[Dictionary] = owned_rows() if is_instance_valid(app) else []
	var final_wallet: int = app.wallet.balance if is_instance_valid(app) else 0
	var final_art: Dictionary = ChestArtLibrary.diagnostics()
	var final_hp: float = app.controller.actor_resources.health.current if is_instance_valid(app) and is_instance_valid(app.controller) else 0.0
	if is_instance_valid(app):
		check(await preload("res://tests/audio_teardown.gd").drain_world(app),"actual original region audio drains cleanly")
		app.free()
		app = null
	gallery_sprites.clear()
	gallery_layer = null
	gallery_host = null
	ChestArtLibrary.clear_cache()
	ItemArtLibrary.clear_cache()
	for unused: int in 8: await process_frame
	var data: Dictionary = {"schema":"chest-art-native-movie-v1","mode":mode,"region":str(gallery_region) if mode == "gallery" else "thorn_forest" if mode == "forest" else "plains","scope":"Actual existing formal chest IDs, original W/reward buttons/COMMITTED ownership/coin ledger/claimed and original reload. Only actor positions and original observation-focus camera are initialized; no HP/AI/coins/tier/RNG rescue. Gallery is explicitly separate visual-only fixture nodes/rows, never stage.chests or natural all-tier spawn. Static closed/open poses, no opening-animation claim; physical device/listening unverified.","fixture_note":fixture_note,"checks":assertions,"failures":failures,"frames":rows,"checkpoints":checkpoints,"input_events":events,"selected_ids":selected_ids,"committed_receipts":committed,"cases":cases,"reload_state":reload_state,"final_owned":final_owned,"final_wallet":final_wallet,"final_hp":final_hp,"original_manifest":original_manifest,"gallery_images":gallery_images,"art":final_art}
	var file: FileAccess = FileAccess.open(destination,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(data,"  ")); file.close()
	else: check(false,"actual chest trace can be saved")
	print("CHEST ART MOVIE: %s frames, %s assertions, %s failures" % [frame,assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
