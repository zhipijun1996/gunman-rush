extends "res://tests/world/approved_hub_actions.gd"
## Actual P05 entry through reward and opened return corridor; no intermediate fixture.
func run()->void:
 root.size=Vector2i(1280,720)
 var authored:=load("res://game/world/regions/P/rooms/P-R05.tscn").instantiate() as FixedWorldRoom
 var draft:=WorldRoomDraft.extract(authored)
 check(WorldRoomDraft.validate(authored,draft).is_empty(),"P05 current scene codec accepts its return lift")
 (authored.get_node("ReturnLift") as WorldMovingPlatform).activation_flag=""
 check(WorldRoomDraft.apply(authored,draft).is_empty() and authored.get_node("ReturnLift").activation_flag=="shortcut_p02","P05 codec round-trip preserves permanent activation binding")
 authored.free()
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R05");await ticks(30)
 movie_mark("start")
 var return_lift:=app.room.get_node("ReturnLift") as WorldMovingPlatform
 check(not return_lift.visible and return_lift.collision_layer==0,"P05 return lift absent before shortcut unlock")
 check((app.room.get_node("RewardReturn") as WorldReturnLatch).closed_bodies[0].collision_layer==1,"P05 return passage starts gated")
 await walk_to(192)
 app.controller.router.request_action(&"shoot_release",(Vector2(224,320)-app.player.position-Vector2(0,-6)).normalized());await ticks(35)
 var lift:=app.room.get_node("Carrier0") as WorldMovingPlatform
 check(lift.motion_running,"P05 actual starting shore shot starts carrier")
 await walk_to(302)
 await ticks(160)
 app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(16)
 app.controller.router.request_action(&"shoot_release",Vector2(-.98,.2).normalized())
 var boarded:=false
 for i:int in 100:
  await ticks(1)
  app.controller.router.set_source_axis(&"keyboard_mouse",clampf((lift.position.x-app.player.position.x)/18,-1,1))
  if app.player.is_on_floor():
   boarded=absf(app.player.position.y-(lift.position.y-30))<8
   break
 app.controller.router.clear("boarded")
 check(boarded,"P05 real entry to carrier "+str(app.player.position)+" "+str(lift.position))
 await ticks(40)
 for i:int in 360:
  if lift.position.x>=610 and lift.position.x<660:break
  await ticks(1)
 app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(16)
 app.controller.router.request_action(&"shoot_release",(Vector2(448,336)-app.player.position-Vector2(0,-6)).normalized())
 var reached:=false
 for i:int in 100:
  await ticks(1)
  if app.player.position.x>=928:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor():
   reached=absf(app.player.position.y-206)<5
   break
 app.controller.router.clear("inspection bank")
 check(reached and not lift.motion_running,"P05 air shot stops drive and reaches inspection bank "+str(app.player.position))
 if reached:
  await walk_to(1020)
  app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(16)
  app.controller.router.request_action(&"shoot_release",Vector2(-.92,.392).normalized())
  var reward_bank:=false
  for i:int in 100:
   await ticks(1)
   if app.player.position.x>=1340:app.controller.router.set_source_axis(&"keyboard_mouse",0)
   if app.player.is_on_floor():
    reward_bank=absf(app.player.position.y-142)<5
    break
  app.controller.router.clear("reward bank")
  check(reward_bank,"P05 continuous route to reward bank "+str(app.player.position))
  if reward_bank:
   movie_mark("reward_return")
   await walk_to(1360);app._interact();await ticks(35)
   await walk_to(1456);app._interact();await ticks(35)
   check(app.state.has("reward_return_TG02_open"),"P05 reward return latch opens")
   await walk_to(1488)
   well_key(KEY_S,true);well_key(KEY_SPACE,true);await ticks(8);well_key(KEY_SPACE,false);well_key(KEY_S,false)
   for i:int in 80:
    await ticks(1)
    if app.player.position.y>=534:break
   var omit_return_shot:bool="--no-return-shot" in OS.get_cmdline_user_args()
   if not omit_return_shot:app.controller.router.request_action(&"shoot_release",Vector2.LEFT)
   await walk_to(1664);await ticks(55)
   if omit_return_shot:
    check(app.player.position.x<1536,"P05 ordinary falling horizontal movement cannot cross the recoil throat")
    await WorldAudioLifecycle.drain_world(app);quit(failures);return
   check(app.player.is_on_floor() and absf(app.player.position.y-622)<5,"P05 drop-through and airborne left shot recoil into return corridor "+str(app.player.position))
   await walk_to(1776);app._interact();await ticks(25)
   check(app.state.has("shortcut_p02"),"P05 actual return switch opens P06")
   await walk_to(1980);await ticks(60)
   check(app.room.room_id=="P-R06","P05 continuous room route exits to P06")
   if app.room.room_id=="P-R06":
    await ticks(25);await walk_to(120);await ticks(50)
    check(app.room.room_id=="P-R05" and app.state.has("shortcut_p02"),"P05 opened doorway supports actual return")
    return_lift=app.room.get_node("ReturnLift") as WorldMovingPlatform
    check(return_lift.visible and return_lift.collision_layer==1,"P05 return lift restored on room re-entry")
    movie_mark("return_board")
    await walk_to(1792)
    # Wait at the right terminal for the actual shuttle; do not restore its clock.
    for i:int in 1200:
     if return_lift.position.distance_to(return_lift.origin)<1:break
     await ticks(1)
    app.controller.router.set_jump_held(&"keyboard_mouse",true)
    for i:int in 80:
     app.controller.router.set_source_axis(&"keyboard_mouse",clampf((return_lift.position.x-app.player.position.x)/18,-1,1))
     await ticks(1)
     if i==24:app.controller.router.set_jump_held(&"keyboard_mouse",false)
     if i>3 and app.player.is_on_floor():break
    app.controller.router.clear("return lift boarded")
    check(app.player.is_on_floor() and absf(app.player.position.y-(return_lift.position.y-30))<5,"P05 physically board the unlocked return lift")
    movie_mark("return_ride")
    var arrived:=false
    for i:int in 700:
     await ticks(1)
     if return_lift.position.distance_to(return_lift.origin+return_lift.route[-1])<1:
      arrived=app.player.is_on_floor() and absf(app.player.position.y-(return_lift.position.y-30))<5
      break
    check(arrived,"P05 right-to-left return ride clears throat and platform undersides "+str(app.player.position))
    await walk_to(1024);await ticks(30)
    check(app.player.is_on_floor() and absf(app.player.position.y-206)<5,"P05 disembark onto left inspection bank "+str(app.player.position)+" lift "+str(return_lift.position))
 await ticks(35)
 if "--movie" not in OS.get_cmdline_user_args(): await unlock_save_roundtrip()
 await WorldAudioLifecycle.drain_world(app);quit(failures)
