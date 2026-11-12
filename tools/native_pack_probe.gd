extends SceneTree
## Empty-project probe of the shipping pack, without editor/authoring fallback.
var app: FixedWorldApp
var failures:=0
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
 if not value:failures+=1;printerr("NATIVE PACK FAILED: ",label)
func ticks(count:int)->void:
 for i:int in count:await physics_frame
func settle()->void:
 for i:int in 300:
  await physics_frame
  if not app.busy:break
 await ticks(5)
 check(not app.busy,"room transition finishes")
func run()->void:
 check(not FileAccess.file_exists("res://config/world/world.json"),"authoring source is excluded")
 check(not FileAccess.file_exists("res://build/workbench/preview-world.json"),"editor preview catalog is excluded")
 check(not ResourceLoader.exists("res://game/world/regions/V/rooms/V-R12.tscn"),"experimental room is excluded")
 check(PlainsActorAssets.texture("effects",&"muzzle_flash")!=null,"dynamic effect atlas resolves from the real package")
 app=preload("res://game/application/world/fixed_world.tscn").instantiate()
 app.save_path="user://native_release_probe.json";app.save_profile="native_release_probe"
 root.add_child(app)
 var ids:Array=app.content.data.rooms.keys()
 check(app.start_new(),"formal entry starts new game")
 await settle()
 for id:String in ids:
  app.load_room(id,"");await settle()
  if is_instance_valid(app.introduction) and app.introduction.phase in ["pending","waking"]:
   await ticks(100)
   while app.introduction.dialogue_active:app.introduction.advance()
  check(app.room!=null and app.room.room_id==id and app.controller.active,"real room loaded: "+id)
 app.toggle_pause();app._ui_command("help","");await ticks(3)
 check(app.ui.page=="help" and PlayerControlGuide.text("title")!="title","compiled guide text opens from the actual pause menu")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
 print("NATIVE PACK: ",ids.size()," rooms; ",failures," failures");quit(failures)
