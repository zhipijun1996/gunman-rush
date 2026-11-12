extends SceneTree
var app:FixedWorldApp
var failures:=0
func _initialize()->void:run.call_deferred()
func ticks(n:int)->void:
 for i:int in n:await physics_frame
func check(ok:bool,label:String)->void:
 print("PANORAMA ",ok," ",label)
 if not ok:failures+=1
## Real room renders at 1wu/px, without HUD/player; other rooms stay unloaded.
func run()->void:
 var args:=OS.get_cmdline_user_args()
 var folder:String=args[0] if not args.is_empty() else "res://build/plains-panorama"
 DirAccess.make_dir_recursive_absolute(folder+"/rooms")
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 var records:Array=[]
 for id:String in app.content.data.rooms:
  check(await app.review.begin(id,"","base",true),id+" panorama load")
  await ticks(6)
  app.controller.active=false;app.set_physics_process(false);app.player.set_physics_process(false);app.player.hide()
  for actor:EnemyActor in app.room.enemies.values():
   if is_instance_valid(actor):actor.get_parent().set_physics_process(false);actor.set_physics_process(false)
  app.ui.hide();app.overlay.hide();app.camera.enabled=false;app.camera.set_process(false);app.camera.set_physics_process(false)
  for mask:Node2D in app.room.camera_concealers.values():mask.hide()
  var area:=FixedWorldProvider.rect(app.room.contract.world_geometry.bounds_world_units)
  root.size=Vector2i(area.size);root.content_scale_size=root.size
  var overview:=Camera2D.new();overview.position=area.get_center();overview.zoom=Vector2.ONE;root.add_child(overview);overview.make_current()
  await ticks(8);paused=true;await RenderingServer.frame_post_draw
  var file:=folder+"/rooms/"+id+".png"
  check(root.get_texture().get_image().save_png(file)==OK,id+" native room image")
  var markers:Array=[]
  if app.room.rest_point!=Vector2.ZERO:markers.append({"kind":"rest","point":[app.room.rest_point.x,app.room.rest_point.y]})
  if not app.room.boss_identity.is_empty():markers.append({"kind":"boss","point":[app.room.boss_position.x,app.room.boss_position.y]})
  if app.room.reward_point!=Vector2.ZERO:markers.append({"kind":"reward","point":[app.room.reward_point.x,app.room.reward_point.y],"action":app.room.reward_action})
  for host:WorldRoomInteraction in app.room.interaction_hosts:
   if host.action_id.begins_with("pickup_") or host.visual in ["chest","clock_altar"]:markers.append({"kind":"chest" if host.visual=="chest" else "clock" if host.visual=="clock_altar" else "reward","point":[host.position.x,host.position.y],"action":host.action_id})
  records.append({"room":id,"markers":markers,"size":[int(area.size.x),int(area.size.y)],"file":id+".png","player_hidden":true,"conceal_masks_hidden_for_inspection":true})
  paused=false;overview.queue_free();await ticks(1)
  root.size=Vector2i(1280,720);root.content_scale_size=root.size
  app.camera.enabled=true;app.camera.make_current();app.camera.set_process(true);app.camera.set_physics_process(true)
  app.ui.show();app.overlay.show();app.player.show();app.player.set_physics_process(true);app.controller.active=true;app.set_physics_process(true)
 FileAccess.open(folder+"/captures.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
 await WorldAudioLifecycle.drain_world(app);print("PANORAMA CAPTURE: ",records.size()," rooms, ",failures," failures");quit(failures)
