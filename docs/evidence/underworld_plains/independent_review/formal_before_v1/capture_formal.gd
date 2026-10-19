extends SceneTree
var shots:Array[Dictionary]=[]
var app:DemoApp
var folder:="res://build/underworld_plains/independent_review/formal_golden_v1"
func _initialize()->void:run.call_deferred()
func pair(p:Vector2)->Array:return [p.x,p.y]
func run()->void:
 root.size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute(folder)
 app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
 app.start_plains("underworld-independent-golden/0")
 for i:int in 10:await physics_frame
 for map_index:int in [1,2]:
  if map_index==2:
   app.director.stage_index=2;app._load_stage()
   for i:int in 10:await physics_frame
  var stage:=app.stage as PlainsRegionStage
  var points:Array[Dictionary]=[{"name":"spawn","position":stage.spawn},{"name":"merchant","position":stage.merchant_position-Vector2(80,0)}]
  for area:Dictionary in stage.generated.manifest.areas:
   if str(area.role) in ["junction","challenge","creek"]:
    points.append({"name":str(area.role)+"_"+str(area.id),"position":Vector2(area.position[0],area.position[1])-Vector2(0,18)})
  var behaviors:Dictionary={}
  for enemy:EnemyMotor in stage.enemies:
   var actor:=enemy.get_node("Actor") as EnemyActor
   var behavior:=str(actor.definition.behavior_id)
   if not behaviors.has(behavior):
    behaviors[behavior]=true
    points.append({"name":"enemy_"+behavior,"position":enemy.position-Vector2(95,0)})
  points.append({"name":"boss","position":Vector2(stage.boss_arena.position.x+200,stage.boss_arena.end.y-18)})
  for point:Dictionary in points:
   if not is_instance_valid(app.controller):break
   app.controller.return_to_segment(point.position)
   app._run_camera.snap_to_target();app._run_camera.force_update_scroll()
   for i:int in 3:await physics_frame
   await RenderingServer.frame_post_draw
   var name:="map%d_%s"%[map_index,point.name]
   var path:=folder+"/"+name+".png"
   var img:=root.get_texture().get_image();img.save_png(path)
   shots.append({"id":name,"path":path,"map_index":map_index,"manifest_hash":stage.generated.manifest.manifest_hash,"position":pair(app.player.global_position),"camera":pair(app._run_camera.get_screen_center_position()),"sha256":FileAccess.get_sha256(path),"parallax":(app.get_node("PixelPlainsParallax") as UnderworldParallax).measured_nodes(),"fixture":"explicit controller.return_to_segment + actual camera follow; NOT route traversal"})
   print("UNDERWORLD_INDEPENDENT_SHOT ",name)
 var f:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE);f.store_string(JSON.stringify({"shots":shots,"scope":"Positioned actual formal consumers with actual HUD/camera; not route completion or user acceptance"},"\t"));f.close()
 await load("res://tests/audio_teardown.gd").drain_world(app)
 app.free()
 for i:int in 4:await process_frame
 quit(0)
