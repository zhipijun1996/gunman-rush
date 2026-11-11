extends "res://tests/world/approved_hub_actions.gd"
# Continuous real inputs from paired entry. Boss terminal damage is explicit;
# this validates postfight traversal, not a played full Boss defeat.
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R14","APPROACH-P27-P14:P-R14","base"),"actual P27 entrance")
 await ticks(20);mark("entry")
 await jump_to(Vector2(384,1102),Vector2.ZERO,"first shoulder")
 await jump_to(Vector2(416,942),Vector2.DOWN,"second shoulder")
 await jump_to(Vector2(400,742),Vector2.DOWN,"preparation bank")
 await walk_to(600);await ticks(30)
 check(app.room.battle_started,"natural approach starts Boss")
 mark("combat")
 for frame:int in 420:
  if frame%70==0:app.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
  if frame%130==0:app.controller.router.set_jump_held(&"keyboard_mouse",true)
  if frame%130==45:app.controller.router.set_jump_held(&"keyboard_mouse",false)
  await ticks(1)
 await WorldAudioLifecycle.drain_world(app);quit(failures)

func cast(target:Vector2,hang:bool)->void:
 app.controller.router.set_jump_held(&"keyboard_mouse",false)
 app.controller.router.set_source_axis(&"keyboard_mouse",0)
 app.controller.router.request_action(&"grapple",(target-app.player.position-Vector2(0,-6)).normalized())
 var reached:=false
 for frame:int in 100:
  await ticks(1)
  if (hang and app.controller.traversal.state==&"hook_hang") or (not hang and app.controller.traversal.state in [&"hook_contact_kick",&"hook_kick"]):reached=true;break
 check(reached,"hook "+str(target)+" at "+str(app.player.position))
func land_at(target:Vector2,label:String)->void:
 app.controller.router.set_source_axis(&"keyboard_mouse",signf(target.x-app.player.position.x))
 for frame:int in 150:
  await ticks(1)
  if absf(target.x-app.player.position.x)<8:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor():break
 check(app.player.is_on_floor() and absf(app.player.position.y-target.y)<5,label+" "+str(app.player.position))
 app.controller.router.clear("land");await ticks(12)
func mark(label:String)->void:print("MOVIE_MARK ",label," ",Engine.get_frames_drawn()," physics ",Engine.get_physics_frames())
func walk_to(x:float)->void:
 var id:=app.room.room_id
 for i:int in 600:
  if app.room.room_id!=id or absf(app.player.position.x-x)<5:break
  app.controller.router.set_source_axis(&"keyboard_mouse",signf(x-app.player.position.x));await ticks(1)
 app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(3)
func jump_to(target:Vector2,aim:Vector2,label:String)->void:
 var axis:=signf(target.x-app.player.position.x)
 app.controller.router.set_source_axis(&"keyboard_mouse",axis);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(16)
 if aim!=Vector2.ZERO:app.controller.router.request_action(&"shoot_release",aim)
 var reached:=false
 for i:int in 120:
  await ticks(1)
  if (app.player.position.x-target.x)*axis>=0 or absf(app.player.position.x-target.x)<5:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor():
   reached=absf(app.player.position.y-target.y)<5;break
 check(reached,label+" "+str(app.player.position));app.controller.router.clear("jump complete")
 await ticks(12)
