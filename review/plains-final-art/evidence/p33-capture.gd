extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 var folder:=OS.get_cmdline_user_args()[0]
 for room_id:String in ["P-R33","Z-R01"]:
  await load_room(room_id)
  var views:Array=[Vector2(144,558),Vector2(768,558),Vector2(1536,558),Vector2(1880,558),Vector2(1152,910)] if room_id=="P-R33" else [Vector2(352,622),Vector2(752,622),Vector2(1120,622)]
  for i:int in views.size():
   await fixture(views[i]);app.controller.active=false;app.player.reset_at(views[i]);app.set_physics_process(false);app.camera.reset_view();await ticks(6);await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://build/clockheart-scale/"+folder+"/"+room_id+"-"+str(i)+".png");app.set_physics_process(true);app.controller.active=true
  app.set_physics_process(false);app.controller.active=false;app.ui.hide();app.overlay.hide();app.camera.enabled=false
  root.size=Vector2i(1984,992) if room_id=="P-R33" else Vector2i(1472,704);root.content_scale_size=root.size
  var overview:=Camera2D.new();overview.position=Vector2(1024,528) if room_id=="P-R33" else Vector2(768,384);overview.zoom=Vector2.ONE;root.add_child(overview);overview.make_current();await ticks(3);await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/clockheart-scale/"+folder+"/"+room_id+"-whole.png")
  overview.queue_free();await ticks(1);root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);app.camera.enabled=true;app.camera.make_current();app.ui.show();app.set_physics_process(true);app.controller.active=true
 await WorldAudioLifecycle.drain_world(app);quit(failures)
