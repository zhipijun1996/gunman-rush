extends "res://tests/world/focus_heal.gd"
## Formal app without the unfinished clockheart; real carrier motion with declared initial boarding position.
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate()
 app.save_path="user://station_arrival_test.json";app.settings_path="user://station_arrival_settings.json"
 for path:String in [app.save_path,app.settings_path]:
  for suffix:String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(path+suffix)
 root.add_child(app);app.start_new();await settle()
 app.load_room("P-R01","INTRO-P24-P01:P-R01");await settle();await ticks(5)
 check(app.content.room("Z-R01").is_empty() and not app.story._has_east_route(),"arrival does not send the player toward an unavailable clockheart interior")
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
 check(lines.size()==3 and "充电站" in str(lines[1]) and "世界钟心" not in str(lines),"formal arrival teaches resting without unavailable east quest")
 var cycle:int=app.state.value.cycle
 app.story._show_lines();app.story.advance();await ticks(40)
 check(app.story.focus.x==480,"charging station lesson pans toward actual west station")
 app.story.finish();await ticks(8)
 check(not app.paused and app.state.has("station_rest_taught") and app.state.value.cycle==cycle,"skip persists lesson and returns control without resting")
 var saved:=app.state.value.duplicate(true)
 app.load_room("P-R03","");await settle()
 app.load_room("P-R01","INTRO-P24-P01:P-R01");await settle()
 app.player.reset_at(Vector2(640,1262));await ticks(15)
 check(not app.story.active and app.state.has("station_rest_taught"),"return does not replay completed lesson")
 check(app.state.valid(saved),"lesson completion is valid durable state")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("STATION ARRIVAL: ",checks," assertions, ",failures," failures");quit(failures)
