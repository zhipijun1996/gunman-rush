class_name PlainsRegionScenery
extends Node2D
## Depth and landmarks only. No gameplay masks, fake foreground passages or RNG.
var manifest: Dictionary
func configure(m: Dictionary) -> void: manifest=m
func _ready() -> void:
	z_index=-10
	var veil := Sprite2D.new()
	var pixels := GradientTexture2D.new()
	pixels.width=2; pixels.height=2
	veil.texture=pixels
	var b: Array=manifest.world_bounds
	veil.position=Vector2(b[0]+b[2]/2.0,b[1]+b[3]/2.0)
	veil.scale=Vector2(b[2]/2.0,b[3]/2.0)
	var material:=ShaderMaterial.new()
	material.shader=preload("res://scripts/art/plains_depth.gdshader")
	veil.material=material
	add_child(veil)
	for a: Dictionary in manifest.areas:
		if not a.has("row"): continue
		var id: String="windmill" if "WINDMILL" in str(a.label) else "ruin_arch" if "TOWER" in str(a.label) else "stones" if int(a.row)==2 else "ivy"
		var image:=PlainsV3Assets.texture("decor.json",id)
		var height:=150.0 if id in ["windmill","ruin_arch"] else 40.0
		var sprite:=Sprite2D.new()
		sprite.texture=image
		sprite.scale=Vector2.ONE*(height/image.get_height())
		sprite.position=Vector2(a.position[0],a.position[1]-height/2.0+14)
		sprite.modulate=Color(0.8,0.9,0.95,0.65) if int(a.row)==2 else Color(1,1,1,0.55)
		add_child(sprite)
