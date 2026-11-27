@tool
class_name WorldForegroundCover
extends Node2D
const CHUNK := 192
const SAMPLE_PX := 6
const COVER := preload("res://game/world/elements/perception/foreground_cover.gdshader")
const DEFAULT_VINES := preload("res://assets/world_elements/native/hanging_vines.png")
@export var element_id := ""
@export var state_scope := "attempt"
@export var section_id := "main"
@export var bounds := Rect2(0,0,192,160)
@export_file var texture_path := "":
	set(value):
		texture_path = value
		queue_redraw()
@export var reveal_radius := 80.0
@export var revealed_alpha := 0.15
@export var fade_out_s := 0.20
@export var restore_s := 0.35
var skin: Texture2D
var player: CollisionShape2D
var chunks := {}

static func validate_configuration(p: Dictionary,_row: Dictionary,_doc: Dictionary) -> String:
	if p.reveal_radius <= 0: return "reveal_radius:positive_required"
	if p.revealed_alpha > 1.0: return "revealed_alpha:maximum_one"
	var path: String = p.get("texture_path","")
	if not path.is_empty() and load_instance_texture(path)==null: return "texture_path:project_texture_required"
	return ""

static func load_instance_texture(path: String) -> Texture2D:
	if not path.begins_with("res://") or path.contains("\\") or path.contains("::") or path!=path.simplify_path(): return null
	if not ResourceLoader.exists(path,"Texture2D"): return null
	return ResourceLoader.load(path,"Texture2D") as Texture2D

func resolved_texture() -> Texture2D:
	if not texture_path.is_empty(): return load_instance_texture(texture_path)
	return load(WorldElementCatalog.skin_value(self,"zone.foreground_cover","texture",DEFAULT_VINES.resource_path))

func element_bind(context: Dictionary) -> void:
	player = context.controller.motor.get_node("CollisionShape2D")
	skin = resolved_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = 6
	queue_redraw()

func element_state() -> Dictionary: return {}
func element_restore(_state: Dictionary) -> void:
	for tile: Dictionary in chunks.values(): tile.rect.free()
	chunks.clear()
	queue_redraw()

func make_tile(at: Vector2i) -> Dictionary:
	var area := Rect2(bounds.position+Vector2(at)*CHUNK,Vector2.ONE*CHUNK).intersection(bounds)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = area.position; rect.size = area.size
	var material_value := ShaderMaterial.new()
	material_value.shader = COVER
	var dimensions := Vector2i(maxi(1,ceili(area.size.x/SAMPLE_PX)),maxi(1,ceili(area.size.y/SAMPLE_PX)))
	var image := Image.create_empty(dimensions.x,dimensions.y,false,Image.FORMAT_R8)
	var texture := ImageTexture.create_from_image(image)
	material_value.set_shader_parameter("vines",skin)
	material_value.set_shader_parameter("texture_origin",(area.position-bounds.position)/skin.get_size())
	material_value.set_shader_parameter("texture_span",area.size/skin.get_size())
	material_value.set_shader_parameter("reveal_mask",texture)
	material_value.set_shader_parameter("revealed_alpha",revealed_alpha)
	rect.material = material_value; add_child(rect)
	var levels := PackedFloat32Array()
	levels.resize(dimensions.x*dimensions.y)
	return {"rect":rect,"area":area,"image":image,"texture":texture,"levels":levels,"open":false}

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	var at := to_local(player.global_position)
	var visible_area := get_global_transform_with_canvas().affine_inverse()*get_viewport_rect()
	var cropped := visible_area.intersection(bounds)
	var visible_tiles := {}
	var changed := false
	if cropped.has_area():
		var first := Vector2i(((cropped.position-bounds.position)/CHUNK).floor())
		var end := Vector2i(((cropped.end-bounds.position)/CHUNK).ceil())
		for y: int in range(first.y,end.y):
			for x: int in range(first.x,end.x):
				var key := Vector2i(x,y)
				visible_tiles[key] = true
				if not chunks.has(key):
					chunks[key] = make_tile(key)
					changed = true
	for key: Vector2i in chunks.keys():
		var tile: Dictionary = chunks[key]
		var area: Rect2 = tile.area
		var intersects := at.distance_to(at.clamp(area.position,area.end)) <= reveal_radius
		if intersects or tile.open: advance_tile(tile,at,delta)
		if not visible_tiles.has(key) and not tile.open:
			tile.rect.free(); chunks.erase(key)
			changed = true
	if changed: queue_redraw()

func advance_tile(tile: Dictionary, at: Vector2, delta: float) -> void:
	var area: Rect2 = tile.area
	var image: Image = tile.image
	var levels: PackedFloat32Array = tile.levels
	var size := image.get_size()
	var step := area.size/Vector2(size)
	var dirty := false
	var opened := false
	for y: int in size.y:
		for x: int in size.x:
			var i := y*size.x+x
			var point := area.position+(Vector2(x,y)+Vector2(0.5,0.5))*step
			var reveal := point.distance_squared_to(at) <= reveal_radius*reveal_radius
			var aim := 1.0 if reveal else 0.0
			var duration := fade_out_s if reveal else restore_s
			var value := aim if duration == 0 else move_toward(levels[i],aim,delta/duration)
			levels[i] = value
			if value > 0: opened = true
			var encoded := roundi(value*255)
			if image.get_pixel(x,y).r8 != encoded:
				image.set_pixel(x,y,Color8(encoded,0,0)); dirty = true
	tile.open = opened
	if dirty: tile.texture.update(image)

## Paint the unopened parts of the bounds even before the first process tick,
## after a reset, or when a cut places the camera over previously unseen tiles.
## Each position belongs to either a masked chunk or the closed artwork.
func closed_regions() -> Array[Rect2]:
	var regions: Array[Rect2] = []
	var columns := {}
	for key: Vector2i in chunks:
		if not columns.has(key.y): columns[key.y]=[]
		columns[key.y].append(key.x)
	var rows := columns.keys()
	rows.sort()
	var bottom := bounds.position.y
	for y: int in rows:
		var top := bounds.position.y+y*CHUNK
		if top>bottom: regions.append(Rect2(bounds.position.x,bottom,bounds.size.x,top-bottom))
		bottom=minf(top+CHUNK,bounds.end.y)
		var left := bounds.position.x
		columns[y].sort()
		for x: int in columns[y]:
			var area: Rect2=chunks[Vector2i(x,y)].area
			if area.position.x>left: regions.append(Rect2(left,top,area.position.x-left,bottom-top))
			left=area.end.x
		if left<bounds.end.x: regions.append(Rect2(left,top,bounds.end.x-left,bottom-top))
	if bottom<bounds.end.y: regions.append(Rect2(bounds.position.x,bottom,bounds.size.x,bounds.end.y-bottom))
	return regions

func _draw() -> void:
	if Engine.is_editor_hint():
		var preview := resolved_texture()
		if preview!=null: draw_texture_rect(preview,bounds,true)
		return
	if skin==null: return
	for area: Rect2 in closed_regions():
		draw_texture_rect_region(skin,area,Rect2(area.position-bounds.position,area.size),Color.WHITE,false,false)
