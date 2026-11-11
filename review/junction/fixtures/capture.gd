extends "res://tests/world/approved_exploration_rooms.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 var folder:=OS.get_cmdline_user_args()[0]
 var geometry:Dictionary={}
 var camera_views:Array=[]
 var views:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/p06-realization/views.json"))
 for id:String in views:
  await app.review.begin(id,"","h");await ticks(5)
  geometry[id]={"platforms":[],"walls":[],"outer":[],"one_way":Array(app.room.one_way_indices),"bounds":app.room.contract.world_geometry.bounds_world_units}
  for r:Rect2 in app.room.platforms:geometry[id].platforms.append([r.position.x,r.position.y,r.size.x,r.size.y])
  for r:Rect2 in app.room.boundary_art_rock:geometry[id].walls.append([r.position.x,r.position.y,r.size.x,r.size.y])
  app.set_physics_process(false);app.story.set_process(false);app.controller.active=false
  for enemy:EnemyActor in app.room.enemies.values():enemy.process_mode=Node.PROCESS_MODE_DISABLED
  for i:int in views[id].size():
   app.player.reset_at(FixedWorldProvider.point(views[id][i]));app.camera.reset_view();await ticks(16)
   var span:=root.get_visible_rect().size/app.camera.zoom
   var corner:=app.camera.get_screen_center_position()-span*.5
   camera_views.append({"room":id,"index":i,"player":views[id][i],"rect":[corner.x,corner.y,span.x,span.y]})
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://build/p06-realization/"+folder+"/"+id+"-"+str(i)+".png")
  app.set_physics_process(true)
 FileAccess.open("res://build/p06-realization/geometry-"+folder+".json",FileAccess.WRITE).store_string(JSON.stringify(geometry))
 FileAccess.open("res://build/p06-realization/camera-views.json",FileAccess.WRITE).store_string(JSON.stringify(camera_views))
 await WorldAudioLifecycle.drain_world(app);quit()
