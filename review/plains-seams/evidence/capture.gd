extends "res://tests/world/plains35_fixture.gd"
## Visual inspection fixtures. Door landing positions are placed explicitly;
## this is not a continuous traversal test or proof of combat readability.
func run()->void:
 var args:=OS.get_cmdline_user_args()
 var folder:String="res://build/plains-seam-audit/"+args[0]+"/"
 root.size=Vector2i(1280,720);root.content_scale_size=root.size
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 var records:Array=[]
 for id:String in args[1].split(","):
  check(await app.review.begin(id,"","base",true),id+" formal load")
  await ticks(12)
  app.controller.active=false;app.set_physics_process(false)
  app.player.set_physics_process(false)
  for door:Dictionary in app.room.contract.doors:
   var at:=FixedWorldProvider.point(door.landing_contract.safe_standing_position_world_units)
   app.player.reset_at(at);app.player.velocity=Vector2.ZERO
   app.camera.reset_view();await ticks(10)
   paused=true;await RenderingServer.frame_post_draw
   var name:=str(door.id).replace(":","_")
   root.get_texture().get_image().save_jpg(folder+name+".jpg",.88)
   var automatic:Array=[]
   for child:Node in app.room.get_node("RegionalArt").get_children():
    if child.name.begins_with("Threshold_"):automatic.append(str(child.name))
   records.append({"room":id,"door":door.id,"target":door.target_room,"implemented":door.target_implemented,"position":[at.x,at.y],"camera":[app.camera.position.x,app.camera.position.y],"automatic_thresholds":automatic,"file":name+".jpg"})
   paused=false
  if id in ["P-R01","P-R31","P-R33","P-R34"]:
   app.ui.hide();app.overlay.hide();app.camera.enabled=false
   var area:=FixedWorldProvider.rect(app.room.contract.world_geometry.bounds_world_units)
   root.size=Vector2i(area.size);root.content_scale_size=root.size
   var overview:=Camera2D.new();overview.position=area.get_center();overview.zoom=Vector2.ONE;root.add_child(overview);overview.make_current()
   await ticks(8);paused=true;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_jpg(folder+id+"-whole.jpg",.92)
   paused=false;overview.queue_free();await ticks(1)
   root.size=Vector2i(1280,720);root.content_scale_size=root.size
   app.camera.enabled=true;app.camera.make_current();app.ui.show();app.overlay.show()
  app.controller.active=true;app.player.set_physics_process(true);app.set_physics_process(true)
  print("AUDIT_CAPTURE ",id)
 FileAccess.open(folder+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
 await WorldAudioLifecycle.drain_world(app);quit(failures)
