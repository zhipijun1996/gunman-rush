extends Control
## Isolated rendering experiment. Shared 2D physics owns both representations.
const U := 64.0
const NATIVE := "res://assets/plains_v07/native/"
var flat: SubViewport
var spatial: SubViewport
var camera2: Camera2D
var camera3: Camera3D
var hero: CharacterBody2D
var actor2: Sprite2D
var actor3: Sprite3D
var elapsed := 0.0
var frame := 0
var recording := false
var projection_label: Label
var pieces: Array[Dictionary] = []
var source_images: Array[String] = []
var camera_center := Vector2(800,330)
var depth_enabled := true
var ortho := false
var bodies3: Array[MeshInstance3D] = []
var solids: Array[Rect2] = []
var terrain_report: Dictionary = {}
var ready_to_run := false
var hero_shadow: MeshInstance3D
var layers3: Array[Sprite3D] = []
var samples: Array[Dictionary] = []
var outdoor := false
var output := "res://build/depth-lab"

func _ready() -> void:
	recording = "--capture" in OS.get_cmdline_user_args()
	outdoor = "--outdoor" in OS.get_cmdline_user_args()
	if outdoor: output += "/outdoor"
	ortho = "--ortho" in OS.get_cmdline_user_args()
	RenderingServer.set_default_clear_color(Color("526879") if outdoor else Color("10191e"))
	flat = viewport_panel(0)
	spatial = viewport_panel(640)
	flat.disable_3d = true
	flat.world_2d = World2D.new()
	spatial.own_world_3d = true
	DirAccess.make_dir_recursive_absolute(output)
	var scene2 := Node2D.new(); flat.add_child(scene2)
	var scene3 := Node3D.new(); spatial.add_child(scene3)
	camera2 = Camera2D.new(); camera2.zoom = Vector2(.75,.75); scene2.add_child(camera2)
	camera3 = Camera3D.new(); camera3.fov = 38; camera3.near = .1; camera3.far = 100; scene3.add_child(camera3)
	var environment := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("526879") if outdoor else Color("10191e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d4dce2"); env.ambient_light_energy = .72
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env; scene3.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-35,-25,0); light.light_color = Color("e8d9af"); light.shadow_enabled = true; light.light_energy = .45; scene3.add_child(light)
	# Both representations consume the same authored pieces and solid rectangles.
	if outdoor:
		build_outdoor()
	else:
		piece("mill_hall_depth",Vector2(800,260),-400,Color(.65,.72,.78),true)
		piece("mill_window_bay",Vector2(800,260),-180,Color(.8,.85,.9),true)
		grounded("mill_drive_frame",Vector2(420,600),Vector2(119,320),1)
		grounded("mill_drive_frame",Vector2(1180,600),Vector2(119,320),1)
		piece("mill_gear",Vector2(680,360),1,Color.WHITE)
		piece("mill_gear",Vector2(920,360),1,Color.WHITE)
		block(Rect2(-300,600,2200,160),128,Color.WHITE)
		block(Rect2(610,270,48,330),128,Color.WHITE)
		block(Rect2(942,270,48,330),128,Color.WHITE)
		block(Rect2(580,238,440,48),128,Color.WHITE)
		block(Rect2(320,442,190,32),128,Color.WHITE)
		block(Rect2(1090,442,190,32),128,Color.WHITE)
		# Native post segments are stacked, not stretched into tall strips.
		for x: float in [280,1320]:
			for bottom: float in [408,472,536,600]: grounded("mill_post_segment",Vector2(x,bottom),Vector2(16,64),2,false)
	terrain_report = await preload("res://game/presentation/experiments/depth_lab/depth_terrain_bridge.gd").build(self,solids,"windchime_plains" if outdoor else "mill_masonry",scene2,scene3,128,U)
	bodies3.append(terrain_report.sides)
	terrain_report.erase("sides"); terrain_report.erase("front")
	for p: Dictionary in pieces:
		var texture := layer_texture(p)
		var sprite := Sprite2D.new(); sprite.texture = texture; sprite.position = p.at; sprite.scale = Vector2.ONE; sprite.modulate = p.tint; sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; sprite.z_index = int(p.depth); scene2.add_child(sprite)
		var plane := Sprite3D.new(); plane.texture = texture; plane.pixel_size = 1.0 / U; plane.position = point3(p.at,p.depth); plane.scale = Vector3.ONE; plane.shaded = not p.background; plane.modulate = p.tint; plane.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; plane.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD; plane.no_depth_test = false; scene3.add_child(plane); plane.set_meta("original_depth",p.depth); layers3.append(plane)
	hero = CharacterBody2D.new(); hero.position = Vector2(760,570); scene2.add_child(hero)
	var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(24,44); collision.shape = shape; collision.position.y = -22; hero.add_child(collision)
	var tex := AtlasTexture.new(); tex.atlas = load("res://assets/underworld_plains/player_animation/run_sheet.png"); tex.region = Rect2(0,0,80,64)
	actor2 = Sprite2D.new(); actor2.texture = tex; actor2.offset = Vector2(0,-26); actor2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; hero.add_child(actor2)
	actor3 = Sprite3D.new(); actor3.texture = tex; actor3.pixel_size = 1.0 / U; actor3.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; actor3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD; scene3.add_child(actor3)
	var animation_spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UnderworldPlayer.BUILD_PATH))
	var factor := 44.0/float(animation_spec.standing_body_source_height)
	actor2.scale = Vector2.ONE*factor; actor3.pixel_size = factor/U
	actor3.set_meta("anchor_offset_y",-26*factor)
	hero_shadow = contact_shadow(scene3,Vector2(760,600),Vector2(42,20),.28)
	var floor_body := StaticBody2D.new(); scene2.add_child(floor_body)
	for r: Rect2 in solids:
		var c := CollisionShape2D.new(); var s := RectangleShape2D.new(); s.size = r.size; c.shape = s; c.position = r.get_center(); floor_body.add_child(c)
	label_at("2D · 同素材平面参照",Vector2(20,12),22)
	projection_label = label_at("",Vector2(660,12),22)
	label_at("← → / A D 移动   空格跳跃   O 正交/透视   Z 厚度开关",Vector2(20,675),17)
	label_at("独立视觉实验 · 共用2D碰撞 / 非正式关卡",Vector2(660,675),16)
	DirAccess.make_dir_recursive_absolute(output)
	ready_to_run = true
	print("DEPTH LAB READY: same textures / shared physics / fixed camera orientation")

