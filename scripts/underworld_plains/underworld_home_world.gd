class_name UnderworldHomeWorld
extends Node2D
## Fixed safe settlement: world sprites and native terrain, never a menu proxy.
const BUILD_PATH := "res://assets/underworld_plains/home/home_build.json"
var specification: Dictionary
var placements: Array[Dictionary] = []
var terrain: UnderworldTerrain
var slot_nodes: Dictionary = {}
var floor_y := 432.0

func configure(ground_y: float) -> void:
	floor_y = ground_y
	specification = JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH))
	var grounds: Array[Rect2] = [Rect2(-100,floor_y,float(specification.world_width)+200,640)]
	terrain = UnderworldTerrain.build(grounds)
	terrain.z_index=-5
	add_child(terrain)
	for entry: Dictionary in specification.slots:
		_build_slot(entry)
	# Sparse native flora bookend the safe squares; never occupy player collision.
	var props: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/decor/chime_props.json"))
	for x: float in [48.0,1280.0,1920.0,2560.0,3390.0]:
		var region: Dictionary=props.regions.tree
		_place("tree", "assets/underworld_plains/decor/chime_props.png",region.region,region.foot,Vector2(x,floor_y),138.0,-9)

func _build_slot(entry: Dictionary) -> void:
	var x:=float(entry.x)
	var root:=Vector2(x,floor_y)
	var building: Dictionary=specification.assets[str(entry.building)]
	_place(str(entry.id)+"_building",str(building.image),building.region,building.foot,root,float(entry.building_height),-7,float(building.get("opaque_height",building.foot[1])))
	if bool(entry.active) and str(entry.id)!="departure":
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
	label.position=Vector2(x-90,floor_y-float(entry.building_height)-30)
	label.size=Vector2(180,26)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.set_meta("home_slot",entry.duplicate(true))
	add_child(label)
	slot_nodes[str(entry.id)]=label

func _place(id: String,image: String,region: Array,foot: Array,root: Vector2,height: float,depth: int,source_height: float = 0.0) -> Sprite2D:
	var sprite:=Sprite2D.new()
	var atlas:=AtlasTexture.new()
	atlas.atlas=load("res://"+image)
	atlas.region=Rect2(region[0],region[1],region[2],region[3])
	atlas.filter_clip=true
	sprite.name=id
	sprite.texture=atlas
	sprite.centered=false
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	# Declared foot is the original object's common opaque foot baseline.
	var factor:=height/(source_height if source_height>0 else float(foot[1]))
	sprite.scale=Vector2.ONE*factor
	sprite.position=root-Vector2(foot[0],foot[1])*factor
	sprite.z_index=depth
	sprite.set_meta("home_root",root)
	add_child(sprite)
	placements.append({"id":id,"source":image,"region":region,"source_foot":foot,"root":[root.x,root.y],"height":height,"collision":false,"node":str(sprite.get_path())})
	return sprite

func update_focus(player_x: float,camera_x: float) -> void:
	# Names stay short. Full function/reserved explanation belongs to Home's
	# nearby context prompt; never clip a distant bilingual label at an edge.
	for id: String in slot_nodes:
		var label:=slot_nodes[id] as Label
		var entry: Dictionary=label.get_meta("home_slot")
		var near:=absf(player_x-float(entry.x))<105
		label.visible=absf(float(entry.x)-camera_x)<540
		if not label.has_meta("focused") or bool(label.get_meta("focused"))!=near:
			label.set_meta("focused",near)
			label.add_theme_font_size_override("font_size",15 if near else 12)
			label.add_theme_color_override("font_color",Color("dcc598") if near else Color("99a59c",.76))
