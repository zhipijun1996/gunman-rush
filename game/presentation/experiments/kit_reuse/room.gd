extends Node2D
## Visual laboratory only. No production registration, collision or save changes.
const CONFIG := "res://config/art/kit_reuse.json"
var config: Dictionary
var layout: Dictionary
var camera: Camera2D
var far: Sprite2D
var middle := Node2D.new()
var structure := Node2D.new()
var ground := Node2D.new()
var actor := Node2D.new()
var light: PointLight2D
var ready_to_capture := false
var room_id := "passage"
var profile := "depth"
var elapsed := 0.0
var touring := false
var middle_parallax := true

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("152537"))
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	far = sprite(config.far_plate,Vector2.ZERO,sky_layer)
	far.light_mask = 0
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE*float(config.camera_zoom)
	camera.position_smoothing_enabled = false
	add_child(camera)
	middle.name = "CompleteIndependentMiddleArches"
	middle.z_index = -20
	add_child(middle)
	structure.name = "CompleteIndependentStructure"
	structure.z_index = -10
	add_child(structure)
	ground.name = "ProductionTerrainComposer"
	add_child(ground)
	actor.name = "FormalResourceScaleReferences"
	actor.z_index = 10
	add_child(actor)
	show_room(room_id)
	ready_to_capture = true

func sprite(path: String, at: Vector2, parent: Node) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = load(path)
	node.centered = false
	node.position = at
	parent.add_child(node)
	return node

func clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()

func show_room(id: String) -> void:
	room_id = id
	layout = config.rooms[id]
	for node: Node in [middle,structure,ground,actor]: clear(node)
	for row: Dictionary in layout.arch_rows:
		for i: int in int(row.count):
			var at := Vector2(row.start[0]+544*i,row.start[1])
			sprite(config.arch,at,structure)
			if int(row.extend)>0:
				for side: int in [0,544]:
					sprite(config.pier,at+Vector2(side,608),structure)
	# A complete, independent row; no complementary whole-scene slices.
	for i: int in range(-3,14):
		var s := sprite(config.arch_half,Vector2(i*272,220),middle)
		s.light_mask = 0
	for pair: Array in [["ground",config.terrain_material],["masonry",config.masonry_material]]:
		var rects: Array[Rect2] = []
		for r: Array in layout[pair[0]]: rects.append(Rect2(r[0],r[1],r[2],r[3]))
		var groups: Array[Dictionary] = [{"material_id":pair[1],"bare":false,"solids":rects,"polygons":[] as Array[Dictionary]}]
		ground.add_child(TerrainComposer.compose({"geometry":TerrainGeometry.plan(rects,[] as Array[Dictionary]),"groups":groups}))
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UnderworldPlayer.BUILD_PATH))
	var hero := Sprite2D.new()
	var frame := AtlasTexture.new()
	frame.atlas = load("res://assets/underworld_plains/player_animation/states_sheet.png")
	frame.region = Rect2(0,0,80,64)
	hero.texture = frame
	hero.position = Vector2(layout.hero_foot[0],layout.hero_foot[1])
	hero.offset = Vector2(0,-26)
	hero.scale = Vector2.ONE*44.0/float(spec.standing_body_source_height)
	hero.light_mask = 0
	actor.add_child(hero)
	var components: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/presentation/world/resources/visual_development/p1_unity_components.json"))
	var part: Dictionary = components.components.chime
	var bell := Sprite2D.new()
	var bell_frame := AtlasTexture.new()
	bell_frame.atlas = load("res://assets/visual_development/p1_unity/components.png")
	bell_frame.region = Rect2(part.region[0],part.region[1],part.region[2],part.region[3])
	bell.texture = bell_frame
	bell.centered = false
	bell.offset = -Vector2(part.pivot[0],part.pivot[1])
	bell.position = Vector2(layout.bell[0],layout.bell[1])
	bell.scale = Vector2.ONE*52.0/385.0
	actor.add_child(bell)
	var gradient := Gradient.new()
	gradient.set_color(0,Color.WHITE)
	gradient.set_color(1,Color(1,1,1,0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256; texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5); texture.fill_to = Vector2(1,.5)
	light = PointLight2D.new()
	light.texture = texture
	light.texture_scale = float(config.light.radius)*2.0/256.0
	light.position = bell.position
	light.color = Color(config.light.color)
	light.shadow_enabled = false
	actor.add_child(light)
	set_profile(profile)
	set_view(Vector2(layout.camera[0],layout.camera[1]))
	elapsed = 0

func set_profile(id: String) -> void:
	profile = id
	var values: Dictionary = config.profiles[id]
	far.modulate = Color(values.far)
	middle.modulate = Color(values.middle)
	middle.visible = bool(values.middle_visible)
	structure.modulate = Color(values.structure)
	light.energy = values.light_energy

func set_view(at: Vector2) -> void:
	camera.position = at.round()
	camera.force_update_scroll()
	# Deliberately explicit depth ownership: sky screen-fixed, middle horizontal .18,
	# structure and terrain fully world-attached. Disabling is a real transform.
	var factor := Vector2(.18,0) if middle_parallax else Vector2.ONE
	middle.position = ((at-Vector2(640,360))*(Vector2.ONE-factor)).round()

func path_at(progress: float) -> Vector2:
	var points: Array = layout.path
	var t := clampf(progress,0,.999999)*float(points.size()-1)
	var i := floori(t)
	return Vector2(points[i][0],points[i][1]).lerp(Vector2(points[i+1][0],points[i+1][1]),t-i)

func _process(delta: float) -> void:
	if touring:
		elapsed += delta
		set_view(path_at(fmod(elapsed/12.0,1.0)))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1: show_room("passage")
		KEY_2: show_room("shaft")
		KEY_3: show_room("hall")
		KEY_SPACE: touring = not touring
		KEY_F: set_profile("flat" if profile=="depth" else "depth")
		KEY_B: structure.visible = not structure.visible
		KEY_M: middle.visible = not middle.visible
		KEY_L: light.enabled = not light.enabled
