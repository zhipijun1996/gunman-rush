extends SceneTree
## Limited production Motor/controller/WorldCamera probe on the left bank.
## Does not claim a complete traversable room or gameplay/editor integration.
class CameraRoom extends FixedWorldRoom:
	func _ready() -> void: pass

const OUTPUT := "res://build/kit-reuse/"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var scene: Node2D = load("res://game/presentation/experiments/kit_reuse/room.tscn").instantiate()
	root.add_child(scene)
	while not scene.ready_to_capture: await process_frame
	(scene.actor.get_child(0) as CanvasItem).hide()
	for key: String in ["ground","masonry"]:
		for r: Array in scene.layout[key]:
			var body := StaticBody2D.new()
			body.position = Vector2(r[0]+r[2]*.5,r[1]+r[3]*.5)
			var shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(r[2],r[3])
			shape.shape = rectangle
			body.add_child(shape)
			scene.add_child(body)
	var player: PlayerMotor = load("res://game/player/player.tscn").instantiate()
	player.position = Vector2(304,558)
	player.z_index = 20
	scene.add_child(player)
	var controller: PlayerController = player.get_node("Controller")
	player.get_node("CourierVisual").hide()
	var visual := PlayerPresentationRuntime.make_body(player,controller,"ActualHero","courier_classic")
	player.add_child(visual)
	var provider := FixedWorldProvider.new()
	assert(provider.open())
	var room := CameraRoom.new()
	room.contract = {"world_geometry":{"bounds_world_units":[0,0,2560,960]},"camera":{"profile":"bounded_follow"}}
	scene.add_child(room)
	var camera := WorldCamera.new()
	camera.target = player
	camera.controller = controller
	camera.room = room
	camera.settings = provider.data.player.camera
	scene.camera.enabled = false
	scene.add_child(camera)
	camera.enter_room(Rect2(0,0,2560,960))
	controller.router.has_application_focus = true
	DirAccess.make_dir_recursive_absolute(OUTPUT+"controller-frames")
	var trace: Array = []
	for frame: int in range(96):
		var axis := 1.0 if frame>=12 and frame<36 else (-1.0 if frame>=54 and frame<78 else 0.0)
		controller.router.set_source_axis(&"keyboard_mouse",axis)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OUTPUT+"controller-frames/%04d.png"%frame)==OK)
		trace.append({"frame":frame,"position":[player.position.x,player.position.y],"camera":[camera.position.x,camera.position.y],"axis":axis,"on_floor":player.is_on_floor(),"zoom":camera.zoom.x,"motor_steps":player.motion_steps})
		if frame in [0,35,95]:
			assert(root.get_texture().get_image().save_png(OUTPUT+"controller-%d.png"%frame)==OK)
	assert(player.motion_steps>100)
	assert(player.position.x>64 and player.position.x<1000)
	var file := FileAccess.open(OUTPUT+"controller.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"left bank walking, stopping and returning only; not room traversal","fixed_render_fps":12,"trace":trace},"\t"))
	print("KIT CONTROLLER: production Motor/controller, UnderworldPlayer and WorldCamera; 96 fixed12fps frames; ",player.motion_steps," motion steps")
	quit()
