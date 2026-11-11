extends "res://tests/world/plains35_fixture.gd"
func run()->void:
 var args:=OS.get_cmdline_user_args()
 var folder:String=args[0]
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 for id:String in args[1].split(","):
  root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
  check(await app.review.begin(id,"","base"),id+" formal load")
  await ticks(12)
  app.controller.active=false;app.set_physics_process(false);app.ui.hide();app.overlay.hide();app.camera.enabled=false
  var area:Rect2=FixedWorldProvider.rect(app.room.contract.world_geometry.bounds_world_units)
  root.size=Vector2i(area.size);root.content_scale_size=root.size
  var camera:=Camera2D.new();camera.position=area.get_center();camera.zoom=Vector2.ONE;root.add_child(camera);camera.make_current()
  await ticks(8);paused=true;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/plains-final-art/"+folder+"/"+id+".png")
  paused=false;camera.queue_free();await ticks(1);app.camera.enabled=true;app.camera.make_current();app.ui.show();app.overlay.show();app.controller.active=true;app.set_physics_process(true)
  print("OVERVIEW ",id," ",area)
 await WorldAudioLifecycle.drain_world(app);quit(failures)
