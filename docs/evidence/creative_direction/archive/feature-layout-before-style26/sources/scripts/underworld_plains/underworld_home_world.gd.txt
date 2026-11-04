class_name UnderworldHomeWorld
extends Node2D
## Fixed safe settlement: world sprites and native terrain, never a menu proxy.
const BUILD_PATH := "res://assets/underworld_plains/home/home_build.json"
const CONTACT := preload("res://scripts/underworld_plains/grounded_contact.gd")
var specification: Dictionary
var placements: Array[Dictionary] = []
var terrain: UnderworldTerrain
var slot_nodes: Dictionary = {}
var floor_y := 432.0
var weapon_workshop_enabled := false
var item_codex_enabled := false

func configure(ground_y: float) -> void:
	floor_y = ground_y
	specification = JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH))
	# Activate the authored arms building without changing its fixed platform or art.
	if weapon_workshop_enabled:
		for slot: Dictionary in specification.slots:
			if str(slot.id) == "arms":
				slot.active = true
				slot.keeper = "artisan"
	# Activate the authored relics shelter without moving its platform or using
	# the unrelated achievements service. It is a building interaction, no NPC.
	if item_codex_enabled:
		for slot: Dictionary in specification.slots:
			if str(slot.id) == "relics":
				slot.active = true
				slot.label = "道具图鉴 / Item codex"
	var grounds: Array[Rect2] = [Rect2(-100,floor_y,float(specification.world_width)+200,640)]
	for platform: Dictionary in specification.get("platforms",[]):
		var rect: Array=platform.rect
		grounds.append(Rect2(rect[0],rect[1],rect[2],rect[3]))
	terrain = UnderworldTerrain.build(grounds)
	terrain.z_index=-5
	add_child(terrain)
	for entry: Dictionary in specification.slots:
		_build_slot(entry)
	# Sparse native flora bookend the safe squares; never occupy player collision.
	var props: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/decor/chime_props.json"))
	for x: float in [48.0,1070.0,1710.0,2760.0,3220.0]:
		var region: Dictionary=props.regions.tree
		_place("tree", "assets/underworld_plains/decor/chime_props.png",region.region,region.foot,Vector2(x,floor_y),138.0,-9,0.0,_grounding_depth("tree"))
	_build_departure_road(props)
	# Rooted flora makes the safe ground feel inhabited; terrace approaches and
	# their landing ends remain empty, as do the open gateway and player path.
	for x: float in [80.0,170.0,390.0,1020.0,1640.0,1840.0,2350.0,2740.0,2860.0,3230.0]:
		var flower: Dictionary=props.regions.flowers
		_place("home_flowers", "assets/underworld_plains/decor/chime_props.png",flower.region,flower.foot,Vector2(x,floor_y),22.0,-3,0.0,_grounding_depth("small_flora"))

