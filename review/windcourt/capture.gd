extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R14")
 app.room.encounter.set_physics_process(false);app.room.boss_contact.enabled=false
 var folder:=OS.get_cmdline_user_args()[0]
 var views:Array=[Vector2(512,1230),Vector2(384,942),Vector2(592,742),Vector2(1100,742),Vector2(1800,742),Vector2(2592,334),Vector2(3712,974),Vector2(4608,398)]
 var camera_views:Array=[]
 for i:int in views.size():
  await fixture(views[i]);app.controller.active=false;app.player.reset_at(views[i]);app.set_physics_process(false)
  app.camera.reset_view();await ticks(6);await RenderingServer.frame_post_draw
  var span:=root.get_visible_rect().size/app.camera.zoom
  var corner:=app.camera.get_screen_center_position()-span*.5
  camera_views.append({"index":i,"player":[views[i].x,views[i].y],"rect":[corner.x,corner.y,span.x,span.y]})
  root.get_texture().get_image().save_png("res://build/p14-composition/"+folder+"/"+str(i)+".png")
  app.set_physics_process(true);app.controller.active=true
 var geometry:Dictionary={"platforms":[],"walls":[],"one_way":Array(app.room.one_way_indices),"bounds":app.room.contract.world_geometry}
 for r:Rect2 in app.room.platforms:geometry.platforms.append([r.position.x,r.position.y,r.size.x,r.size.y])
 for r:Rect2 in app.room.boundary_art_rock:geometry.walls.append([r.position.x,r.position.y,r.size.x,r.size.y])
 FileAccess.open("res://build/p14-composition/geometry.json",FileAccess.WRITE).store_string(JSON.stringify(geometry))
 FileAccess.open("res://build/p14-composition/"+folder+"-views.json",FileAccess.WRITE).store_string(JSON.stringify(camera_views))
 await WorldAudioLifecycle.drain_world(app);quit(failures)
