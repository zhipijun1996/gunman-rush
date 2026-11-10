extends "res://tests/world/approved_draft_actions.gd"
## Three actual adapters on an authored one-way receiving platform.
func key(code:Key,held:bool)->void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=held
 app.player.get_node("KeyboardMouseAdapter")._unhandled_input(event)
func touch(id:int,point:Vector2,held:bool)->void:
 var event:=InputEventScreenTouch.new();event.index=id;event.position=point;event.pressed=held
 app.overlay.handle_touch(event)
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R35");await fixture(Vector2(240,398))
 key(KEY_S,true);await ticks(40)
 check(app.player.is_on_floor() and absf(app.player.position.y-398)<2,"keyboard Down alone stays on receiving platform")
 key(KEY_SPACE,true);await ticks(8)
 check(app.player.position.y>414 and app.player.velocity.y>0,"keyboard Down+Jump drops without upward jump "+str(app.player.position)+" "+str(app.player.velocity))
 key(KEY_SPACE,false);key(KEY_S,false)
 await fixture(Vector2(240,398))
 var pad:=app.player.get_node("GamepadAdapter") as GamepadAdapter
 pad.sample_tick(Vector2.ZERO,Vector2.ZERO);pad.sample_tick(Vector2.DOWN,Vector2.ZERO);await ticks(30)
 check(app.player.is_on_floor(),"gamepad Down alone stays grounded")
 pad.sample_tick(Vector2.DOWN,Vector2.ZERO,true);await ticks(8)
 check(app.player.position.y>414,"gamepad Down+Jump drops "+str(app.player.position))
 pad.sample_tick(Vector2.ZERO,Vector2.ZERO,false)
 await fixture(Vector2(240,398));app.overlay.set_enabled(true)
 var left:Vector2=app.overlay.left_center
 touch(10,left,true)
 var drag:=InputEventScreenDrag.new();drag.index=10;drag.position=left+Vector2.DOWN*app.overlay.radius
 app.overlay.handle_touch(drag);await ticks(30)
 check(app.player.is_on_floor(),"touch Down alone stays grounded")
 touch(11,app.overlay.jump_center,true);await ticks(8)
 check(app.player.position.y>414,"touch Down+Jump drops "+str(app.player.position))
 touch(11,app.overlay.jump_center,false);touch(10,drag.position,false)
 app.overlay.set_enabled(false)
 await fixture(Vector2(1856,142));key(KEY_S,true);key(KEY_SPACE,true);await ticks(100)
 check(app.player.is_on_floor() and absf(app.player.position.y-558)<2,"holding Down+Jump stops on the next one-way deck "+str(app.player.position))
 key(KEY_SPACE,false);key(KEY_S,false)
 await fixture(Vector2(1056,1614));key(KEY_S,true);key(KEY_SPACE,true);await ticks(8)
 check(app.player.position.y<1580,"Down+Jump on solid ground remains a normal jump")
 key(KEY_SPACE,false);key(KEY_S,false)
 await fixture(Vector2(240,398));key(KEY_SPACE,true);await ticks(8)
 check(app.player.position.y<370,"Jump alone rises through normal jump")
 key(KEY_SPACE,false)
 # Cancelled chord cannot reappear after room transition/reset.
 key(KEY_S,true);key(KEY_SPACE,true);app.controller.router.clear("room transition");await fixture(Vector2(240,398));await ticks(20)
 check(app.player.is_on_floor(),"cancelled chord does not revive on landing")
 key(KEY_SPACE,false);key(KEY_S,false)
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("PLATFORM DROP INPUT: ",failures," failures");quit(failures)
