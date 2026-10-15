extends SceneTree
var output:="res://build/region_production_v3/highland_identity/static_v2"
var rows:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func wait_stage(app:DemoApp)->void:
 for unused:int in 120:
  await physics_frame;await process_frame
  if not app._stage_pending and app.stage is PlainsRegionStage:return
func find_landscape(n:Node)->PlainsSemanticLandscape:
 if n is PlainsSemanticLandscape:return n
 for c:Node in n.get_children():
  var x:=find_landscape(c)
  if x!=null:return x
 return null
func run()->void:
 root.size=Vector2i(1280,720)
 var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
 app.start_plains("level-design-v2-baseline");await wait_stage(app)
 app.lifetime.stage_epoch+=1;app.lifetime.actor_epoch+=1;app.director._enter_stage(2,&"boss");app._stage_entered(DemoRunResult.new());await wait_stage(app)
 var stage:=app.stage as PlainsRegionStage;var landscape:=find_landscape(stage)
 var before:=JSON.stringify(stage.generated.manifest)
 var entry:Dictionary={}
 for e:Dictionary in landscape.entries:
  if e.family.family_id=="windmill_highland_v1":entry=e;break
 if entry.is_empty():printerr("highland missing: ",landscape.omitted);quit(1);return
 var tower:Sprite2D=entry.sprite
 var center:float=entry.anchor_world.x
 var support:Rect2=entry.support
 var poses:Array[Vector2]=[Vector2(center-100,support.position.y-24),Vector2(center+90,support.position.y-24),Vector2(center+220,support.position.y-24)]
 for i:int in poses.size():
  app.player.reset_at(poses[i])
  for unused:int in 30:await physics_frame;await process_frame
  paused=true
  for unused:int in 3:await process_frame
  for variant:String in ["before","candidate"]:
   tower.visible=variant=="candidate"
   await RenderingServer.frame_post_draw
   var path:=output+"/window_"+str(i)+"_"+variant+".png"
   var err:=root.get_texture().get_image().save_png(path)
   var camera:=root.get_camera_2d()
   rows.append({"window":i,"variant":variant,"file":path,"save_error":err,"actual_player":PlainsSemanticLandscape.pair(app.player.global_position),"actual_camera":PlainsSemanticLandscape.pair(camera.global_position),"zoom":PlainsSemanticLandscape.pair(camera.zoom),"actual_landscape":landscape.measured_nodes(),"scope":"Paused real formal DemoApp/map2 static reset pose; no traversal or normal-speed movie claim"})
  paused=false
 var woods:Array[Dictionary]=[]
 for e:Dictionary in landscape.entries:
  if e.family.family_id=="woodland_two_depth_ridges_v1":woods.append(e)
 if not woods.is_empty():
  var ref:Vector2=woods[0].parallax_reference-Vector2(300,0)
  var pos:=Vector2.ZERO;var best:=INF
  for slab:Rect2 in landscape.supports:
   if slab.size.x<100:continue
   var trial:=Vector2(clampf(ref.x,slab.position.x+48,slab.end.x-48),slab.position.y-24)
   var distance:=trial.distance_squared_to(ref)
   if distance<best:best=distance;pos=trial
  app.player.reset_at(pos)
  for unused:int in 30:await physics_frame;await process_frame
  paused=true
  for unused:int in 3:await process_frame
  for variant:String in ["woods_on","woods_off"]:
   for e:Dictionary in woods:(e.sprite as Sprite2D).visible=variant=="woods_on"
   await RenderingServer.frame_post_draw
   var path:=output+"/"+variant+".png"
   var err:=root.get_texture().get_image().save_png(path)
   var camera:=root.get_camera_2d()
   rows.append({"variant":variant,"file":path,"save_error":err,"actual_player":PlainsSemanticLandscape.pair(app.player.global_position),"actual_camera":PlainsSemanticLandscape.pair(camera.global_position),"zoom":PlainsSemanticLandscape.pair(camera.zoom),"actual_landscape":landscape.measured_nodes(),"scope":"Counterfactual diagnostic Sprite.visible toggle only while paused, restored afterward. Same source/actor/camera; not version improvement or traversal proof"})
  for e:Dictionary in woods:(e.sprite as Sprite2D).visible=true
  paused=false
 var actual_issues:=landscape.actual_issues()
 var f:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"root_seed":"level-design-v2-baseline","map_index":2,"manifest_hash":stage.generated.manifest.manifest_hash,"manifest_unchanged":before==JSON.stringify(stage.generated.manifest),"issues":actual_issues,"rows":rows})+"\n");f.close()
 app.free();await process_frame
 print("HIGHLAND STATIC: 3 paired actual windows; issues=",actual_issues)
 quit(0 if actual_issues.is_empty() else 1)
