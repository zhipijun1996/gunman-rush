extends SceneTree
## Actual PR142 rooms/camera/tiles/light/UI; only static art placement is a fixture.
## No combat, movement, collision or animation acceptance is implied.
const ART := "res://art/reviews/plains_enemies_pr142/static/"
const DEST := "res://build/plains_enemies_pr142/color-c/context/"
const BASELINE := "res://build/plains_enemies_pr142/color-c/baseline/"
const SAMPLES := "res://art/reviews/plains_enemies_pr142/pixel_samples/static/"
const SAMPLE_DEST := "res://build/plains_enemies_pr142/pixel-d/context/"
var sample_mode := "sample-d" in OS.get_cmdline_user_args()
var rejected_material: Shader
var app: FixedWorldApp
var records: Array[Dictionary] = []
var sprites: Array[Sprite2D] = []
var note: Label
var current_title := ""
var shots := [
	{"id":"01-meadow","room":"P-R03","player":Vector2(860,398),"title":"草坡 / 亮天空与草沿", "poses":[["patrol",Vector2(650,464)],["charger",Vector2(960,416)],["hopper",Vector2(1200,368)]]},
	{"id":"02-junction","room":"P-R06","player":Vector2(1130,878),"title":"岔路 / 建筑、草沿与远景", "poses":[["sentry",Vector2(1015,896)],["root_bell",Vector2(1280,896)],["fan_sentry",Vector2(1430,896)],["diver",Vector2(1190,710)]]},
	{"id":"03-interior","room":"P-R10","player":Vector2(1050,1326),"title":"风车室内 / 木墙与砌石TileSet", "poses":[["sentry",Vector2(800,1344)],["root_bell",Vector2(1210,1344)],["fan_sentry",Vector2(1390,1344)],["diver",Vector2(1050,1180)]]},
	{"id":"04-bellstrider","room":"P-R11","player":Vector2(1240,878),"title":"巡游机 / 正式竞技场", "poses":[["bellstrider",Vector2(1450,896)]]},
	{"id":"05-keeper-one","room":"P-R14","player":Vector2(1080,742),"title":"牧风者一阶段 / 正式竞技场", "poses":[["windkeeper_phase1",Vector2(1280,760)]]},
	{"id":"06-keeper-two","room":"P-R14","player":Vector2(1080,742),"title":"牧风者二阶段 / 头顶风车与视野", "poses":[["windkeeper_phase2",Vector2(1280,760)]]},
]

func _initialize() -> void: run.call_deferred()
func ticks(count: int) -> void:
	for i: int in count: await physics_frame
func settle() -> void:
	for i: int in 240:
		await physics_frame
		if not app.busy: return
	assert(false,"room load did not settle")

func add_static(id: String, foot: Vector2) -> void:
	var im := Image.load_from_file(ART+id+".png")
	assert(im != null and not im.is_empty())
	var sprite := Sprite2D.new()
	sprite.name=id
	sprite.texture=ImageTexture.create_from_image(im)
	sprite.centered=false
	sprite.offset=Vector2(-floorf(im.get_width()*.5),-im.get_height())
	sprite.position=foot
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index=1
	# Static pose faces the player's actual fixture location.
	if foot.x>app.player.position.x:sprite.scale.x=-1
	app.room.add_child(sprite)
	sprites.append(sprite)

