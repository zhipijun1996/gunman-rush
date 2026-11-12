extends SceneTree
## Runs through the exported pack on a real Windows display; no headless fallback.
var app:FixedWorldApp
var failures:=0
var output:="user://native-display"
var samples:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func ticks(n:int)->void:
 for i:int in n:await process_frame
func check(ok:bool,label:String)->void:
 if not ok:failures+=1;printerr("DISPLAY FAILED: ",label)
func sample(stage:String,save:bool=false)->float:
 var image:=root.get_texture().get_image()
 check(image!=null and image.get_size()==Vector2i(1280,720),stage+" stable internal render resolution")
 if image==null:return -1
 var luminance:=0.0;var count:=0
 for y:int in range(32,image.get_height()-32,32):
  for x:int in range(32,image.get_width()-32,32):
   var c:=image.get_pixel(x,y);luminance+=c.get_luminance();count+=1
 var mean:=luminance/maxi(1,count)
 check(mean>.015 and mean<.98,stage+" scene is neither empty black nor a white flash")
 samples.append({"stage":stage,"window":[root.size.x,root.size.y],"render":[image.get_width(),image.get_height()],"mean_luminance":mean})
 if save:image.save_png(output+"/"+stage+".png")
 return mean
func phase(stage:String)->void:
 await ticks(30)
 var previous:=sample(stage,true)
 for i:int in 12:
  await ticks(3)
  var current:=sample(stage)
  check(absf(current-previous)<.18,stage+" consecutive frames have no whole-frame brightness jump")
  previous=current
func run()->void:
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 for arg:String in OS.get_cmdline_user_args():
  if arg=="--local-viewport" and not OS.has_feature("windows"):root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
 check(DisplayServer.get_name()!="headless","actual graphical display is required")
 check(root.content_scale_mode==Window.CONTENT_SCALE_MODE_VIEWPORT,"shipping viewport stretch is active")
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R22","","base"),"real Windpressure Canal loads")
 for enemy:EnemyActor in app.room.enemies.values():
  enemy.cancel_attacks();enemy.process_mode=Node.PROCESS_MODE_DISABLED;enemy.motor.position=Vector2(-10000,-10000)
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720)
 await phase("normal")
 app.controller.router.clear("declared mid-canal rendering fixture")
 app.player.reset_at(Vector2(1760,1390));(app.camera as WorldCamera).reset_view()
 root.mode=Window.MODE_MAXIMIZED
 if OS.has_feature("windows"):
  await ticks(30);check(root.mode==Window.MODE_MAXIMIZED and root.size!=Vector2i(1280,720),"OS actually maximizes the visible client window")
 await phase("maximized")
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);await phase("restored")
 root.size=Vector2i(1857,1021);await phase("large_window")
 var report:={"display":DisplayServer.get_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"failures":failures,"samples":samples}
 var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
 print("NATIVE DISPLAY: ",samples.size()," rendered samples; ",failures," failures");quit(failures)
