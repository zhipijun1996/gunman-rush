class_name RegionThresholdArt
extends PlainsRoomArt
## Bounded regional threshold samples reuse the style library; no gameplay state.
var back: Sprite2D
var air_points: PackedVector2Array = []
var phase := 0.0
func _ready() -> void:
	name="RegionalArt"
	if assets.is_empty():assets=JSON.parse_string(FileAccess.get_file_as_string("res://art/world-art-v2/assets/pixel/manifest.json"))
	if props.is_empty():props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/plains_v07/manifest.json")).props
	var family := room.region_preview
	var material_unshaded:=CanvasItemMaterial.new();material_unshaded.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=material_unshaded
	var spec:Dictionary=assets.backgrounds.get(family+"_v2",assets.backgrounds[family])
	back=Sprite2D.new();back.texture=load("res://art/world-art-v2/"+str(spec.file));back.z_index=-100;back.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(back)
	var ambient_color := {"thorn_forest":"a8c2bd","mushroom_caverns":"9ca7c0","firefly_marsh":"adc7bc","moonshadow_cemetery":"abb1c6","moon_crown_castle":"c2bec8","echo_mines":"b3bac6","gear_city":"b8b8b3"}
	ambient=CanvasModulate.new();ambient.color=Color(ambient_color[family]);add_child(ambient)
	# A small regional lantern is attached to the actual far bank, not a screen edge.
	var terrain_spec:Dictionary=assets.terrains[family]
	var prefix:=str(terrain_spec.asset).trim_suffix("_terrain")
	var lamp_id:=prefix+"_lamp"
	if assets.sprites.has(lamp_id):
		var extent:=FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units).size
		var floor_height:=448.0 if room.start_point.y>400 and extent.y==640 and room.room_id!="K-R01" else extent.y-64
		var foot:=Vector2(extent.x*.5,floor_height)
		var lamp:=sprite(lamp_id,foot,-3)
		var light:=add_lamp(lamp.position+Vector2(0,-lamp.texture.get_height()*.55))
		light.color=Color("8ed9c3") if family in ["mushroom_caverns","firefly_marsh"] else Color("e4c497")
		light.energy=.8
	for i:int in 14:air_points.append(Vector2(37+i*83,52+posmod(i*131,520)))
func _process(delta:float)->void:
	if back==null:return
	var camera:=get_viewport().get_camera_2d()
	if camera!=null:
		var span:=get_viewport_rect().size/camera.zoom
		back.scale=Vector2.ONE*ceilf(maxf(span.x/back.texture.get_width(),span.y/back.texture.get_height()))
		back.position=camera.get_screen_center_position().round()
	phase+=delta;queue_redraw()
func _draw()->void:
	for i:int in air_points.size():
		var at:=air_points[i]+Vector2(sin(phase*.35+i)*8,sin(phase*.5+i)*5)
		draw_rect(Rect2(at.round(),Vector2.ONE),Color(.75,.89,.73,.25+.15*sin(phase+i)))
