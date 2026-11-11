extends "res://tests/world/approved_hub_actions.gd"
func mark(label:String)->void:print("MOVIE_MARK ",label," ",Engine.get_frames_drawn()," position ",app.player.position)
func walk(x:float)->void:
 var id:=app.room.room_id
 for i:int in 300:
  if app.room.room_id!=id or absf(app.player.position.x-x)<5:break
  app.controller.router.set_source_axis(&"keyboard_mouse",signf(x-app.player.position.x));await ticks(1)
 app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(8)
func jump_to(target:Vector2,aim:Vector2=Vector2.ZERO,delay:int=16)->void:
 var axis:=signf(target.x-app.player.position.x)
 app.controller.router.set_source_axis(&"keyboard_mouse",axis)
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(delay)
 if aim!=Vector2.ZERO:app.controller.router.request_action(&"shoot_release",aim)
 for i:int in 110:
  await ticks(1)
  if (target.x-app.player.position.x)*axis<8:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor():break
 app.controller.router.clear("landing")
 check(app.player.is_on_floor() and absf(app.player.position.y-target.y)<6,"continuous landing "+str(target)+" actual "+str(app.player.position));await ticks(12)
func kill_enemy(id:String)->void:
 var enemy:EnemyActor=app.room.enemies.get(id)
 if enemy==null:return
 for i:int in 8:
  if enemy.health.terminal:break
  var stay:=app.player.position.x
  app.controller.router.request_action(&"shoot_release",(enemy.motor.global_position-app.player.global_position).normalized());await ticks(22)
  await walk(stay);await ticks(15)
  if app.player.position.x<200:await walk(310)
 check(enemy.health.terminal,"real shots defeat "+id)
func snap(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/p32-composition/route-"+label+".png")
func isolate_combat()->void:
 # Declared art traversal fixture only; no actor teleport and no gameplay source changes.
 for enemy:EnemyActor in app.room.enemies.values():
  enemy.cancel_attacks();enemy.process_mode=Node.PROCESS_MODE_DISABLED;enemy.motor.position=Vector2(-10000,-10000)
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R32","HUB-P31-P32:P-R32","h"),"actual west entrance; H review stage")
 await ticks(24);isolate_combat();mark("entry")
 await walk(360);await ticks(12)
 await walk(736);mark("gap")
 await jump_to(Vector2(1056,942),Vector2.LEFT)
 await walk(1380)
 await ticks(12)
 await walk(1440);await jump_to(Vector2(1712,814),Vector2(-.8,.6))
 await walk(1880);await ticks(12)
 await walk(1936);await jump_to(Vector2(2096,814))
 mark("bell");await snap("bell")
 app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(10)
 app.controller.router.request_action(&"shoot_release",(Vector2(1952,744)-app.player.position-Vector2(0,-6)).normalized())
 for i:int in 120:
  await ticks(1)
  if app.player.position.x>2230:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor():break
 app.controller.router.clear("board")
 var lift:=app.room.get_node("BridgeInspectionLift") as WorldMovingPlatform
 check(lift.motion_running,"air shot activates real bell")
 check(app.player.is_on_floor() and absf(app.player.position.y-lift.position.y+28)<6,"continuous boarding "+str(app.player.position))
 for i:int in 240:
  await ticks(1)
  if lift.position.y<641:break
 check(app.player.is_on_floor() and absf(app.player.position.y-612)<6,"continuous ride reaches summit "+str(app.player.position));mark("summit")
 await jump_to(Vector2(2496,622));await walk(2680);await ticks(165);mark("vista");await snap("vista")
 if app.story.dialogue_active:
  app.story.advance();await ticks(65);app.story.advance();await ticks(65)
 await walk(3100);await ticks(60)
 check(app.room.room_id=="P-R33","continuous east doorway");mark("east")
 await walk(-50);await ticks(50)
 check(app.room.room_id=="P-R32","actual east return");mark("return");isolate_combat()
 await walk(2440)
 app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for i:int in 120:
  await ticks(1)
  if app.player.position.x<2240:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor() and app.player.position.x<2400:break
 app.controller.router.clear("lower approach")
 for j:int in 4:
  if app.player.position.y>980:break
  well_key(KEY_S,true);well_key(KEY_SPACE,true);await ticks(8);well_key(KEY_SPACE,false);well_key(KEY_S,false)
  await ticks(90)
 check(app.player.is_on_floor() and absf(app.player.position.y-1006)<6,"east return reaches lower deck "+str(app.player.position))
 await walk(2010);await ticks(30);await ticks(12)
 await walk(1792);app._interact();await ticks(60);mark("cache");await snap("cache")
 check(app.state.value.receipts.has("open_P32_pier_cache"),"actual chest reward receipt")
 await walk(2144);await jump_to(Vector2(2240,1006));mark("cache_return");await walk(2352)
 well_key(KEY_S,true);well_key(KEY_SPACE,true);await ticks(8);well_key(KEY_SPACE,false);well_key(KEY_S,false)
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 for i:int in 120:
  await ticks(1)
  if app.player.position.x>2432:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor():break
 app.controller.router.clear("lower landing");await ticks(30);mark("service");await snap("service")
 check(app.player.is_on_floor() and absf(app.player.position.y-1230)<6,"continuous lower service bank "+str(app.player.position))
 await WorldAudioLifecycle.drain_world(app);quit(failures)
