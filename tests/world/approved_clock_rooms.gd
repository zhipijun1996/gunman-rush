extends "res://tests/world/approved_draft_actions.gd"
## Real formal rooms/inputs. Local starts and a lethal health fixture isolate
## progression; this is not a full Boss fight or uninterrupted campaign replay.
func victory(id:String)->void:
 check(not app.room.battle_started,id+" entry stays outside battle")
 var zoom:=app.camera.zoom
 await fixture(app.room.battle_entry_anchor);await ticks(8)
 check(app.room.battle_started and not app.room.battle_finished,id+" grounded approach starts battle")
 check(app.camera.zoom==zoom,id+" Boss composition preserves zoom")
 var health:=app.room.encounter.health
 health.apply_damage(ActorResourceRequest.new(&"victory_integration_fixture",health.epoch,health.current+1,health.get_instance_id()))
 await ticks(12)
 check(app.room.battle_finished and app.state.has(app.room.defeat_flag),id+" terminal Boss commits victory and opens seals")
 for seal:StaticBody2D in app.room.seals:check(seal.collision_layer==0,id+" battle seal released")

func cache(id:String,at:Vector2,amount:int)->void:
 await fixture(at)
 var before:int=app.services.ledger().gold
 app._interact();await ticks(4)
 var total:int=int(app.services.ledger().gold)-before
 for drop:Dictionary in app.services.ledger().drops.values():
  if str(drop.source)=="chest:"+id:total+=int(drop.amount)
 check(app.state.value.receipts.has(id) and total==amount,id+" one-time physical interaction pays exact coins")
 var revision:int=app.state.revision
 app._commit_action(id);check(app.state.revision==revision,id+" repeated open rejected")
 check(app.state.valid(app._snapshot()),id+" valid persistent receipt")

func hook(start:Vector2,target:Vector2,label:String,delay:int=0)->void:
 await fixture(start)
 if delay>0:app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(delay)
 app.controller.router.request_action(&"grapple",(target-app.player.position-Vector2(0,-6)).normalized())
 var reached:=false
 for frame:int in 90:
  await ticks(1)
  if app.controller.traversal.state==&"hook_hang":reached=true;break
 check(reached,label+" "+str(app.player.position))
 app.controller.router.set_jump_held(&"keyboard_mouse",false)

func next_hook(target:Vector2,label:String,jump:bool=true,recoil:bool=false)->void:
 app.controller.router.set_jump_held(&"keyboard_mouse",false)
 if jump:
  app.controller.router.set_source_axis(&"keyboard_mouse",signf(target.x-app.player.position.x))
  app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(18)
  if recoil:app.controller.router.request_action(&"shoot_release",Vector2.DOWN);await ticks(6)
 app.controller.router.request_action(&"grapple",(target-app.player.position-Vector2(0,-6)).normalized())
 var reached:=false
 for frame:int in 100:
  await ticks(1)
  if app.controller.traversal.state==&"hook_hang" and app.player.position.distance_to(target)<65:reached=true;break
 check(reached,label+" "+str(app.player.position))
 app.controller.router.set_source_axis(&"keyboard_mouse",0)
 app.controller.router.set_jump_held(&"keyboard_mouse",false)

