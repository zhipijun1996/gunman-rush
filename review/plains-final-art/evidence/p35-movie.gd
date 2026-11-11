extends "res://tests/world/plains35_fixture.gd"
func mark(label:String)->void:print("MOVIE_MARK ",label," ",Engine.get_frames_drawn()," ",app.player.position)
func drop()->void:
 well_key(KEY_S,true);well_key(KEY_SPACE,true);await ticks(8);well_key(KEY_SPACE,false);well_key(KEY_S,false)
func well_key(code:Key,held:bool)->void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=held;Input.parse_input_event(event)
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R35","HUB-P33-P35:P-R35","base"),"P35 actual tower entry; enemies active")
 await ticks(30);mark("tower_landing")
 app.controller.router.request_action(&"shoot_release",Vector2(-16,-52).normalized());await ticks(25)
 var lift:=app.room.get_node("JunctionLift") as WorldMovingPlatform
 check(lift.motion_running,"entry shot starts transport")
 await drop();await ticks(95);mark("upper_transfer")
 await drop()
 var boarded:=false
 for i:int in 480:
  await ticks(1)
  if app.player.is_on_floor() and app.player.position.distance_to(lift.position-Vector2(0,28))<85:
   boarded=true;break
 check(boarded,"continuous drop lands on active lift");mark("boarding")
 for i:int in 600:
  await ticks(1)
  if app.player.position.y<240:break
 check(app.player.position.y<240,"transport returns to tower head");mark("arrival")
 await ticks(30)
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(70);app.controller.router.clear("finish")
 mark("exit");await WorldAudioLifecycle.drain_world(app);quit(failures)
