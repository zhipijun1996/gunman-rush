extends SceneTree
## Real Godot diagnostic composition, not a finished room or playability claim.
var stage: Node2D
var moving_camera: Camera2D
func _initialize() -> void: run.call_deferred()
func label_at(at: Vector2, text: String, size := 18) -> void:
	var label := Label.new();label.position=at;label.text=text
	label.add_theme_font_size_override("font_size",size);stage.add_child(label)
func compose(solids: Array[Rect2], polygons: Array[Dictionary], paint: Dictionary, spikes: Array[Dictionary]=[]) -> void:
	var groups: Array[Dictionary]=[{"material_id":"windchime_plains","solids":solids,"polygons":polygons,"bare":false}]
	stage.add_child(TerrainComposer.compose({"groups":groups,"geometry":TerrainGeometry.plan(solids,polygons)},paint,spikes))
	if not spikes.is_empty():
		var art:=WorldSpikeArt.new();stage.add_child(art);art.setup(spikes,solids)
func run() -> void:
	root.size=Vector2i(1280,720)
	RenderingServer.set_default_clear_color(Color("17202e"))
	stage=Node2D.new();root.add_child(stage)
	label_at(Vector2(40,20),"Terrain & Material · 原生32px / 共享轮廓 / 真实Godot渲染",24)
	label_at(Vector2(40,70),"异材质接触 + 中间3格地刺（几何不变）")
	var solids: Array[Rect2]=[Rect2(40,160,544,112)]
	var spikes: Array[Dictionary]=[{"id":"spikes","bounds":[168,128,96,32],"facing":"up"}]
	compose(solids,[],{"version":1,"regions":[{"id":"stone","bounds":[376,160,208,112],"material_id":"mill_masonry"}]},spikes)
	label_at(Vector2(680,70),"洞口 / 薄柱 / 多材质交点")
	compose([Rect2(680,128,256,32),Rect2(680,160,32,112),Rect2(904,160,32,112),Rect2(680,240,256,32),Rect2(936,192,224,80)],[],{"version":1,"regions":[{"id":"forest","bounds":[808,112,96,176],"material_id":"thorn_forest"},{"id":"stone","bounds":[904,176,256,112],"material_id":"mill_masonry"}]})
	label_at(Vector2(40,310),"非整格与多边形：材质边界不生成实体描边")
	compose([],[{"points":[[40,424],[168,368],[368,368],[520,440],[520,492],[40,492]]}],{"version":1,"regions":[{"id":"stone","bounds":[247,352,128,160],"material_id":"mill_masonry"}]})
	label_at(Vector2(680,310),"上下分层 / 四向外露表面 / 明确硬接缝回退")
	compose([Rect2(680,384,480,112)],[],{"version":1,"regions":[{"id":"forest","bounds":[680,432,480,64],"material_id":"thorn_forest"}],"surfaces":[{"id":"bare","surface_id":"bare","facing":"up","bounds":[776,380,96,16]},{"id":"stone","surface_id":"material","material_id":"mill_masonry","facing":"right","bounds":[1152,384,16,112]}]})
	label_at(Vector2(40,530),"16区已登记素材（仅技术样片，不代表新房间美术终审）")
	var index:=0
	for family: String in TerrainMaterialRegistry.catalog().regions:
		var x:=40+(index%8)*150;var y:=584+(index/8)*64
		var rects: Array[Rect2]=[Rect2(x,y,112,32)]
		var groups: Array[Dictionary]=[{"material_id":family,"solids":rects,"polygons":[] as Array[Dictionary],"bare":false}]
		stage.add_child(TerrainComposer.compose({"groups":groups,"geometry":TerrainGeometry.plan(rects,[])}))
		index+=1
	DirAccess.make_dir_recursive_absolute("res://build/terrain-materials")
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/terrain-materials/diagnostic.png")
	print("TERRAIN CAPTURE READY")
	if "--motion" in OS.get_cmdline_user_args():
		moving_camera=Camera2D.new();moving_camera.position=Vector2(640,360);stage.add_child(moving_camera)
		var start:=Time.get_ticks_msec()
		while Time.get_ticks_msec()-start<8000:
			var seconds:=float(Time.get_ticks_msec()-start)/1000.0
			moving_camera.position=Vector2(640+round(sin(seconds*TAU/8.0)*32),360)
			await process_frame
	stage.queue_free();await process_frame
	print("TERRAIN PREVIEW: rendered native diagnostic")
	quit()
