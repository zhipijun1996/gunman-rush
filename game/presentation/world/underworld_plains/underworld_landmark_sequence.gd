class_name UnderworldLandmarkSequence
extends Node2D
## World-anchored authored groups separated by genuinely unoccupied intervals.
## The continuous meadow draws AFTER these painted shoulders to bury their roots.
const ART_SHADER := preload("res://game/presentation/world/underworld_plains/underworld_parallax_edge.gdshader")
var spec: Dictionary
var texture: Texture2D
var sprites: Array[Sprite2D] = []
var measured: Array[Dictionary] = []

func setup(configuration: Dictionary) -> void:
	spec=configuration
	texture=load("res://"+str(spec.image)) as Texture2D
	if FileAccess.file_exists("res://"+str(spec.image)):
		assert(FileAccess.get_sha256("res://"+str(spec.image))==str(spec.source_sha256))
	for i: int in 4:
		var sprite:=Sprite2D.new()
		sprite.centered=false
		sprite.texture=texture
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.region_enabled=true
		var material:=ShaderMaterial.new()
		material.shader=ART_SHADER
		material.set_shader_parameter("edge_fraction",float(spec.edge_fraction))
		material.set_shader_parameter("fog_shadow",Color(str(spec.fog_shadow)))
		material.set_shader_parameter("fog_highlight",Color(str(spec.fog_highlight)))
		material.set_shader_parameter("source_detail_retention",float(spec.source_detail_retention))
		sprite.material=material
		add_child(sprite)
		sprites.append(sprite)

func update_view(center: Vector2,size: Vector2,vertical: float,seed_key: String,home: bool) -> void:
	measured.clear()
	for sprite: Sprite2D in sprites:sprite.hide()
	var spacing:=float(spec.world_cell_wu)
	var nearest:=floori((center.x-float(spec.anchor_offset_wu))/spacing)
	var scale_height:=clampf(size.y/720.0,.75,1.25)
	var used:=0
	for index: int in range(nearest-5,nearest+6):
		var kind: String=str(spec.cycle[posmod(index,spec.cycle.size())])
		if home:
			if index!=1:continue
			kind="windmills"
		if kind=="open":continue
		var variation:=posmod((seed_key+"/landscape/"+str(index)).hash(),401)-200
		var anchor:=float(spec.anchor_offset_wu)+float(index)*spacing+float(variation)
		var group: Dictionary=spec.groups[kind]
		var crop_data: Array=group.crop
		var crop:=Rect2(float(crop_data[0]),float(crop_data[1]),float(crop_data[2]),float(crop_data[3]))
		var width:=float(group.width_wu)*scale_height*(.82 if home else 1.0)
		var factor:=width/crop.size.x
		var height:=crop.size.y*factor
		var x:=roundf(size.x*.5+(anchor-center.x)*float(spec.camera_factor_x)-width*.5)
		var bottom_ratio:=.92 if home else float(spec.bottom_ratio)
		var y:=roundf(size.y*bottom_ratio-height-vertical)
		var bounds:=Rect2(x,y,width,height)
		if not bounds.intersects(Rect2(Vector2.ZERO,size)):continue
		if used>=sprites.size():break
		var sprite:=sprites[used]
		sprite.name="Local_%s_%d"%[kind,index]
		sprite.region_rect=crop
		sprite.position=Vector2(x,y)
		sprite.scale=Vector2.ONE*factor
		(sprite.material as ShaderMaterial).set_shader_parameter("source_region",Vector4(crop.position.x/texture.get_width(),crop.position.y/texture.get_height(),crop.size.x/texture.get_width(),crop.size.y/texture.get_height()))
		sprite.show()
		measured.append({"kind":kind,"world_cell":index,"anchor_world_x":anchor,"bounds":[x,y,width,height],"crop":crop_data,"opacity":1.0,"camera_factor_x":spec.camera_factor_x,"collision":false})
		used+=1
