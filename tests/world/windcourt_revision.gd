extends "res://tests/world/approved_hub_actions.gd"
## Formal phase transition, persistent floor, real thorn damage/recovery and cleanup.
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R14")
 var arena:=app.room.get_node("Arena") as PlatformingModule
 var floor_body:=arena.get_node("Platform0") as StaticBody2D
 var geometry:=arena.definition.platforms.duplicate()
 var centres:Array[float]=[]
 for index:int in arena.definition.one_way_platform_indices:centres.append(arena.definition.platforms[index].get_center().x)
 check(centres==[240.0,560.0,880.0],"three equal-width evenly distributed battle decks")
 await fixture(app.room.battle_entry_anchor);await ticks(8)
 check(app.room.battle_started,"real approach triggers Boss")
 var e:=app.room.encounter as WindkeeperPressureEncounter
 var hazard:WindkeeperArena
 for child:Node in e.get_children():
  if child is WindkeeperArena:hazard=child
 check(hazard!=null,"formal Boss binds floor hazard")
 app.room.boss_contact.enabled=false # Isolate environmental damage; live phase movement stays enabled.
 await fixture(arena.to_global(Vector2(240,452)))
 await ticks(10)
 var zoom:=app.camera.zoom
 var hp:=e.health
 hp.apply_damage(ActorResourceRequest.new(&"phase_threshold_fixture",hp.epoch,hp.current-hp.capacity*.25,hp.get_instance_id()))
 var warned:=false
 for i:int in 650:
  await ticks(1)
  if hazard.thorns_active and not hazard._contact.enabled:warned=true
  if hazard._contact.enabled:break
 check(e.stage_phase==3 and e.thorns_ready(),"Boss actually mounts a verified deck before phase-three release")
 check(warned and hazard._contact.enabled and hazard._growth==1.0,"visible warning and growth precede thorn damage")
 check(hazard._band.position.x==hazard._floor.position.x and hazard._band.end.x==hazard._floor.end.x,"thorns cover both sealed floor edges without camping gaps")
 check(floor_body.collision_layer==1 and arena.definition.platforms==geometry,"phase three preserves every platform and solid floor")
 check(app.camera.zoom==zoom,"phase change preserves formal camera scale")
 e.set_physics_process(false);e.cancel_pending_attacks()
 var age:=hazard._age
 paused=true;await ticks(5);check(hazard._age==age,"pause freezes thorn growth/lifetime");paused=false
 # A real down+jump leaves the reached perch and contacts the actual thorn strip.
 await fixture(arena.to_global(Vector2(240,452)));await ticks(8)
 var player_hp:=app.controller.actor_resources.health.current
 var epoch:=app.lifetime.actor_epoch
 well_key(KEY_S,true);well_key(KEY_SPACE,true);await ticks(8);well_key(KEY_SPACE,false);well_key(KEY_S,false)
 for i:int in 100:
  await ticks(1)
  if app.lifetime.actor_epoch>epoch:break
 check(app.controller.actor_resources.health.current==player_hp-1,"thorns submit one real environment hit")
 check(app.lifetime.actor_epoch>epoch and app.player.position.distance_to(arena.to_global(Vector2(240,452)))<6,"thorn failure returns to the actually reached safe deck")
 # The old right margin was safe. A real actor is now hurt and restored
 # from the last 12 units next to either wall, not just a middle-strip probe.
 for side:int in [-1,1]:
  await ticks(100)
  var before_hp:=app.controller.actor_resources.health.current
  var before_epoch:=app.lifetime.actor_epoch
  var edge_x:=hazard._floor.position.x+12 if side<0 else hazard._floor.end.x-12
  app.player.reset_at(Vector2(edge_x,hazard._floor.position.y-18))
  for i:int in 30:
   await ticks(1)
   if app.lifetime.actor_epoch>before_epoch:break
  check(app.lifetime.actor_epoch>before_epoch and app.controller.actor_resources.health.current==before_hp-1,"real thorn damage and safe-deck return at sealed edge "+str(side))
 hp.apply_damage(ActorResourceRequest.new(&"terminal_fixture",hp.epoch,hp.current+1,hp.get_instance_id()))
 await ticks(2)
 check(not hazard._contact.enabled,"accepted death immediately stops thorn damage")
 await ticks(35)
 check(not hazard._art.visible and not hazard.thorns_active and floor_body.collision_layer==1,"victory retracts thorns and keeps postfight ground traversable")
 await WorldAudioLifecycle.drain_world(app)
 print("WINDCOURT REVISION: ",failures," failures");quit(failures)
