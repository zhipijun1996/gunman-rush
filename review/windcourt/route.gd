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
 mark("terminal_fixture")
 var health:=app.room.encounter.health
 health.apply_damage(ActorResourceRequest.new(&"victory_integration_fixture",health.epoch,health.current+1,health.get_instance_id()))
 await ticks(30)
 check(app.room.battle_finished,"victory commits")
 await walk_to(1800);app._interact();await ticks(12)
 check(app.state.has("H"),"actual reward grants H")
 mark("gallery")
 await jump_to(Vector2(1900,558),Vector2.DOWN,"reward bank to hook approach")
 await cast(Vector2(1840,408),true)
 await jump_to(Vector2(2000,366),Vector2.ZERO,"first high bank")
 await walk_to(2170)
 await cast(Vector2(2304,264),false)
 await ticks(8);app.controller.router.request_action(&"shoot_release",Vector2.LEFT)
 await land_at(Vector2(2592,334),"first spring reaches high bank")
 await walk_to(2650)
 await cast(Vector2(2820,280),true)
 await jump_to(Vector2(3190,430),Vector2.LEFT,"holding ring to middle bank")
 await walk_to(3370)
 await cast(Vector2(3504,296),false)
 await ticks(8);app.controller.router.request_action(&"shoot_release",Vector2.LEFT)
 app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(16)
 await cast(Vector2(3744,232),true)
 await jump_to(Vector2(4040,366),Vector2.LEFT,"middle ring to east bank")
 await walk_to(4220)
 await cast(Vector2(4392,288),false)
 await ticks(8);app.controller.router.request_action(&"shoot_release",Vector2.LEFT)
 app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(12)
 await cast(Vector2(4608,224),true)
 await jump_to(Vector2(4720,398),Vector2.LEFT,"last ring to clock shaft bank")
 mark("clock_exit")
 await walk_to(4608);await ticks(70)
 check(app.room.room_id=="P-R15","continuous upper route reaches clock")
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(75)
 app.controller.router.clear("return from clock")
 check(app.room.room_id=="P-R14","clock shaft returns to court")
 mark("return_upper")
 await jump_to(Vector2(4420,462),Vector2.RIGHT,"cross clock opening on return")
 await jump_to(Vector2(4200,366),Vector2.DOWN,"return over eastern shoulder")
 await walk_to(3920)
 await jump_to(Vector2(3670,462),Vector2.ZERO,"return to low edge")
 await jump_to(Vector2(3330,430),Vector2.RIGHT,"return across middle shoulder")
 await walk_to(3010);await ticks(65)
 mark("low_gallery")
 check(app.player.is_on_floor() and absf(app.player.position.y-974)<5,"upper route drops into actual low gallery")
 await walk_to(3712);app._interact();await ticks(10)
 check(app.state.has("shortcut_p03"),"actual return switch")
 well_key(KEY_S,true);well_key(KEY_SPACE,true);await ticks(8);well_key(KEY_SPACE,false);well_key(KEY_S,false);await ticks(90)
 check(app.room.room_id=="P-R06","lower shaft reaches junction")
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(85);app.controller.router.clear("junction return")
 check(app.room.room_id=="P-R14","junction returns into court")

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
