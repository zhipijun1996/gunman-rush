class_name ForestBibleTerrainMaterial
extends RefCounted
## Forest material extension of the same 47-tile / exact-boundary family.
## Owns no geometry, collision, masks, neighbors, or shader implementation.
# FINE-SPACE-05: selected shared1wu grid, distinct living bark/root material.
# Original v2 and rejected v3 remain unchanged as historical assets.
const SOURCE: Texture2D = preload("res://assets/forest_bible_v2/native/fine_32/bark_source.png")
const ATLAS: Texture2D = preload("res://assets/forest_bible_v2/native/fine_32/bark_atlas47.png")
const DECK: Texture2D = preload("res://assets/forest_bible_v2/native/fine_32/bark_deck.png")

static func install_on(terrain: UnderworldTerrain) -> bool:
	if not is_instance_valid(terrain) or not is_instance_valid(terrain.core_layer): return false
	if SOURCE.get_size() != Vector2(1056, 288) or ATLAS.get_size() != Vector2(768, 192): return false
	var original: TileSet = terrain.core_layer.tile_set
	if original == null or original.tile_size != Vector2i(32, 32): return false
	if not original.has_source(0) or not original.get_source(0) is TileSetAtlasSource: return false
	# Validate every adapter consumer before changing either material path.
	var adapters: Array[ColorRect] = []
	for child: Node in terrain.get_children():
		if not child is ColorRect: continue
		var quad := child as ColorRect
		if not quad.material is ShaderMaterial: return false
		var material := quad.material as ShaderMaterial
		if material.shader != UnderworldTerrain.SHADER: return false
		if material.get_shader_parameter("source_size") != Vector2(1056, 288): return false
		adapters.append(quad)
	var tiles: TileSet = original.duplicate(true) as TileSet
	var atlas: TileSetAtlasSource = tiles.get_source(0) as TileSetAtlasSource
	atlas.texture = ATLAS
	terrain.core_layer.tile_set = tiles
	for quad: ColorRect in adapters:
		var material: ShaderMaterial = quad.material.duplicate() as ShaderMaterial
		material.set_shader_parameter("source_pixels", SOURCE)
		material.set_shader_parameter("source_size",Vector2(SOURCE.get_size()))
		quad.material = material
	terrain.set_meta("forest_material_generation","FINE-SPACE-05/bark_fine32")
	return true

static func draw_one_way(canvas: Node2D,rect: Rect2) -> void:
	# Distinct grown-bark open deck; no copper/plain grass line and no collider.
	var height:=minf(8.0,maxf(6.0,rect.size.y))
	var left:=minf(8.0,rect.size.x*.5)
	var right:=minf(8.0,rect.size.x-left)
	var widths: Array[float]=[left,rect.size.x-left-right,right]
	var source_x: Array[float]=[0.0,80.0,192.0-right]
	var source_width: Array[float]=[left,32.0,right]
	var x:=rect.position.x
	for column: int in 3:
		var remaining:=widths[column]
		while remaining>0.0:
			var width:=minf(remaining,source_width[column])
			# Keep the full bark cross-section distinct from distant lamp vines.
			canvas.draw_texture_rect_region(DECK,Rect2(x,rect.position.y,width,height),Rect2(source_x[column],4,width,height),Color(1.9,2.0,1.6))
			x+=width;remaining-=width
