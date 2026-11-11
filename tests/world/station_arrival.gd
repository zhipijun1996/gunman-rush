extends "res://tests/world/focus_heal.gd"
## Formal app with the authorized clockheart interior; real carrier motion with declared initial boarding position.
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate()
 app.save_path="user://station_arrival_test.json";app.settings_path="user://station_arrival_settings.json"
 for path:String in [app.save_path,app.settings_path]:
  for suffix:String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(path+suffix)
 root.add_child(app);app.start_new();await settle()
 app.load_room("P-R01","INTRO-P24-P01:P-R01");await settle();await ticks(5)
 check(not app.content.room("Z-R01").is_empty() and app.story._has_east_route(),"arrival has a playable east route to the clockheart")
 check(not app.state.value.receipts.has("station_briefing"),"room entry does not auto-commit unplayed arrival")
 # Emulate the previous release's premature receipt, not a completed new lesson.
 app._commit_action("station_briefing");await ticks(4)
 var lift:=app.room.get_node("StationLift") as WorldMovingPlatform
 app.player.reset_at(lift.position-Vector2(0,28));await ticks(3)
 for i:int in 720:
  await ticks(1)
  if app.story.active:break
 check(app.story.active and app.player.position.y<=1267 and app.player.get_platform_velocity().length_squared()<1,"stopped first lift automatically starts arrival, including legacy receipt")
 check(not app.state.has("station_rest_taught"),"lesson does not commit before viewing or skipping")
 var lines:=app.story._lines()
 check(lines.size()>3 and "充电站" in str(lines[1]) and "世界钟心" in str(lines),"formal arrival teaches resting and directs the player to the clockheart")
 var cycle:int=app.state.value.cycle
 app.story._show_lines();app.story.advance();await ticks(40)
 check(app.story.focus.x==480,"charging station lesson pans toward actual west station")
 app.story.finish();await ticks(8)
 check(not app.paused and app.state.has("station_rest_taught") and app.state.value.cycle==cycle,"skip persists lesson and returns control without resting")
 await ticks(60)
 var half:=app.camera.get_viewport_rect().size/(2*app.camera.zoom)
 var street_fraction:float=(1280-app.camera.get_screen_center_position().y+half.y)/(2*half.y)
 check(street_fraction>0.73 and street_fraction<0.9,"street composition favors town landmarks while keeping feet safely visible")
 var saved:=app.state.value.duplicate(true)
 app.load_room("P-R03","");await settle()
 app.load_room("P-R01","INTRO-P24-P01:P-R01");await settle()
 app.player.reset_at(Vector2(640,1262));await ticks(15)
 check(not app.story.active and app.state.has("station_rest_taught"),"return does not replay completed lesson")
 check(app.state.valid(saved),"lesson completion is valid durable state")
 # The town is one walkable street, not a lower corridor under floating shops.
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 for frame:int in 360:
  await ticks(1)
  if app.player.position.x>=1760:break
 app.controller.router.clear("east street")
 check(app.player.position.x>=1760 and app.player.is_on_floor() and absf(app.player.position.y-1262)<3,"walk to east street without jumping a central gap")
 app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for frame:int in 420:
  await ticks(1)
  if app.player.position.x<=544:break
 app.controller.router.clear("arrival grate");await ticks(3)
 check(app.player.is_on_floor() and absf(app.player.position.y-1262)<3,"arrival grate completes the street and accepts return")
 for frame:int in 500:
  if (app.room.get_node("StationLift") as WorldMovingPlatform).position.y>1500:break
  await ticks(1)
 var adapter:=app.player.get_node("KeyboardMouseAdapter")
 for code:Key in [KEY_S,KEY_SPACE]:
  var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;adapter._unhandled_input(event)
 await ticks(8)
 check(app.player.position.y>1276 and app.player.velocity.y>0,"Down+Jump enters the retained arrival shaft")
 for code:Key in [KEY_SPACE,KEY_S]:
  var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=false;adapter._unhandled_input(event)
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("STATION ARRIVAL: ",checks," assertions, ",failures," failures");quit(failures)
