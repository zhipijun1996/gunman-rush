extends "res://tests/world/terrain_materials_preview.gd"
## Native renderer inspection for both stacking orders and every hazard face.
func run() -> void:
	root.size=Vector2i(1280,720)
	RenderingServer.set_default_clear_color(Color("17202e"))
	stage=Node2D.new();root.add_child(stage)
	label_at(Vector2(24,16),"可交互元素 · 原生32px拼装检查",24)
	for i: int in 2:
		var x := 32+i*608
		label_at(Vector2(x,62),"上土下砌体" if i==0 else "上砌体下土")
		compose([Rect2(x,112,544,128)],[],{"version":1,"regions":[{"id":"stack","material_id":"mill_masonry","bounds":[x,176 if i==0 else 112,544,64]}]})
	var styles := ["stone_spikes","forest_bramble","metal_spikes"]
	for i: int in styles.size():
		var x := 48+i*416
		label_at(Vector2(x,272),str(WorldSurfaceStyles.catalog().styles[styles[i]].name)+" · 四向根部")
		var host := Rect2(x+32,352,256,96)
		var spikes: Array[Dictionary] = [
			{"id":"up","bounds":[x+32,328,256,24],"facing":"up","appearance":styles[i]},
			{"id":"down","bounds":[x+32,448,256,24],"facing":"down","appearance":styles[i]},
			{"id":"left","bounds":[x+8,352,24,96],"facing":"left","appearance":styles[i]},
			{"id":"right","bounds":[x+288,352,24,96],"facing":"right","appearance":styles[i]}]
		compose([host],[],{},spikes)
	label_at(Vector2(32,524),"实体47地形 / 单向踏板 / 木踏板 / 实体载台（外观与碰撞方式独立）")
	compose([Rect2(32,600,224,64)],[],{})
	for i: int in 3:
		var surface := WorldPlatformSurface.new();surface.bounds=Rect2(336+i*304,600,224,24)
		surface.one_way=i<2;surface.appearance="timber" if i==1 else "carrier";stage.add_child(surface)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/elements/diagnostic.png")
	stage.queue_free();await process_frame;quit()
