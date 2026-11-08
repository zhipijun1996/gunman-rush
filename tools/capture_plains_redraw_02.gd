extends SceneTree
## Actual fixed-world rendering at unchanged camera settings.
## Room loads and initial player placements are disclosed capture fixtures.
var app: FixedWorldApp
func _initialize() -> void: run.call_deferred()
func ticks(count: int) -> void:
	for i: int in count: await physics_frame
func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/plains_redraw_02/"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,720)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://plains_redraw_02_capture.json"
	app.settings_path="user://plains_redraw_02_settings.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app)
	assert(app.start_new())
	await ticks(45)
	app.player.reset_at(Vector2(855,432))
	await ticks(45)
	await snap("fixed-world-patrol")
	app.load_room("P-R06","room-link-139:P-R06")
	while app.busy: await physics_frame
	var charger: EnemyActor=app.room.enemies["P-R06:charger:01"]
	app.player.reset_at(charger.motor.global_position+Vector2(-80,0))
	await ticks(35)
	await snap("fixed-world-charger")
	app.load_room("P-R14","L02:P-R14")
	while app.busy: await physics_frame
	app.player.reset_at(Vector2(1330,654))
	await ticks(90)
	await snap("fixed-world-windkeeper")
	app.queue_free()
	await ticks(3)
	print("PLAINS REDRAW: actual fixed-world renders captured; initial positions are fixtures")
	quit()
