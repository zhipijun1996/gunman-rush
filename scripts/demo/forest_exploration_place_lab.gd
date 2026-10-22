extends Node2D
## Explicit single-place fixture; never a formal region or a player-duration proof.
const FACTORY := preload("res://scripts/generation/forest_exploration_places.gd")
class SurfaceOverlay extends Node2D:
	var data: Dictionary
	func _draw() -> void:
		ForestBibleThorns.draw(self,data)
		for row: Dictionary in data.platforms:
			if bool(row.one_way): UnderworldTerrain.draw_one_way(self,Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3]))
var layout := "seven_bough_reveal"
var place_variant := 0
var route_name := "main"
var grant_hook := true
var manifest: Dictionary
var module: PlatformingModule
var player: PlayerMotor
var controller: PlayerController
var terrain: UnderworldTerrain
var camera: Camera2D
func _ready() -> void:
	match layout:
		"fallen_trunk_two_faces": manifest = preload("res://scripts/generation/forest_exploration_fallen_trunk.gd").build(place_variant)
		"backbranch_fruit_reversal": manifest = preload("res://scripts/generation/forest_exploration_fruit_crossing.gd").build(place_variant)
		_: manifest = FACTORY.build(layout,place_variant)
	manifest = manifest.duplicate(true)
	assert(not manifest.is_empty())
	var selected: Dictionary = manifest.routes[route_name]
	manifest.routes.main = selected.duplicate(true)
	if selected.has("action_program"): manifest.action_program = selected.action_program.duplicate(true)
	var start: Dictionary = manifest.ports[selected.from_port]
	var finish: Dictionary = manifest.ports[selected.to_port]
	manifest.spawn = start.position.duplicate()
	manifest.goal = finish.position.duplicate()
	manifest.goal_support_id = str(finish.support_id)
	module = PlatformingModule.new()
	module.definition = ForestDirectionalGeometry.as_module(manifest)
	module.authoring_debug = false
	module.visible = false
	add_child(module)
	var solids: Array[Rect2] = []
	for row: Dictionary in manifest.platforms:
		if not bool(row.one_way): solids.append(Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3]))
	terrain = UnderworldTerrain.build(solids)
	assert(terrain != null and ForestBibleTerrainMaterial.install_on(terrain))
	add_child(terrain)
	move_child(terrain,0)
	var overlay := SurfaceOverlay.new()
	overlay.data = manifest.duplicate(true)
	overlay.data.layout_version = "forest-bible-world-v15"
	overlay.data.thorn_surfaces = []
	for surface: Dictionary in manifest.get("danger_surfaces",[]):
		var hazard: Array = manifest.dangers[int(surface.danger_index)]
		var host: Dictionary = manifest.platforms.filter(func(row: Dictionary) -> bool: return row.id == surface.host_support_id)[0]
		var seam_y: float = float(host.rect[1]) if surface.face == "up" else float(host.rect[1])+float(host.rect[3])
		overlay.data.thorn_surfaces.append({"face":surface.face,"hazard_rect":hazard.duplicate(),"segments":[{"support_id":surface.host_support_id,"start":[hazard[0],seam_y],"end":[float(hazard[0])+float(hazard[2]),seam_y]}]})
	add_child(overlay)
	for row: Dictionary in manifest.hook_anchors:
		var anchor := ForestFruitAnchor.new()
		anchor.name = row.id
		anchor.position = Vector2(row.position[0],row.position[1])
		anchor.bible_presentation = true
		anchor.fruit_role = str(row.get("fruit_role","optional"))
		anchor.stem_root = Vector2(row.stem_root[0],row.stem_root[1])-anchor.position
		add_child(anchor)
	player = preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	player.position = Vector2(manifest.spawn[0],manifest.spawn[1])
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.enable_shot_energy()
	if grant_hook: controller.traversal.grant(&"grapple")
	var visual := UnderworldPlayer.new()
	visual.name = "PixelPlainsActor"
	visual.motor = player
	visual.controller = controller
	player.add_child(visual)
	player.get_node("CourierVisual").hide()
	player.get_node("PlayerFeedback").hide()
	player.get_node("PlayerVisualAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera2D.new()
	camera.position = Vector2(350,100)
	add_child(camera)
	queue_redraw()
func _draw() -> void:
	if manifest.is_empty(): return
	var view := get_viewport_rect().size
	ForestBiblePresentation.draw_background(self,{"layout_version":"forest-bible-world-v15","platforms":[]},camera.get_screen_center_position() if is_instance_valid(camera) else Vector2(350,100),view,0.0)
