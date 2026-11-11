extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 root.size=Vector2i(1536,512)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R14");await ticks(8)
 app.set_physics_process(false);app.controller.active=false
 app.ui.hide();app.overlay.hide()
 app.camera.enabled=false
 var overview:=Camera2D.new();overview.position=Vector2(2400,672);overview.zoom=Vector2(.18,.18)
 root.add_child(overview);overview.make_current();overview.force_update_scroll()
 await ticks(3);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/p14-composition/whole.png")
 await WorldAudioLifecycle.drain_world(app);quit(failures)
