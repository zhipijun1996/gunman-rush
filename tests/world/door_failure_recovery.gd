extends "res://tests/world/approved_final_connections.gd"
## Force a save refusal at the real P34 -> P35 doorway. It must never flash-loop.
class RefusingSave extends WorldRoomReview.MemorySave:
 var refuse:=true
 func commit(payload:Dictionary,revision:int)->bool:
  if refuse:return false
  return super.commit(payload,revision)
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await app.review.begin("P-R34","","base");await ticks(5)
 await fixture(Vector2(2736,366))
 var storage:=RefusingSave.new();storage.payload_validator=app.state.valid
 app.state.storage=storage
 var ticket:int=app._ticket
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 await ticks(180)
 check(app.room.room_id=="P-R34" and app._ticket==ticket+1,"one refused transition, no repeated cover or reload")
 check(not app.busy and app.controller.active,"failed crossing restores player control")
 var position:Vector2=app.player.position
 app.controller.router.set_source_axis(&"keyboard_mouse",-1);await ticks(25)
 check(app.player.position.x<position.x-60,"can walk away from refused doorway")
 storage.refuse=false
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 await ticks(140)
 check(app.room.room_id=="P-R35" and not app.busy and app.controller.active,"fresh approach retries successfully")
 # Return through the actual paired door with live room enemies.
 app.controller.router.set_source_axis(&"keyboard_mouse",-1);await ticks(140)
 check(app.room.room_id=="P-R34" and not app.busy and app.controller.active,"paired return restores control")
 await WorldAudioLifecycle.drain_world(app);quit(failures)
