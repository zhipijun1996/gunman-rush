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
var layers3: Array[Sprite3D] = []
var thicknesses: Array[float] = []
var samples: Array[Dictionary] = []

func _ready() -> void:
	recording = "--capture" in OS.get_cmdline_user_args()
	ortho = "--ortho" in OS.get_cmdline_user_args()
	RenderingServer.set_default_clear_color(Color("10191e"))
	flat = viewport_panel(0)
	spatial = viewport_panel(640)
	flat.disable_3d = true
	flat.world_2d = World2D.new()
	spatial.own_world_3d = true
	var scene2 := Node2D.new(); flat.add_child(scene2)
	var scene3 := Node3D.new(); spatial.add_child(scene3)
	camera2 = Camera2D.new(); camera2.zoom = Vector2(.75,.75); scene2.add_child(camera2)
	camera3 = Camera3D.new(); camera3.fov = 38; camera3.near = .1; camera3.far = 100; scene3.add_child(camera3)
	var environment := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("10191e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9cbdc7"); env.ambient_light_energy = .7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env; scene3.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-35,-25,0); light.light_color = Color("e8d9af"); light.shadow_enabled = true; light.light_energy = .9; scene3.add_child(light)
	# A shared source list; depth and extrusion are the experimental variables.
	piece("mill_hall_depth",Vector2(800,260),Vector2(1728,1152),-560,Color(.55,.65,.7))
	piece("mill_window_bay",Vector2(800,260),Vector2(344,768),-300,Color(.7,.8,.83))
	for x: float in [300.0,1300.0]:
		piece("mill_drive_frame",Vector2(x,420),Vector2(238,320),-180,Color(.55,.65,.68))
	for x: float in [420.0,1180.0]:
		piece("mill_gear",Vector2(x,300),Vector2(142,144),-80,Color(.8,.8,.7))
	# Doorway posts, lintel, walkable stage and side platforms have actual depth.
	block(Rect2(-300,600,2200,160),130,Color("516166"))
	block(Rect2(610,270,48,330),150,Color("818173"))
	block(Rect2(942,270,48,330),150,Color("818173"))
	block(Rect2(580,238,440,48),150,Color("a29978"))
	block(Rect2(320,442,190,32),80,Color("8d8066"))
	block(Rect2(1090,442,190,32),80,Color("8d8066"))
	for x: float in [440.0,1160.0]:
		piece("mill_post_segment",Vector2(x,504),Vector2(48,192),170,Color("536364"))
		piece("mill_gear",Vector2(x,380),Vector2(142,144),170,Color("667473"))
	for p: Dictionary in pieces:
		var texture: Texture2D = load(p.path)
		var sprite := Sprite2D.new(); sprite.texture = texture; sprite.position = p.at; sprite.scale = p.size / texture.get_size(); sprite.modulate = p.tint; sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; sprite.z_index = int(p.depth); scene2.add_child(sprite)
		var plane := Sprite3D.new(); plane.texture = texture; plane.pixel_size = 1.0 / U; plane.position = point3(p.at,p.depth); plane.scale = Vector3(p.size.x / texture.get_width(),p.size.y / texture.get_height(),1); plane.modulate = p.tint; plane.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; plane.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD; plane.no_depth_test = false; scene3.add_child(plane); plane.set_meta("original_depth",p.depth); layers3.append(plane)
	hero = CharacterBody2D.new(); hero.position = Vector2(760,570); scene2.add_child(hero)
	var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(24,44); collision.shape = shape; collision.position.y = -22; hero.add_child(collision)
	var tex := AtlasTexture.new(); tex.atlas = load("res://assets/underworld_plains/player_animation/run_sheet.png"); tex.region = Rect2(0,0,80,64)
	actor2 = Sprite2D.new(); actor2.texture = tex; actor2.offset = Vector2(0,-26); actor2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; hero.add_child(actor2)
	actor3 = Sprite3D.new(); actor3.texture = tex; actor3.pixel_size = 1.0 / U; actor3.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; actor3.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD; scene3.add_child(actor3)
	var floor_body := StaticBody2D.new(); scene2.add_child(floor_body)
	for r: Rect2 in [Rect2(-300,600,2200,160),Rect2(320,442,190,32),Rect2(1090,442,190,32)]:
		var c := CollisionShape2D.new(); var s := RectangleShape2D.new(); s.size = r.size; c.shape = s; c.position = r.get_center(); floor_body.add_child(c)
	label_at("2D · 同素材平面参照",Vector2(20,12),22)
	projection_label = label_at("",Vector2(660,12),22)
	label_at("← → / A D 移动   空格跳跃   O 正交/透视   Z 厚度开关",Vector2(20,675),17)
	label_at("独立视觉实验 · 共用2D碰撞 / 非正式关卡",Vector2(660,675),16)
	DirAccess.make_dir_recursive_absolute("res://build/depth-lab")
	print("DEPTH LAB READY: same textures / shared physics / fixed camera orientation")

