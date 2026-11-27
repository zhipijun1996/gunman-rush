class_name P02ConnectionRoom
extends Node2D
## Room scenery and active pickups. Item identity and value come from the locked world.
const SHARD := "wr_P16_primary"
const PURSE := "coin20_P16"
const REACH := 42.0
var host: OrdinaryRoomSession
var catalog: WorldContentCatalog
var points := {}
var objects := {}
var offers := {}
var label: Label
var notification := 0.0

static func install(session: OrdinaryRoomSession, document: Dictionary, source: WorldContentCatalog) -> P02ConnectionRoom:
	if session.room_dressing != null: return session.room_dressing as P02ConnectionRoom
	var result := P02ConnectionRoom.new()
	session.room_dressing = result
	result.host=session
	result.catalog=source
	session.room.add_child(result)
	result.populate(document)
	if document.exits.has("d223"):
		preload("res://rooms/world/p02_connections/forest_shortcut_gate.gd").mount(session,document)
	return result

func populate(doc: Dictionary) -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
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
		if not piece.has("texture"): continue # The P02 bell and its field pieces have a dedicated renderer.
		var spr := Sprite2D.new()
		spr.texture=load(piece.texture)
		var height := float(spr.texture.get_height())
		if piece.has("source_rect"):
			spr.region_enabled=true
			spr.region_rect=FixedWorldProvider.rect(piece.source_rect)
			height=spr.region_rect.size.y
		spr.offset.y=-height*.5
		spr.position=FixedWorldProvider.point(piece.at)
		spr.flip_h=piece.get("flip",false)
		spr.z_index=int(piece.get("z_index",-3))
		add_child(spr)
	# Authored sites place the objects; the imported catalog owns their rules.
	for table: String in ["coin_caches", "rewards"]:
		for row: Dictionary in host.content_context.get(table, []):
			if not doc.get("sites", {}).has(row.id): continue
			if table == "rewards" and row.get("reward_kind") not in ["health_fragment", "lost_gear"]: continue
			offers[row.id] = row
	if offers.is_empty() and doc.room_id != "P19":
		set_physics_process(false)
		return
	host.controller.router.set_meta(&"world_up_interaction",true)
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
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
		label.text="头顶的井通往田埂。站在井底跳起，再沿左壁石阶上行。"
		notification=5.0
	if offers.is_empty(): return
	for id: String in offers:
		points[id]=FixedWorldProvider.point(doc.sites[id].at)
		var node := Node2D.new()
		node.position=points[id]+Vector2(0,18)
		add_child(node)
		if offers[id].has("reward_kind"):
			var relic := WorldSpriteAnimation.new()
			relic.asset_id="time_gear" if offers[id].reward_kind=="lost_gear" else "health_shard"
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
		else:
			# Loose money rests in the grass on the same scale as enemy drops.
			for at: Vector2 in [Vector2(-7,-2),Vector2(0,-3),Vector2(6,-2)]:
				var coin := Sprite2D.new()
				coin.texture = UnderworldActors.icon_texture("coin")
				coin.scale = Vector2(.22,.15)
				coin.position = at
				node.add_child(coin)
		objects[id]=node
	refresh(0)
	host.state.committed.connect(refresh)
	host.controller.interact_requested.connect(interact)

func receipt(id: String) -> String:
	return "income:"+id if offers.get(id,{}).has("amount") else id

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
	var row: Dictionary=offers.get(id,{})
	if row.get("room")!=host.room.room_id: return false
	var conditions: Dictionary={"requires":row.get("requires",[])+row.get("completion_requires",[]),"excludes":row.get("excludes",[])}
	var eligible := catalog.condition_match(conditions,host.state.value.flags,host.services.ledger().equipped)
	if not eligible.ok or not eligible.matches: return false
	var next := host.state.candidate()
	var message: String
	if row.has("reward_kind"):
		if row.delivery_mode!="collection" or not row.permanent_unique: return false
		if row.reward_kind=="lost_gear":
			var gear: String=row.formal_item_id
			if row.quantity!=1 or gear in next.gear_ids.carried or gear in next.gear_ids.delivered: return false
			next.gear_ids.carried.append(gear)
			next.inventory["time_gear"]=int(next.inventory.get("time_gear",0))+1
			message="取得"+str(row.display_name)
		else:
			next.inventory["health_shard"]=int(next.inventory.get("health_shard",0))+int(row.quantity)
			message="取得生命碎片　共 %d 枚" % int(next.inventory.health_shard)
		next.receipts[id]={"source":id,"source_hash":MetaSaveService.canonical_json(row).sha256_text(),"revision":revision+1}
	elif row.get("one_time",false):
		next=host.services.earned_candidate(next,id,int(row.amount))
		message="拾取 %d 金币" % int(row.amount)
	else: return false
	if not host.state.commit(next,revision): return false
	label.text=message
	GameAudio.cue_committed_reward(self,&"item_get" if row.has("reward_kind") else &"chest_open",&"confirm")
	return true

func _physics_process(delta: float) -> void:
	if notification>0:
		notification-=delta
		return
	label.text=""
	for id: String in points:
		if objects[id].visible and in_reach(id):
			var row: Dictionary=offers[id]
			if id==SHARD: label.text="↑ / W　取下生命碎片"
			elif id==PURSE: label.text="↑ / W　调查旧钱袋"
			else: label.text="↑ / W　拾取"+str(row.get("display_name",row.get("name","")))
			return