func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 if selected("P-R11"):
  await load_room("P-R11","h")
  check(not app.state.holds(app.content.action("pickup_skill_core_root").requires),"P11 unique skill core locked before victory")
  check(not app.state.holds(app.content.action("open_P11_crown_cache").requires),"P11 high cache cannot bypass battle")
  await victory("P11")
  await fixture(Vector2(2240,1134));app._interact();await ticks(4)
  check(app.state.value.receipts.has("pickup_skill_core_root"),"P11 actual core pickup after victory")
  await hook(Vector2(2240,1134),Vector2(2352,896),"P11 first frame hook",16)
  await next_hook(Vector2(2304,544),"P11 second frame hook after jump and recoil",true,true)
  await next_hook(Vector2(2192,256),"P11 third frame hook",true,true)
  app.controller.router.set_jump_held(&"keyboard_mouse",true);app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(12)
  app.controller.router.request_action(&"shoot_release",Vector2.LEFT)
  for frame:int in 100:
   await ticks(1)
   if app.player.position.x>2440:app.controller.router.set_source_axis(&"keyboard_mouse",0)
   if app.player.is_on_floor():break
  check(app.player.is_on_floor() and absf(app.player.position.y-238)<4,"P11 recoil from frame to top bank "+str(app.player.position))
  await cache("open_P11_crown_cache",Vector2(2528,238),30)
 if selected("P-R14"):
  await load_room("P-R14")
  await hop(Vector2(512,1230),Vector2(384,1102),Vector2.ZERO,"P14 first widened approach shoulder")
  await hop(Vector2(384,1102),Vector2(416,942),Vector2.DOWN,"P14 rise to second shoulder")
  await hop(Vector2(416,942),Vector2(400,742),Vector2.DOWN,"P14 recoil to preparation bank")
  check(not app.state.has("H"),"P14 approach needs no granted H")
  await victory("P14")
  await fixture(Vector2(1800,742));app._interact();await ticks(8)
  check(app.state.has("H") and app.controller.traversal.hook_enabled,"P14 reward activates actual hook consumer")
  await hook(Vector2(1984,558),Vector2(1840,408),"P14 first holding hook")
  await fixture(Vector2(2176,366));app.controller.router.request_action(&"grapple",(Vector2(2304,264)-app.player.position).normalized())
  var bounced:=false
  for frame:int in 65:await ticks(1);bounced=bounced or app.controller.traversal.state in [&"hook_contact_kick",&"hook_kick"]
  check(bounced,"P14 spring hook actually releases")
  await hop(Vector2(2112,974),Vector2(2448,910),Vector2.LEFT,"P14 first low-return gap")
  await hop(Vector2(2848,910),Vector2(3168,974),Vector2.LEFT,"P14 second low-return gap")
 if selected("P-R15"):
  await load_room("P-R15","h")
  # Approach goes outside the solid throat before casting; not through its wall.
  await fixture(Vector2(960,3758));app.controller.router.set_source_axis(&"keyboard_mouse",1)
  for frame:int in 40:
   await ticks(1)
   if app.player.position.x>=1048 and app.player.position.y>=3790:break
  app.controller.router.set_source_axis(&"keyboard_mouse",0)
  app.controller.router.request_action(&"grapple",(Vector2(1120,3840)-app.player.position).normalized());await ticks(35)
  check(app.controller.traversal.state==&"hook_hang","P15 first hook after rounding the throat "+str(app.player.position))
  await next_hook(Vector2(1296,3808),"P15 middle crossing hook",false)
  await next_hook(Vector2(1472,3840),"P15 far crossing hook",false)
  app.controller.router.set_jump_held(&"keyboard_mouse",true);app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(8);app.controller.router.request_action(&"shoot_release",Vector2.LEFT)
  for frame:int in 100:
   await ticks(1)
   if app.player.position.x>1620:app.controller.router.set_source_axis(&"keyboard_mouse",0)
   if app.player.is_on_floor():break
  check(app.player.is_on_floor() and absf(app.player.position.y-3918)<4,"P15 cross to clock bank "+str(app.player.position))
  await hook(Vector2(1152,4686),Vector2(1152,4528),"P15 basin recovery first hook")
  for target:Vector2 in [Vector2(1280,4320),Vector2(1408,4112),Vector2(1488,3896)]:await next_hook(target,"P15 recovery chain")
  app.controller.router.set_jump_held(&"keyboard_mouse",true);app.controller.router.set_source_axis(&"keyboard_mouse",1)
  for frame:int in 100:
   await ticks(1)
   if app.player.position.x>1600:app.controller.router.set_source_axis(&"keyboard_mouse",0)
   if app.player.is_on_floor():break
  check(app.player.is_on_floor() and absf(app.player.position.y-3918)<4,"P15 recovery final jump returns to clock bank "+str(app.player.position))
  await fixture(Vector2(1952,3918));var zoom:=app.camera.zoom;app._interact();await ticks(365)
  check(app.state.has("clock_P") and app.story.active and app.story.dialogue_active,"P15 actual repair reaches narrative after performance")
  check(app.camera.zoom==zoom and (app.room.get_node("RegionalArt") as PlainsRoomArt).repair_blend>.95,"P15 repair restores environment at fixed zoom")
  app.story.finish();await ticks(5);await fixture(Vector2(2112,3918));app._interact();await ticks(4)
  check(app.state.has("shortcut_p01") and app.state.valid(app._snapshot()),"P15 actual return switch persists after repair")
 if selected("P-R16"):
  await load_room("P-R16")
  await hop(Vector2(512,1166),Vector2(448,878),Vector2.DOWN,"P16 recoil from receiving bank to upper step")
  await hop(Vector2(448,1006),Vector2(448,878),Vector2.ZERO,"P16 ordinary middle step")
  await hop(Vector2(576,878),Vector2(896,750),Vector2.LEFT,"P16 no-H crossing to upper main bank")
  await hop(Vector2(1008,750),Vector2(1296,686),Vector2.LEFT,"P16 no-H route to east exit")
  await load_room("P-R16","h")
  await hook(Vector2(992,750),Vector2(1040,576),"P16 first return hook")
  await next_hook(Vector2(784,416),"P16 upper hook")
  app.controller.router.set_jump_held(&"keyboard_mouse",true);app.controller.router.set_source_axis(&"keyboard_mouse",-1);await ticks(18);app.controller.router.request_action(&"shoot_release",Vector2(.6,.8))
  for frame:int in 100:
   await ticks(1)
   if app.player.position.x<540:app.controller.router.set_source_axis(&"keyboard_mouse",0)
   if app.player.is_on_floor():break
  check(app.player.is_on_floor() and absf(app.player.position.y-206)<4,"P16 recoil up to optional high bank "+str(app.player.position))
  await cache("open_P16_loft_cache",Vector2(480,206),20)
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("APPROVED CLOCK ROOMS: ",failures," failures");quit(failures)
