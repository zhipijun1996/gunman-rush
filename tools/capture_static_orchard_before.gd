extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,720)
 var scene: Control=load("res://game/presentation/experiments/depth_lab/depth_lab.tscn").instantiate()
 scene.output="res://build/static-orchard/reference"
 root.add_child(scene)
 while not scene.ready_to_run:await process_frame
 scene.set_physics_process(false)
 scene.flat.size=Vector2i(1280,720);scene.camera2.zoom=Vector2.ONE;scene.camera2.position=Vector2(800,360);scene.camera2.force_update_scroll();scene.hero.position=Vector2(760,600);scene.actor2.texture.atlas=load("res://assets/underworld_plains/player_animation/states_sheet.png");scene.actor2.texture.region=Rect2(0,0,80,64)
 await process_frame
 await RenderingServer.frame_post_draw
 assert(scene.flat.get_texture().get_image().save_png("res://build/static-orchard/before.png")==OK)
 scene.queue_free();await process_frame
 print("STATIC ORCHARD BEFORE: prior flat reference at normal 1wu/px scale captured");quit()