func _build_departure_road(props: Dictionary) -> void:
	var road: Dictionary=specification.departure_road
	# The full clock arch frames open, traversable space, rather than another
	# storefront. A lone roadside bell is the last village landmark behind it.
	var tower: Dictionary=props.regions.tower
	_place("departure_road_bell","assets/underworld_plains/decor/chime_props.png",tower.region,tower.foot,Vector2(float(road.from_x),floor_y),148.0,-7,0.0,_grounding_depth("structure"))
	var label:=Label.new()
	label.name="DepartureRoadDirection"
	label.text="风铃平原  →"
	label.position=Vector2(float(road.gate_x)-180,floor_y-100)
	label.size=Vector2(360,60)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",UnderworldUI.FONT)
	label.add_theme_font_size_override("font_size",21)
	label.add_theme_color_override("font_color",Color("f4d896"))
	label.add_theme_color_override("font_shadow_color",Color("101c25"))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _build_slot(entry: Dictionary) -> void:
	var x:=float(entry.x)
	var root:=Vector2(x,float(entry.get("y",floor_y)))
	var building: Dictionary=specification.assets[str(entry.building)]
	_place(str(entry.id)+"_building",str(building.image),building.region,building.foot,root,float(entry.building_height),-7,float(building.get("opaque_height",building.foot[1])),_grounding_depth("structure"))
	if bool(entry.active) and str(entry.id)!="departure" and not str(entry.keeper).is_empty():
		var npc: Dictionary=specification.assets[str(entry.keeper)]
		var keeper:=_place(str(entry.id)+"_keeper",str(npc.image),npc.region,npc.foot,root+Vector2(48,0),UnderworldActors.HUMANOID_HEIGHT,-1,float(npc.opaque_height))
		keeper.set_meta("home_function",str(entry.id))
	var label:=Label.new()
	label.name="Slot_"+str(entry.id)
	label.text=str(entry.label).split("/")[0].strip_edges()+( "" if bool(entry.active) else " · 预留")
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",UnderworldUI.FONT)
	label.add_theme_font_size_override("font_size",13)
	label.add_theme_color_override("font_color",Color("eadab3") if bool(entry.active) else Color("9baaa3"))
	label.add_theme_color_override("font_shadow_color",Color("101c25"))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.position=Vector2(x-90,root.y-float(entry.building_height)-30)
	label.size=Vector2(180,26)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.set_meta("home_slot",entry.duplicate(true))
	add_child(label)
	slot_nodes[str(entry.id)]=label

func _grounding_depth(kind: String) -> float:
	return CONTACT.depth(kind)

func _place(id: String,image: String,region: Array,foot: Array,root: Vector2,height: float,depth: int,source_height: float = 0.0,contact_depth: float = 0.0) -> Sprite2D:
	var sprite:=Sprite2D.new()
	var atlas:=AtlasTexture.new()
	atlas.atlas=load("res://"+image)
	atlas.region=Rect2(region[0],region[1],region[2],region[3])
	atlas.filter_clip=true
	sprite.name=id
	sprite.texture=atlas
	sprite.centered=false
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	# The measured source foot is the final opaque row, not a broad contact
	# line. Bury only this non-colliding render base into the fine grass/soil;
	# slots, real supporting bodies and the navigation foot stay unchanged.
	var factor:=height/(source_height if source_height>0 else float(foot[1]))
	sprite.scale=Vector2.ONE*factor
	sprite.position=CONTACT.origin(root,Vector2(foot[0],foot[1]),factor,contact_depth)
	sprite.z_index=depth
	sprite.set_meta("home_root",root)
	var render_root:=sprite.position+Vector2(foot[0],foot[1])*factor
	sprite.set_meta("grounded_render_root",render_root)
	sprite.set_meta("grounded_inset_wu",render_root.y-root.y)
	add_child(sprite)
	placements.append({"id":id,"source":image,"region":region,"source_foot":foot,"root":[root.x,root.y],"render_root":[render_root.x,render_root.y],"render_bounds":[sprite.position.x,sprite.position.y,float(region[2])*factor,float(region[3])*factor],"ground_inset_wu":render_root.y-root.y,"height":height,"collision":false,"node":str(sprite.get_path())})
	return sprite

func update_focus(player_position: Vector2,camera_x: float) -> void:
	# Names stay short. Full function/reserved explanation belongs to Home's
	# nearby context prompt; never clip a distant bilingual label at an edge.
	for id: String in slot_nodes:
		var label:=slot_nodes[id] as Label
		var entry: Dictionary=label.get_meta("home_slot")
		var foot:=Vector2(float(entry.x),float(entry.get("y",floor_y)))
		var near:=absf(player_position.x-foot.x)<105 and absf(player_position.y+18-foot.y)<32
		label.visible=absf(float(entry.x)-camera_x)<540
		if not label.has_meta("focused") or bool(label.get_meta("focused"))!=near:
			label.set_meta("focused",near)
			label.add_theme_font_size_override("font_size",15 if near else 12)
			label.add_theme_color_override("font_color",Color("dcc598") if near else Color("99a59c",.76))
