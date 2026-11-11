extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R05")
 await fixture(Vector2(1776,622));app.camera.reset_view();await ticks(25)
 app._interact();await ticks(12)
 check(app.state.has("shortcut_p02"),"P05 actual switch opens the original shortcut")
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 for i:int in 300:
  await ticks(1)
  if app.room.room_id=="P-R06" and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id=="P-R06" and not app.busy and app.player.is_on_floor(),"P05 to P06 actual doorway and supported recess")
 app.controller.router.clear("arrived")
 await ticks(35)
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 for i:int in 50:
  await ticks(1)
  if app.player.position.x>=434:break
 app.controller.router.clear("outlook");await ticks(50)
 app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for i:int in 300:
  await ticks(1)
  if app.room.room_id=="P-R05" and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id=="P-R05" and not app.busy and app.player.is_on_floor(),"P06 to P05 actual return retains shortcut")
 app.controller.router.clear("returned");await ticks(35)
 await WorldAudioLifecycle.drain_world(app);quit(failures)
