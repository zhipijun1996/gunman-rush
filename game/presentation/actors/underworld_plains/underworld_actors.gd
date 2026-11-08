@static_unload
class_name UnderworldActors
extends RefCounted
## Presentation only. Accepted state/anchors remain owned by existing actors.
const BUILD := "res://assets/underworld_plains/actors/actors_build.json"
## Shared world-space stature for the courier and human NPCs. UI icons use
## their own layout sizes; this never changes the character collision shape.
const HUMANOID_HEIGHT := 44.0
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
	return load("res://game/presentation/actors/underworld_plains/underworld_actor_installer.gd").install(stage)
