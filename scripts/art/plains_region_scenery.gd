class_name PlainsRegionScenery
extends Node2D
## Depth and landmarks only. No gameplay masks, fake foreground passages or RNG.
var manifest: Dictionary
func configure(m: Dictionary) -> void: manifest=m
func _ready() -> void:
	z_index=-10
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
	queue_redraw()
func _draw() -> void:
	if manifest.is_empty(): return
	var b: Array=manifest.world_bounds
	for i: int in 10:
		draw_rect(Rect2(float(b[0]),250+i*30,float(b[2]),30),Color(0.06,0.12,0.14,0.065*(i+1)))
	draw_rect(Rect2(float(b[0]),550,float(b[2]),float(b[1])+float(b[3])-550),Color(0.06,0.12,0.14,0.65))
	# Maintenance braces remain behind actors/platforms and away from landing text.
	for a: Dictionary in manifest.areas:
		if int(a.get("row",-1))!=2: continue
		var p:=Vector2(a.position[0],a.position[1])
		draw_line(p+Vector2(-180,-260),p+Vector2(-180,-40),Color(0.3,0.4,0.39,0.5),10)
		draw_line(p+Vector2(180,-260),p+Vector2(180,-40),Color(0.3,0.4,0.39,0.5),10)
		draw_line(p+Vector2(-180,-260),p+Vector2(180,-260),Color(0.4,0.5,0.46,0.5),14)
