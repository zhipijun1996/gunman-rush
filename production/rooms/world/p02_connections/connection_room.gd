class_name P02ConnectionRoom
extends Node2D
## Landing scenery and two local P16 claims. The pilot owns crossing and saving.
const SHARD := "wr_P16_primary"
const PURSE := "coin20_P16"
const REACH := 42.0
var host: OrdinaryRoomSession
var catalog: WorldContentCatalog
var points := {}
var objects := {}
var label := Label.new()
var notification := 0.0

static func install(session: OrdinaryRoomSession, document: Dictionary, source: WorldContentCatalog) -> P02ConnectionRoom:
	var result := P02ConnectionRoom.new()
	result.host=session
	session.controller.router.set_meta(&"world_up_interaction",true)
	result.catalog=source
	session.room.add_child(result)
	result.populate(document)
	return result

func populate(doc: Dictionary) -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var bounds := FixedWorldProvider.rect(doc.bounds)
	var camera := host.player.get_node_or_null("Camera2D") as Camera2D
	if camera!=null:
		camera.zoom=Vector2.ONE*1.40
		camera.limit_left=int(bounds.position.x)
		camera.limit_top=int(bounds.position.y)
		camera.limit_right=int(bounds.end.x)
		camera.limit_bottom=int(bounds.end.y)
	var background := Sprite2D.new()
	background.texture=load(doc.scenery.backdrop)
	background.region_enabled=true
	background.region_rect=FixedWorldProvider.rect(doc.scenery.view)
	background.centered=false
	background.position=bounds.position
	background.z_index=-90

	add_child(background)
	if doc.scenery.has("wall"):
		var wall := Polygon2D.new()
		var spec: Dictionary = doc.scenery.wall
		var vertices := PackedVector2Array()
		for xy: Array in spec.points: vertices.append(FixedWorldProvider.point(xy))
		wall.polygon=vertices
		# UVs in world pixels keep masonry and earth grains at the native actor scale.
		wall.uv=vertices
		wall.texture=load(spec.texture)
		wall.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		wall.color=Color(spec.tint)
		wall.z_index=-65
		add_child(wall)
	for piece: Dictionary in doc.scenery.pieces:
		var spr := Sprite2D.new()
		spr.texture=load(piece.texture)
		spr.offset.y=-spr.texture.get_height()*.5
		spr.position=FixedWorldProvider.point(piece.at)
		spr.flip_h=piece.get("flip",false)
		spr.z_index=-3
		add_child(spr)
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left=-330
	label.offset_right=330
	label.offset_top=-90
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",EquipmentMenu.UI_FONT)
	label.add_theme_font_size_override("font_size",22)
	label.add_theme_constant_override("outline_size",5)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if doc.room_id=="P19":
		label.text="井口透着田野的光。站在井底，朝上跳回田埂。"
		notification=5.0
	if doc.room_id!="P16": return
	for id: String in doc.sites:
		points[id]=FixedWorldProvider.point(doc.sites[id].at)
		var node := Node2D.new()
		node.position=points[id]+Vector2(0,18)
		add_child(node)
		if id==SHARD:
			var relic := WorldSpriteAnimation.new()
			relic.asset_id="health_shard"
			relic.position.y=-8
			node.add_child(relic)
			var seat := Sprite2D.new()
			seat.texture=preload("res://assets/plains_v07/native/clock_altar.png")
			seat.region_enabled=true
			seat.region_rect=Rect2(18,96,75,12)
			seat.scale=Vector2(.47,.75)
			seat.position=node.position-Vector2(0,4)
			add_child(seat)
		elif id==PURSE:
			# The courier supplier's leather satchel is an existing native pixel prop.
			var bag := Polygon2D.new()
			bag.texture=UnderworldActors.icon_texture("merchant")
			var cut := PackedVector2Array([Vector2(0,31),Vector2(3,29),Vector2(5,25),Vector2(7,22),Vector2(10,21),Vector2(8,24),Vector2(6,28),Vector2(10,29),Vector2(14,30),Vector2(17,32),Vector2(17,40),Vector2(14,43),Vector2(3,43),Vector2(0,41)])
			bag.uv=cut
			bag.polygon=cut
			bag.offset=Vector2(-8,-43)
			bag.scale=Vector2.ONE*1.25
			node.add_child(bag)
			var coin := Sprite2D.new()
			coin.texture=UnderworldActors.icon_texture("coin")
			coin.scale=Vector2(.19,.09)
			coin.position=Vector2(9,-2)
			node.add_child(coin)
		objects[id]=node
	refresh(0)
	host.state.committed.connect(refresh)
	host.controller.interact_requested.connect(interact)

func receipt(id: String) -> String:
	return "income:"+id if id==PURSE else id

func refresh(_revision: int) -> void:
	for id: String in objects:
		objects[id].visible=not host.state.value.receipts.has(receipt(id))

func in_reach(id: String) -> bool:
	if not points.has(id) or not host.lifetime.active or not host.controller.active: return false
	if host.controller.actor_resources.health.terminal or host.controller.has_pending_damage(): return false
	if not host.pending_defeats.is_empty() or not host.player.is_on_floor(): return false
	return host.player.position.distance_squared_to(points[id])<=REACH*REACH

func interact() -> void:
	for id: String in points:
		if not objects[id].visible or not in_reach(id): continue
		if not claim(id,host.state.revision): label.text="没能记下这次领取，请再试一次。"
		notification=3.0
		return

func claim(id: String, revision: int) -> bool:
	if revision!=host.state.revision or not in_reach(id) or host.state.value.receipts.has(receipt(id)): return false
	var source := catalog.lookup("rewards" if id==SHARD else "coin_caches",id)
	if not source.ok or source.row.room!=host.room.room_id: return false
	var row: Dictionary=source.row
	var conditions: Dictionary={"requires":row.get("requires",[])+row.get("completion_requires",[]),"excludes":row.get("excludes",[])}
	var eligible := catalog.condition_match(conditions,host.state.value.flags,host.services.ledger().equipped)
	if not eligible.ok or not eligible.matches: return false
	var next := host.state.candidate()
	if id==SHARD and row.formal_item_id=="HP01" and row.reward_kind=="health_fragment" and row.delivery_mode=="collection" and row.permanent_unique:
		next.inventory["health_shard"]=int(next.inventory.get("health_shard",0))+int(row.quantity)
		next.receipts[id]={"source":id,"source_hash":MetaSaveService.canonical_json(row).sha256_text(),"revision":revision+1}
	elif id==PURSE and row.one_time:
		next=host.services.earned_candidate(next,id,int(row.amount))
	else: return false
	if not host.state.commit(next,revision): return false
	label.text=("取得生命碎片　共 %d 枚" % int(next.inventory.health_shard)) if id==SHARD else ("找到沟谷旅费　+%d 金币" % int(row.amount))
	GameAudio.cue_committed_reward(self,&"item_get" if id==SHARD else &"chest_open",&"confirm")
	return true

func _physics_process(delta: float) -> void:
	if notification>0:
		notification-=delta
		return
	label.text=""
	for id: String in points:
		if objects[id].visible and in_reach(id):
			label.text="↑ / W　取下生命碎片" if id==SHARD else "↑ / W　调查旧钱袋"
			return
