extends "res://tests/world/plains35_fixture.gd"
## Local legal-state door approaches, real movement/interaction and grounded arrivals.
## Progression flags are a declared isolation fixture, not proof of earning them.
var results:Array=[]
func run()->void:
 DirAccess.make_dir_recursive_absolute("res://build/plains-door-review")
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R01","","hwdq",true),"isolated formal review")
 var candidate:=app.state.value.duplicate(true)
 for row:Dictionary in app.content.data.rooms.values():
  for d:Dictionary in row.doors:
   for group:Array in d.requires:
    for flag:String in group:
     if flag not in candidate.flags:candidate.flags.append(flag)
 for flag:String in ["intro_complete","intro_gun","station_briefed","station_rest_taught","clockheart_briefed","clock_P","boss_P","H","D","W","Q"]:
  if flag not in candidate.flags:candidate.flags.append(flag)
 check(app.state.commit(candidate,app.state.revision),"explicit open-door state fixture")
 var chosen:=OS.get_cmdline_user_args()
 for rid:String in app.content.data.rooms:
  for door:Dictionary in app.content.room(rid).doors:
   if not door.target_implemented or not (rid.begins_with("P-") or str(door.target_room).begins_with("P-")):continue
   if not chosen.is_empty() and door.edge_id not in chosen:continue
   await passage(rid,door)
 FileAccess.open("res://build/plains-door-review/traversals.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
 await WorldAudioLifecycle.drain_world(app)
 print("PAIRED THRESHOLDS: ",results.size()," directions, ",failures," failures")
 quit(failures)
func passage(source:String,door:Dictionary)->void:
 await app.load_room(source,"");await ticks(4)
 if is_instance_valid(app.story) and app.story.active:app.story.finish();await ticks(2)
 app.room.refresh_doors(app.state,app.content)
 for actor:EnemyActor in app.room.enemies.values():
  if is_instance_valid(actor):actor.get_parent().set_physics_process(false);actor.set_physics_process(false)
 var start:=FixedWorldProvider.point(door.landing_contract.safe_standing_position_world_units)
 var portal:=FixedWorldProvider.point(door.position_candidate.local_world_units)
 await fixture(start)
 var axis:=signf(portal.x-start.x) if door.direction=="down" else (-1.0 if door.direction=="left" else (1.0 if door.direction=="right" else 0.0))
 if door.get("front_door",false):
  await fixture(portal-Vector2(0,18));app._interact()
 else:
  app.controller.router.set_source_axis(&"keyboard_mouse",axis)
  if door.direction=="up":app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for frame:int in 300:
  await ticks(1)
  if door.direction=="down" and app.room.room_id==source and absf(app.player.position.x-portal.x)<8:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if door.direction=="down" and app.room.room_id==source and app.player.is_on_floor() and absf(app.player.position.x-portal.x)<16 and frame%20==0:
   app.controller.router.set_look_axis(&"keyboard_mouse",1);app.controller.router.request_action(&"jump")
  if app.room.room_id==str(door.target_room) and not app.busy and app.player.is_on_floor():break
 var ok:=app.room.room_id==str(door.target_room) and not app.busy and app.player.is_on_floor()
 var row:Dictionary={"door":door.id,"target":door.target_room,"passed":ok,"room":app.room.room_id,"position":[app.player.position.x,app.player.position.y]};results.append(row)
 check(ok,str(door.id)+" -> "+str(door.target_room)+" "+str(app.player.position))
 app.controller.router.clear("paired threshold fixture finished")