func snap(id: String, variant: String) -> void:
	var titles := {"B":"B 旧配色", "C":"C 主色块重绘", "D":"D 收色与像素簇样板"}
	note.text=current_title+"  |  "+titles[variant]+"\n正式TileSet / 原镜头与光照 / 静态试摆，非战斗或动画"
	for sprite: Sprite2D in sprites:
		var folder: String = SAMPLES if variant=="D" else (BASELINE+"static/" if variant=="B" else ART)
		var path: String=folder+String(sprite.name)+".png"
		var im:=Image.load_from_file(path)
		assert(im!=null and not im.is_empty(),"Prepare baseline with package_plains_enemy_context.py --prepare-baseline")
		sprite.texture=ImageTexture.create_from_image(im)
		sprite.offset=Vector2(-floorf(im.get_width()*.5),-im.get_height())
		if variant=="B":
			var mat:=ShaderMaterial.new();mat.shader=rejected_material;sprite.material=mat
		else: sprite.material=null
	await process_frame
	await RenderingServer.frame_post_draw
	var filename: String=(SAMPLE_DEST if sample_mode else DEST)+id+"-"+variant+".png"
	assert(root.get_texture().get_image().save_png(filename)==OK)
	var row: Dictionary={"case":id,"variant":variant,"room":app.room.room_id,"file":filename,"camera":str(app.camera.global_position),"zoom":str(app.camera.zoom),"player":str(app.player.global_position),"sprites":[]}
	for sprite: Sprite2D in sprites:
		var box: Rect2=sprite.get_global_transform_with_canvas()*sprite.get_rect()
		row.sprites.append({"id":sprite.name,"feet":str(sprite.position),"native_size":str(sprite.texture.get_size()),"screen_bounds":str(box),"inside_viewport":root.get_visible_rect().grow(.5).encloses(box)})
	records.append(row)
	print("STATIC CONTEXT ",id," ",variant," ",row.sprites)

func run() -> void:
	var destination: String = SAMPLE_DEST if sample_mode else DEST
	DirAccess.make_dir_recursive_absolute(destination)
	if not sample_mode:
		rejected_material=Shader.new()
		rejected_material.code=FileAccess.get_file_as_string(BASELINE+"readability.gdshader")
		assert(not rejected_material.code.is_empty(),"Prepare the rejected baseline first")
	root.size=Vector2i(1280,720)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://plains_enemy_static_context.json"
	app.settings_path="user://plains_enemy_static_context_settings.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle()
	var layer:=CanvasLayer.new();layer.layer=200;root.add_child(layer)
	note=Label.new();note.position=Vector2(320,14);note.add_theme_font_size_override("font_size",16)
	note.add_theme_color_override("font_outline_color",Color("142b2b"));note.add_theme_constant_override("outline_size",5);layer.add_child(note)
	for shot: Dictionary in shots:
		if sample_mode:
			if shot.id not in ["02-junction","03-interior","06-keeper-two"]:continue
		elif not OS.get_cmdline_user_args().is_empty() and shot.id not in OS.get_cmdline_user_args()[0].split(","):continue
		app.process_mode=Node.PROCESS_MODE_INHERIT
		app.load_room(shot.room,"");await settle()
		app.set_physics_process(false);app.controller.active=false
		for actor: EnemyActor in app.room.enemies.values():
			actor.set_physics_process(false);actor.motor.hide()
		if app.room.encounter!=null:app.room.encounter.set_physics_process(false)
		if app.room.boss!=null:app.room.boss.hide()
		app.player.reset_at(shot.player)
		app._update_hud()
		current_title=shot.title
		app.player.set_physics_process(false)
		(app.camera as WorldCamera).enter_room(FixedWorldProvider.rect(app.room.contract.world_geometry.bounds_world_units))
		await ticks(90)
		app.process_mode=Node.PROCESS_MODE_DISABLED
		sprites.clear()
		for pose: Array in shot.poses:
			if sample_mode and pose[0] not in ["sentry","windkeeper_phase2"]:continue
			add_static(pose[0],pose[1])
		await snap(shot.id,"C" if sample_mode else "B")
		await snap(shot.id,"D" if sample_mode else "C")
	var file:=FileAccess.open(destination+"capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"PR142 actual runtime scenery with frozen static approval fixtures; no combat or motion acceptance","shots":records},"\t"));file.close()
	app.process_mode=Node.PROCESS_MODE_INHERIT
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	quit()