func build_outdoor() -> void:
	piece("longbridge_vista",Vector2(800,330),-700,Color(.8,.87,.91),true)
	piece("orchard",Vector2(800,345),-400,Color(.8,.88,.82),true)
	piece("orchard_ridge",Vector2(800,510),-200,Color(.85,.9,.85),true)
	piece("opening_road_ridge",Vector2(860,536),-100,Color(.9,.94,.92),true)
	block(Rect2(-300,600,2200,160),128,Color.WHITE)
	block(Rect2(320,442,190,32),128,Color.WHITE)
	block(Rect2(1090,442,190,32),128,Color.WHITE)
	grounded("orchard_arch_east",Vector2(820,602),Vector2(300,340),1)
	grounded("orchard_arch_west",Vector2(280,602),Vector2(207,243),2)
	grounded("orchard_fence",Vector2(1140,602),Vector2(80,73),2)
	grounded("orchard_fence",Vector2(470,602),Vector2(80,73),1)

func grounded(asset: String,foot: Vector2,anchor: Vector2,depth: float,shadow := true) -> void:
	var texture: Texture2D = load(NATIVE+asset+".png")
	piece(asset,foot-anchor+texture.get_size()/2,depth,Color.WHITE)
	pieces[-1]["foot"] = [foot.x,foot.y]
	pieces[-1]["anchor"] = [anchor.x,anchor.y]
	pieces[-1]["support_y"] = 600 if shadow else foot.y
	if shadow:
		var feet: Array[float] = [0.0]
		if asset == "orchard_arch_east": feet = [-250.0,250.0]
		elif asset == "orchard_arch_west": feet = [-170.0,170.0]
		elif asset == "mill_drive_frame": feet = [-90.0,90.0]
		pieces[-1]["contact_points"] = []
		for offset_x: float in feet:
			contact_shadow(spatial,Vector2(foot.x+offset_x,600),Vector2(56,22),.24)
			pieces[-1].contact_points.append([foot.x+offset_x,600])

func contact_shadow(parent: Node,at: Vector2,dimensions: Vector2,strength: float) -> MeshInstance3D:
	var node := MeshInstance3D.new(); var quad := QuadMesh.new(); quad.size = dimensions/U; node.mesh = quad; node.position = point3(at)+Vector3(0,.015,-12/U); node.rotation.x = -PI/2
	var material := ShaderMaterial.new(); material.shader = preload("res://game/presentation/experiments/depth_lab/depth_contact_shadow.gdshader"); material.set_shader_parameter("opacity",strength); node.material_override = material; parent.add_child(node); return node

func layer_texture(piece_row: Dictionary) -> Texture2D:
	var texture: Texture2D = load(piece_row.path)
	if not outdoor or not piece_row.background: return texture
	# Extend only edge scenery at native pixel density; keep the unique landmark once.
	# This is bounded coverage for this camera sweep, not an infinite seamless asset.
	var image := texture.get_image(); image.convert(Image.FORMAT_RGBA8)
	var band := 128; var padding := 1536
	var wide := Image.create(image.get_width()+padding*2,image.get_height(),false,Image.FORMAT_RGBA8)
	wide.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(padding,0))
	var left := image.get_region(Rect2i(0,0,band,image.get_height()))
	var right := image.get_region(Rect2i(image.get_width()-band,0,band,image.get_height()))
	for k: int in padding/band:
		var l := left.duplicate() as Image; var r := right.duplicate() as Image
		if k%2 == 0: l.flip_x(); r.flip_x()
		wide.blit_rect(l,Rect2i(Vector2i.ZERO,l.get_size()),Vector2i(padding-(k+1)*band,0))
		wide.blit_rect(r,Rect2i(Vector2i.ZERO,r.get_size()),Vector2i(padding+image.get_width()+k*band,0))
	return ImageTexture.create_from_image(wide)

