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
func jump_shot(axis:float, aim:Vector2, delay:int=8) -> void:
 app.controller.router.set_source_axis(&"keyboard_mouse",axis)
 app.controller.router.set_jump_held(&"keyboard_mouse",true)
 await ticks(delay)
 app.controller.router.request_action(&"shoot_release",aim)
func run() -> void:
 root.size=Vector2i(1280,720)
 app=load("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://next_batch_round3.json";root.add_child(app);app.workbench.enabled=true
 for id:String in ["P-R08","P-R06","P-R13"]:
  await load_room(id)
  for door:Dictionary in app.room.doors:
   var at:=FixedWorldProvider.point(door.landing_contract.safe_standing_position_world_units)
   await fixture(at)
   check(app.player.is_on_floor() and app.player.position.distance_to(at)<3,id+" safe support "+door.id+" "+str(app.player.position))
 await load_room("P-R08")
 await fixture(Vector2(864,2926))
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(38)
 app.controller.router.clear("boarded first lift")
 check(app.player.is_on_floor() and app.player.position.y<2880,"P08 ordinary boarding "+str(app.player.position))
 app.controller.router.request_action(&"shoot_release",Vector2.UP);await ticks(15)
 var lift:=app.room.get_node("WellLift") as WorldMovingPlatform
 check(lift.motion_running,"P08 real onboard bell starts first lift")
 for i:int in 500:
  await ticks(1)
  if lift.position.y<=2256.1:break
 check(app.player.is_on_floor() and absf(app.player.position.y-2228)<3,"P08 first ascent unobstructed "+str(app.player.position))
 app.controller.router.set_source_axis(&"keyboard_mouse",-1);await ticks(15)
 await jump_shot(-1,Vector2(.4,.916515),12)
 var boarded:=false
 for i:int in 90:
  await ticks(1)
  if app.player.position.x<592:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor() and app.player.position.y<2050:boarded=true;break
 check(boarded,"P08 recoil transfers to second lift "+str(app.player.position))
 app.controller.router.clear("second deck")
 app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for i:int in 20:
  await ticks(1)
  if app.player.position.x<=578:break
 app.controller.router.clear("centered to shoot bell")
 var bell:=app.room.mechanisms["P-R08:service_lift"] as WorldShotLatch
 app.controller.router.request_action(&"shoot_release",Vector2.UP);await ticks(15)
 lift=app.room.get_node("ServiceLift") as WorldMovingPlatform
 check(lift.motion_running,"P08 real bell starts second lift")
 for i:int in 550:
  await ticks(1)
  if lift.position.y<=1408.1:break
 check(app.player.is_on_floor() and absf(app.player.position.y-1380)<3,"P08 second ascent unobstructed "+str(app.player.position))
 app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(14)
 await jump_shot(1,Vector2(-.4,.916515),12)
 boarded=false
 for i:int in 90:
  await ticks(1)
  if app.player.position.x>880:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor() and app.player.position.y<1200:boarded=true;break
 check(boarded,"P08 recoil transfers to third lift "+str(app.player.position))
 app.controller.router.clear("third deck")
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 for i:int in 25:
  await ticks(1)
  if app.player.position.x>=894:break
 app.controller.router.clear("centered on third deck")
 bell=app.room.mechanisms["P-R08:upper_lift"] as WorldShotLatch
 app.controller.router.request_action(&"shoot_release",(bell.bell_position-app.player.position).normalized());await ticks(15)
 lift=app.room.get_node("UpperLift") as WorldMovingPlatform
 check(lift.motion_running,"P08 real bell starts third lift")
 for i:int in 700:
  await ticks(1)
  if lift.position.y<=240.1:break
 check(app.player.is_on_floor() and absf(app.player.position.y-212)<3,"P08 third ascent unobstructed "+str(app.player.position))
 await load_room("P-R06")
 check(app.room.enemy_placements.size()==7 and app.room.one_way_indices.size()==8,"P06 open hub has mixed aerial and ground encounters")
 await fixture(Vector2(144,1678));app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for i:int in 180:
  await ticks(1)
  if app.room!=null and app.room.room_id=="P-R13" and not app.busy:break
 app.controller.router.clear("crossed doorway")
 check(app.room.room_id=="P-R13" and app.player.is_on_floor(),"P06 west doorway enters P13 through real walk")
 await load_room("P-R13")
 await fixture(Vector2(5680,2158))
 await jump_shot(-1,Vector2.RIGHT,6)
 var crossed:=false
 for i:int in 55:
  await ticks(1)
  if app.player.position.x<5384:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor() and app.player.position.x<5400:crossed=true;break
 check(crossed,"P13 horizontal recoil between floor and ceiling thorns "+str(app.player.position))
 app.controller.router.clear("first low refuge")
 await jump_shot(0,Vector2.DOWN,8)
 await ticks(10);app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 var climbed:=false
 for i:int in 45:
  await ticks(1)
  if app.player.position.x<5320:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor() and app.player.position.y<2000:climbed=true;break
 check(climbed,"P13 upward turn onto refill refuge "+str(app.player.position))
 await fixture(Vector2(5296,1966))
 await jump_shot(-1,Vector2.RIGHT,6)
 crossed=false
 for i:int in 55:
  await ticks(1)
  if app.player.position.x<5024:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor() and app.player.position.x<5040:crossed=true;break
 check(crossed,"P13 upper horizontal recoil to down-turn refuge "+str(app.player.position))
 app.controller.router.clear("downturn approach");app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for i:int in 50:
  await ticks(1)
  if app.player.position.x<4952:app.controller.router.set_source_axis(&"keyboard_mouse",0)
 check(app.player.is_on_floor() and app.player.position.y>2120 and app.player.position.x>4880,"P13 downward turn lands in next refuge "+str(app.player.position))
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
 check(WorldTraveler.chapter(app.state,"P-R21").is_empty(),"traveler story deferred")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
 print("NEXT BATCH: ",failures," failures");quit(failures)
