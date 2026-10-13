class_name PlainsRegionScenery
extends Node2D
## Grounded landmark groups. Presentation has its own deterministic selection;
## no gameplay RNG consumption, geometry changes or imitation interactive bells.
var manifest: Dictionary
var supports: Array[Rect2] = []
func configure(m: Dictionary, slabs: Array[Rect2] = []) -> void:
	manifest=m
	supports=slabs
func _ready() -> void:
	z_index=-10
	var veil := Sprite2D.new()
	var pixels := GradientTexture2D.new()
	pixels.width=2; pixels.height=2
	veil.texture=pixels
	var b: Array=manifest.world_bounds
	veil.position=Vector2(b[0]+b[2]/2.0,b[1]+b[3]/2.0)
	veil.scale=Vector2(b[2]/2.0,b[3]/2.0)
	var depth:=ShaderMaterial.new()
	depth.shader=preload("res://scripts/art/plains_depth.gdshader")
	veil.material=depth
	add_child(veil)
	for a: Dictionary in manifest.areas:
		# Meaningful landmarks frame a few quiet rooms, leaving challenge sightlines clear.
		if str(a.get("role","")) not in ["rest", "camp", "junction", "entry", "merchant"]: continue
		var origin:=Vector2(a.position[0],a.position[1])
		var floor_rect:=ground_for(origin,supports)
		if not floor_rect.has_area(): continue
		var landmark:="windmill" if str(a.get("landmark",""))=="windmill" else "ruin_arch"
		var x:=clampf(origin.x+95,floor_rect.position.x+65,floor_rect.end.x-65)
		_add_prop(landmark,Vector2(x,floor_rect.position.y),100)
		_add_prop("ivy",Vector2(x-32,floor_rect.position.y),26)
		_add_prop("stones",Vector2(x+39,floor_rect.position.y),20)

static func ground_for(origin: Vector2, slabs: Array[Rect2]) -> Rect2:
	var best:=Rect2()
	var distance:=INF
	for slab:Rect2 in slabs:
		if slab.size.x<180 or slab.size.y<40:continue
		if origin.x<slab.position.x or origin.x>slab.end.x:continue
		var d:=absf(slab.position.y-origin.y)
		if d<distance and d<100:best=slab;distance=d
	return best

func _add_prop(id: String, foot: Vector2, height: float) -> void:
	var texture:=PlainsV3Assets.texture("decor.json",id)
	var sprite:=Sprite2D.new()
	sprite.texture=texture
	sprite.scale=Vector2.ONE*height/texture.get_height()
	sprite.position=foot-Vector2(0,height/2)
	# Same depth plane, same material treatment in all map rows.
	sprite.modulate=Color(.92,.96,.88,.90)
	add_child(sprite)
