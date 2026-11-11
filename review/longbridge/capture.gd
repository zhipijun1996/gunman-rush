extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R32","h")
 var folder:=OS.get_cmdline_user_args()[0]
 var views:Array[Vector2]=[Vector2(208,1006),Vector2(672,1006),Vector2(1184,942),Vector2(1952,814),Vector2(2680,622),Vector2(1792,1038),Vector2(2432,1230),Vector2(960,142),Vector2(1104,622)]
 for i:int in views.size():
  await fixture(views[i]);app.controller.active=false;app.player.reset_at(views[i]);app.set_physics_process(false)
  app.camera.reset_view();await ticks(6);await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/p32-structure/"+folder+"/"+str(i)+".png")
  app.set_physics_process(true);app.controller.active=true
 app.set_physics_process(false);app.controller.active=false;app.ui.hide();app.overlay.hide();app.camera.enabled=false
 var overview:=Camera2D.new();overview.position=Vector2(1536,672);overview.zoom=Vector2(.38,.38)
 root.add_child(overview);overview.make_current();await ticks(3);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/p32-structure/"+folder+"-whole.png")
 await WorldAudioLifecycle.drain_world(app);quit(failures)
