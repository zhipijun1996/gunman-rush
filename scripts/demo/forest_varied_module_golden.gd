extends Node2D
const FACTORY := preload("res://scripts/generation/forest_playful_module_variants.gd")
var layout := "forked_bough_hh"
var grant_hook := true
var manifest: Dictionary
var module: PlatformingModule
var player: PlayerMotor
var controller: PlayerController
func _ready() -> void:
	manifest = FACTORY.build(layout)
	assert(not manifest.is_empty())
	module = PlatformingModule.new()
	module.definition = ForestDirectionalGeometry.as_module(manifest)
	module.authoring_debug = false
	add_child(module)
	for row: Dictionary in manifest.hook_anchors:
		var anchor := GrappleAnchor.new()
		anchor.name = row.id
		anchor.position = Vector2(row.position[0],row.position[1])
		add_child(anchor)
	player = preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	player.position = Vector2(manifest.spawn[0],manifest.spawn[1])
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.enable_shot_energy()
	if grant_hook: controller.traversal.grant(&"grapple")
	var camera := Camera2D.new()
	camera.position = Vector2(250,-100)
	if layout == "bridge_five":
		# New long bridge renders through a real following Camera2D; next rings
		# enter the forward view while old fixed golden cameras stay unchanged.
		camera.position = Vector2(200,-100)
		player.add_child(camera)
	else:
		add_child(camera)
