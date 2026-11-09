extends SceneTree
## Next-batch local fixtures: the common bridge, real contacts and selected actions.
var app: FixedWorldApp
var failures:=0
func _initialize() -> void:run.call_deferred()
func ticks(n: int) -> void:
 for i: int in n:await physics_frame
func check(ok: bool,label: String) -> void:
 print("NEXT BATCH ",ok," ",label)
 if not ok:failures+=1
func load_room(id: String) -> void:
 var source:=load("res://game/world/regions/P/rooms/"+id+".tscn").instantiate() as FixedWorldRoom
 var draft:=WorldRoomDraft.extract(source)
 check(WorldRoomDraft.validate(source,draft).is_empty(),id+" codec")
 source.free()
 draft.base_content_version=app.content.workbench_base_version();draft.revision=1
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FixedWorldProvider.WORKBENCH_CATALOG))
 var row:Dictionary=catalog.rooms[id]
 draft.geometry={"bounds":row.world_geometry.bounds_world_units,"space_rects":row.world_geometry.space_rects,"doors":row.doors}
 await app.workbench._handle({"channel":"gunman-workbench","type":"load_draft","request_id":id,"revision":1,"draft":draft,"stage":"base","paused":false})
 await ticks(4)
 check(app.room.room_id==id and app.player.is_on_floor(),id+" bridge and entry contact "+str(app.player.position))
func fixture(at:Vector2) -> void:
 app.controller.router.clear("declared approach fixture");app.player.reset_at(at)
 app.lifetime.invalidate_actor();app.controller.session_id+=1
 (app.camera as WorldCamera).reset_view();await ticks(4)
func run() -> void:
 root.size=Vector2i(1280,720)
 app=load("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://next_batch_isolated.json";root.add_child(app);app.workbench.enabled=true
 for id:String in ["P-R08","P-R06","P-R13"]:
  await load_room(id)
  for door:Dictionary in app.room.doors:
   var at:=FixedWorldProvider.point(door.landing_contract.safe_standing_position_world_units)
   await fixture(at)
   check(app.player.is_on_floor() and app.player.position.distance_to(at)<3,id+" safe support "+door.id+" "+str(app.player.position))
 await load_room("P-R08")
 await fixture(Vector2(688,2926))
 var bell:=app.room.mechanisms["P-R08:well_lift"] as WorldShotLatch
 app.controller.router.request_action(&"shoot_release",(bell.bell_position-app.player.position).normalized());await ticks(20)
 check((app.room.get_node("WellLift") as WorldMovingPlatform).motion_running,"P08 first lift starts from real bell hit")
 await fixture(Vector2(848,1806))
 app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
 app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
 var boarded:=false
 for i:int in 80:
  await ticks(1)
  if app.player.position.x>=928:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor() and app.player.position.y<1650:boarded=true;break
 check(boarded,"P08 recoil boards upper lift "+str(app.player.position))
 await fixture(Vector2(704,142));app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for i:int in 180:
  await ticks(1)
  if app.room!=null and app.room.room_id=="P-R06" and not app.busy:break
 check(app.room.room_id=="P-R06" and app.player.is_on_floor(),"P08 upper doorway enters P06 through real jump")
 await load_room("P-R06")
 for recoil:bool in [false,true]:
  await fixture(Vector2(1032,1806));app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(10)
  if recoil:app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
  await ticks(12);print("P06 launch ",recoil," ",app.player.position);app.controller.router.set_source_axis(&"keyboard_mouse",1)
  var landed:=false
  for i:int in 65:
   await ticks(1)
   if app.player.is_on_floor() and app.player.position.y<1640:landed=true;break
  check(landed==recoil,"P06 high bank needs recoil "+str(recoil)+" "+str(app.player.position))
 await fixture(Vector2(144,1678));app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for i:int in 180:
  await ticks(1)
  if app.room!=null and app.room.room_id=="P-R13" and not app.busy:break
 app.controller.router.clear("crossed doorway")
 check(app.room.room_id=="P-R13" and app.player.is_on_floor(),"P06 west doorway enters P13 through real walk")
 await load_room("P-R13")
 await fixture(Vector2(3600,2478));app.controller.router.set_source_axis(&"keyboard_mouse",-1);app.controller.router.set_jump_held(&"keyboard_mouse",true)
 await ticks(40)
 check(app.player.position.x<3456 and app.player.position.y<2520,"P13 lower road ordinary jump "+str(app.player.position))
 await fixture(Vector2(2840,1966))
 var shutter:=app.room.mechanisms["P-R13:thorn_shutter"] as WorldShotLatch
 app.controller.router.set_source_axis(&"keyboard_mouse",-1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
 app.controller.router.request_action(&"shoot_release",(shutter.bell_position-app.player.position).normalized())
 await ticks(21);print("SHUTTER ",shutter.open_count," ",app.player.position);app.controller.router.clear("upper shutter finished");await ticks(15)
 check(shutter.open_count==1 and app.player.position.x<2704 and app.player.position.y<2000,"P13 thorn gallery shot/recoil shutter "+str(app.player.position))
 for at:Vector2 in [Vector2(576,2478),Vector2(2440,2478)]:
  await fixture(at);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
  app.controller.router.request_action(&"shoot_release",Vector2.DOWN if at.x<1000 else Vector2(.3,1).normalized())
  var highest:=app.player.position.y
  for i:int in 50:await ticks(1);highest=minf(highest,app.player.position.y)
  check(highest>2240,"P13 sealed reward shelf cannot be reverse-entered from lower approach "+str(at)+" top="+str(highest))
 await fixture(Vector2(416,2478));(app.camera as WorldCamera).reset_view();await ticks(45)
 var half:=Vector2(root.size)/(2*app.camera.zoom)
 var view:=Rect2(app.camera.get_screen_center_position()-half,half*2)
 check(view.has_point(Vector2(384,2222)),"P13 lower west approach sees upper reward before04 "+str(view))
 await fixture(Vector2(384,2222));app._interact();await ticks(12)
 check(app.state.has("found_HP01"),"P13 actual HP01 interaction")
 await fixture(Vector2(448,2222));app._interact();await ticks(12)
 check(app.state.has("reward_return_HP01_open"),"P13 reward-side return opens")
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 var returned:=false
 for i:int in 100:
  await ticks(1)
  if app.player.position.x>=576:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor() and app.player.position.y>2400:returned=true;break
 check(returned,"P13 reward side drops onto ordinary road "+str(app.player.position))
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
 print("NEXT BATCH: ",failures," failures");quit(failures)
