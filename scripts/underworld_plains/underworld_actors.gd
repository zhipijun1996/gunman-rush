@static_unload
class_name UnderworldActors
extends RefCounted
## Presentation only. Accepted state/anchors remain owned by existing actors.
const BUILD := "res://assets/underworld_plains/actors/actors_build.json"
## Shared world-space stature for the courier and human NPCs. UI icons use
## their own layout sizes; this never changes the character collision shape.
const HUMANOID_HEIGHT := 44.0
const BELLSTRIDER := preload("res://assets/underworld_plains/actors/bellstrider.png")
const WINDKEEPER := preload("res://assets/underworld_plains/actors/windkeeper.png")
const ICONS := {
	"merchant":preload("res://assets/underworld_plains/actors/merchant.png"),
	"chest":preload("res://assets/underworld_plains/actors/chest.png"),
	"coin":preload("res://assets/underworld_plains/actors/coin.png"),
	"heart":preload("res://assets/underworld_plains/actors/heart.png"),
	"door":preload("res://assets/underworld_plains/actors/door.png"),
	"bell":preload("res://assets/underworld_plains/actors/bell.png")}

static func icon_texture(kind: StringName) -> Texture2D:
	return ICONS[String(kind)] if ICONS.has(String(kind)) else PixelFormalActors.icon_texture(kind)

static func place_humanoid(sprite: Sprite2D, foot: Vector2) -> void:
	assert(sprite.texture != null and sprite.texture.get_height() > 0)
	# Tight source crops retain their aspect ratio and share the courier's
	# stature instead of stretching an NPC into a much larger portrait.
	sprite.centered = true
	sprite.scale = Vector2.ONE * HUMANOID_HEIGHT / sprite.texture.get_height()
	sprite.position = foot - Vector2(0, HUMANOID_HEIGHT * 0.5)

static func enabled(node: Node) -> bool:
	var cursor := node
	while cursor != null:
		if cursor.get_meta("underworld_formal_style",false): return true
		cursor = cursor.get_parent()
	return false

static func install(stage: Node2D) -> Dictionary:
	# Keep drawing helpers free of strong back-edges to their consumers.
	return load("res://scripts/underworld_plains/underworld_actor_installer.gd").install(stage)

static func draw_bellstrider(canvas: Node2D, encounter: Node, _spring: float, angle: float, flash: bool) -> void:
	var facing := float(encounter.direction)
	# The generated wheels are part of this body page: bobbing the whole image
	# would lift both wheels from the real floor. Only the functional core sways.
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	canvas.draw_texture_rect(BELLSTRIDER,Rect2(-80,-91,160,157),false,Color(1.5,1.3,1.0) if flash else Color.WHITE)
	canvas.draw_set_transform(Vector2.ZERO)
	# Axles remain the real legacy centers; rotation follows accepted movement.
	for side: int in [-1,1]:
		var hub := Vector2(side*40,40)
		for spoke: int in 3:
			var axis := Vector2.from_angle(angle+spoke*TAU/3)
			PixelFormalActors.pixel_line(canvas,hub+axis*5,hub+axis*14,Color("7b6d3c"),2)

static func draw_windkeeper(canvas: Node2D, encounter: Node, stride: float, speed: float, flash: bool, old_phase: int, blend: float) -> void:
	var raised: bool = (encounter.definition as WindkeeperDefinition).platform_trials
	var old_height := 236.0 if raised and old_phase==3 else 198.0
	var height := lerpf(old_height,236.0 if raised and encounter.stage_phase==3 else 198.0,smoothstep(0,1,blend))
	var face := float(encounter.direction)
	var dip := 4.0 if encounter.mode in [&"stomp_warning",&"charge_warning",&"pier_warning"] else 0.0
	canvas.draw_set_transform(Vector2(0,dip),0,Vector2(face,1))
	canvas.draw_texture_rect(WINDKEEPER,Rect2(-92,65-height,184,height),false,Color(1.5,1.3,1.0) if flash else Color.WHITE)
	# The real edited source contains continuous closed armour. Its functional
	# moving core is rendered only at the encounter-owned anchor below.
	if absf(speed)>2:
		for leg: int in 4:
			var lift := maxf(0,sin(stride+(PI if leg%2==0 else 0)))*4
			canvas.draw_rect(Rect2(-72+leg*43,59-lift,22,6),Color("141e18"))
	canvas.draw_set_transform(Vector2.ZERO)
	if not encounter.core_open:
		var bell := icon_texture(&"bell")
		var size := bell.get_size() * (32.0 / bell.get_height())
		canvas.draw_texture_rect(bell,Rect2(encounter.core_offset()-size*.5,size),false,Color(1.5,1.3,1.0) if flash else Color.WHITE)