func viewport_panel(x: int) -> SubViewport:
	var container := SubViewportContainer.new(); container.position = Vector2(x,60); container.size = Vector2(640,600); add_child(container)
	var viewport := SubViewport.new(); viewport.size = Vector2i(640,600); viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; container.add_child(viewport); return viewport

func label_at(text: String,at: Vector2,font_size: int) -> Label:
	var label := Label.new(); label.text = text; label.position = at; label.add_theme_font_size_override("font_size",font_size); add_child(label); return label

func piece(asset: String,at: Vector2,dimensions: Vector2,depth: float,tint: Color) -> void:
	var path := NATIVE+asset+".png"; pieces.append({"path":path,"at":at,"size":dimensions,"depth":depth,"tint":tint}); source_images.append(path)

func point3(p: Vector2,depth: float = 0) -> Vector3:
	return Vector3(p.x/U,-p.y/U,depth/U)

func block(rect: Rect2,depth: float,tint: Color) -> void:
	# Identical masonry front image in both views; side faces exist only in 3D.
	var atlas: Texture2D = load(NATIVE+"mill_masonry_atlas47.png")
	var image := atlas.get_image().get_region(Rect2i(0,160,32,32))
	var tile := ImageTexture.create_from_image(image)
	var front := Polygon2D.new(); front.polygon = PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]); front.texture = tile; front.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED; front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; front.color = tint; flat.add_child(front)
	var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = Vector3(rect.size.x/U,rect.size.y/U,depth/U); mesh.mesh = box; mesh.position = point3(rect.get_center(),-depth/2)
	var material := StandardMaterial3D.new(); material.albedo_texture = tile; material.albedo_color = tint; material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; material.uv1_triplanar = true; material.uv1_world_triplanar = true; material.uv1_scale = Vector3(2,2,2); material.roughness = 1; mesh.material_override = material; spatial.add_child(mesh); bodies3.append(mesh); thicknesses.append(depth)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_O: ortho = not ortho
		if event.physical_keycode == KEY_Z:
			depth_enabled = not depth_enabled
			for i: int in bodies3.size():
				(bodies3[i].mesh as BoxMesh).size.z = thicknesses[i]/U if depth_enabled else .01
				bodies3[i].position.z = -thicknesses[i]/2/U if depth_enabled else -.005
			for layer: Sprite3D in layers3: layer.position.z = float(layer.get_meta("original_depth"))/U if depth_enabled else float(layer.get_meta("original_depth"))*.01/U

func _physics_process(delta: float) -> void:
	if hero == null: return
	elapsed += delta; frame += 1
	var axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	if recording: axis = .75*cos(elapsed*.6)
	hero.velocity.x = axis*140; hero.velocity.y += 1000*delta
	if not recording and Input.is_physical_key_pressed(KEY_SPACE) and hero.is_on_floor(): hero.velocity.y = -600
	hero.move_and_slide()
	actor2.flip_h = axis < 0; actor3.flip_h = actor2.flip_h
	var anim := int(elapsed*9) % 8 if absf(axis) > .1 else 0
	(actor2.texture as AtlasTexture).region = Rect2(anim%4*80,anim/4*64,80,64)
	actor3.position = point3(hero.position+Vector2(0,-26),8)
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
	get_viewport().get_texture().get_image().save_png(("res://build/depth-lab/ortho-frame-%03d.png" if ortho else "res://build/depth-lab/frame-%03d.png") % index)

func finish() -> void:
	set_physics_process(false)
	await RenderingServer.frame_post_draw
	var data := {"frames":frame,"seconds":elapsed,"samples":samples,"orthographic":ortho,"assets":source_images,"camera_fov":38,"shared_physics":true,"formal_controller":false,"note":"2D reference is this experiment's flat assembly, not the full production renderer"}
	var file := FileAccess.open("res://build/depth-lab/ortho-capture.json" if ortho else "res://build/depth-lab/capture.json",FileAccess.WRITE); file.store_string(JSON.stringify(data,"\t")); print("DEPTH LAB CAPTURE COMPLETE"); get_tree().quit()