func walk_to(x:float)->void:
 var room_id:=app.room.room_id
 for i:int in 120:
  if app.room.room_id!=room_id or absf(app.player.position.x-x)<5:break
  app.controller.router.set_source_axis(&"keyboard_mouse",signf(x-app.player.position.x));await ticks(1)
 app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(3)

func unlock_save_roundtrip() -> void:
 var storage:=WorldSaveService.new()
 var path:="user://p05_return_lift_test.json"
 storage.configure(path,false,"p05_return_lift_test")
 storage.content_version=app.content.data.content_version
 storage.payload_validator=app.state.valid
 check(storage.commit(app.state.value,app.state.revision),"P05 unlocked state writes to an isolated disk save")
 var restored:=FixedWorldState.new();restored.content=app.content;restored.storage=storage
 check(restored.restore() and restored.has("shortcut_p02"),"P05 disk reload retains the actual unlock fact")
 var source:=load("res://game/world/regions/P/rooms/P-R05.tscn").instantiate() as FixedWorldRoom
 var carrier:=source.get_node("ReturnLift") as WorldMovingPlatform
 source.remove_child(carrier);source.free();root.add_child(carrier)
 carrier.bind_activation(restored);await ticks(3)
 check(carrier.visible and carrier.collision_layer==1 and carrier.position.distance_to(carrier.origin)<1,"P05 freshly loaded carrier is active at its safe right terminal")
 carrier.queue_free();await ticks(2)
 for suffix:String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(path+suffix)

func movie_mark(label:String)->void:
 if "--movie" in OS.get_cmdline_user_args(): print("MOVIE_MARK ",label," ",Engine.get_process_frames())
