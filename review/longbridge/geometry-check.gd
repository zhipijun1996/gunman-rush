extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 for start:Vector2 in [Vector2(736,1006),Vector2(1440,942)]:
  await load_room("P-R32")
  var bank:=Vector2(672,1006) if start.x<1000 else Vector2(1184,942)
  await fixture(bank);await ticks(20)
  app.controller.router.set_source_axis(&"keyboard_mouse",1)
  for j:int in 80:
   await ticks(1)
   if app.player.position.x>=start.x-2:break
  app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(6)
  var hp:=app.controller.actor_resources.health.current
  app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true)
  for i:int in 120:
   await ticks(1)
   if app.controller.actor_resources.health.current<hp:break
  app.controller.router.clear("ordinary jump probe")
  check(app.controller.actor_resources.health.current<hp,"ordinary jump cannot replace recoil from "+str(start))
  await ticks(80)
  check(app.player.is_on_floor() and app.player.position.distance_to(bank)<96,"thorn failure returns to reached safe bank "+str(app.player.position))
 await load_room("P-R32")
 var authored:=load("res://game/world/regions/P/rooms/P-R32.tscn").instantiate() as FixedWorldRoom
 var overlaps:=0
 for i:int in authored.platforms.size():
  if i in app.room.one_way_indices:continue
  for j:int in range(i+1,authored.platforms.size()):
   if j in app.room.one_way_indices:continue
   if authored.platforms[i].intersection(authored.platforms[j]).has_area():overlaps+=1
 check(overlaps==0,"authored solid bridge bodies do not overlap")
 authored.free()
 await WorldAudioLifecycle.drain_world(app);quit(failures)