func viewport_panel(x: int) -> SubViewport:
	var container := SubViewportContainer.new(); container.position = Vector2(x,60); container.size = Vector2(640,600); add_child(container)
	var viewport := SubViewport.new(); viewport.size = Vector2i(640,600); viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; container.add_child(viewport); return viewport

func label_at(text: String,at: Vector2,font_size: int) -> Label:
	var label := Label.new(); label.text = text; label.position = at; label.add_theme_font_size_override("font_size",font_size); add_child(label); return label

func piece(asset: String,at: Vector2,depth: float,tint: Color,background := false) -> void:
	var path := NATIVE+asset+".png"
	var texture: Texture2D = load(path)
	pieces.append({"path":path,"at":at,"size":texture.get_size(),"depth":depth,"tint":tint,"background":background,"world_units_per_pixel":1})
	source_images.append(path)

func point3(p: Vector2,depth: float = 0) -> Vector3:
	return Vector3(p.x/U,-p.y/U,depth/U)

func block(rect: Rect2,_depth: float,_tint: Color) -> void:
	solids.append(rect)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_O: ortho = not ortho
		if event.physical_keycode == KEY_Z:
			depth_enabled = not depth_enabled
			for i: int in bodies3.size():
				bodies3[i].scale.z = 1.0 if depth_enabled else .01
			for layer: Sprite3D in layers3: layer.position.z = float(layer.get_meta("original_depth"))/U if depth_enabled else float(layer.get_meta("original_depth"))*.01/U

func _physics_process(delta: float) -> void:
	if not ready_to_run: return
	elapsed += delta; frame += 1
	var axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	if recording: axis = .75*cos(elapsed*.6)
	hero.velocity.x = axis*140; hero.velocity.y += 1000*delta
	if not recording and Input.is_physical_key_pressed(KEY_SPACE) and hero.is_on_floor(): hero.velocity.y = -600
	hero.move_and_slide()
	actor2.flip_h = axis < 0; actor3.flip_h = actor2.flip_h
	var anim := int(elapsed*9) % 8 if absf(axis) > .1 else 0
	(actor2.texture as AtlasTexture).region = Rect2(anim%4*80,anim/4*64,80,64)
	actor3.position = point3(hero.position+Vector2(0,float(actor3.get_meta("anchor_offset_y"))),3)
	hero_shadow.position.x = hero.position.x/U
	if hero.is_on_floor(): hero_shadow.position.y = -hero.position.y/U+.015
	hero_shadow.visible = hero.is_on_floor()
	if recording: camera_center = Vector2(800+sin(elapsed*.55)*230,330+sin(elapsed*.3)*36)
	else: camera_center = camera_center.lerp(Vector2(hero.position.x,330),.04)
	camera2.position = camera_center
	camera3.projection = Camera3D.PROJECTION_ORTHOGONAL if ortho else Camera3D.PROJECTION_PERSPECTIVE
	camera3.size = 800/U
	camera3.position = point3(camera_center, (800/2)/tan(deg_to_rad(38.0/2)))
	projection_label.text = "3D · "+("正交" if ortho else "透视 38°")+" · 纵深与体块"
	if recording and frame in [2,240,480,719]:
		var measured := {"frame":frame,"camera":[camera_center.x,camera_center.y],"points":{}}
		for z: float in [-560.0,0.0,170.0]:
			var p := camera3.unproject_position(point3(Vector2(800,500),z))
			measured.points[str(z)] = [p.x,p.y]
		samples.append(measured)
		capture.call_deferred(frame)
	if recording and frame >= 720: finish.call_deferred()

func capture(index: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+("/ortho-frame-%03d.png" if ortho else "/frame-%03d.png") % index)

func finish() -> void:
	set_physics_process(false)
	await RenderingServer.frame_post_draw
	var data := {"composition_schema":2,"terrain":terrain_report,"asset_placement":pieces,"lighting":"lit terrain and local props; unlit atmospheric backgrounds; original-color actor","frames":frame,"seconds":elapsed,"samples":samples,"orthographic":ortho,"assets":source_images,"camera_fov":38,"shared_physics":true,"formal_controller":false,"note":"2D reference is this experiment's flat assembly, not the full production renderer"}
	var file := FileAccess.open(output+("/ortho-capture.json" if ortho else "/capture.json"),FileAccess.WRITE); file.store_string(JSON.stringify(WorldRoomDocument.encode(data),"\t")); print("DEPTH LAB CAPTURE COMPLETE"); get_tree().quit()
