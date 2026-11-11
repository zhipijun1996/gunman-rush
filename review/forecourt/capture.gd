extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R33")
 var folder:=OS.get_cmdline_user_args()[0]
 var views:Array[Vector2]=[Vector2(144,558),Vector2(768,558),Vector2(1440,558),Vector2(1880,558),Vector2(1024,814),Vector2(1152,910)]
 for i:int in views.size():
  await fixture(views[i]);app.controller.active=false;app.player.reset_at(views[i]);app.set_physics_process(false);app.camera.reset_view();await ticks(6);await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/p33-boundary/"+folder+"/"+str(i)+".png");app.set_physics_process(true);app.controller.active=true
 app.set_physics_process(false);app.controller.active=false;app.ui.hide();app.overlay.hide();app.camera.enabled=false
 root.size=Vector2i(2048,1024);root.content_scale_size=Vector2i(2048,1024)
 var overview:=Camera2D.new();overview.position=Vector2(1024,512);overview.zoom=Vector2.ONE;root.add_child(overview);overview.make_current();await ticks(3);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/p33-boundary/"+folder+"-whole.png")
 await WorldAudioLifecycle.drain_world(app);quit(failures)
