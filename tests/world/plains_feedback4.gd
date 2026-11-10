extends "res://tests/world/plains35_fixture.gd"
func run() -> void:
 root.size=Vector2i(1280,720)
 app=load("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_feedback4.json";root.add_child(app);app.workbench.enabled=true
 await load_room("P-R25")
 for actor:EnemyActor in app.room.enemies.values():actor.set_physics_process(false)
 await hop(Vector2(1488,718),Vector2(1488,430),Vector2.DOWN,"P25 full jump + down recoil reward",20)
 app._interact();await ticks(3);check(app.state.has("found_TG01"),"TG01 actual new host receipt")
 await fixture(Vector2(1488,718));app.controller.router.set_jump_held(&"keyboard_mouse",true)
 var top:=718.0
 for i:int in 70:await ticks(1);top=minf(top,app.player.position.y)
 check(top>448,"P25 normal jump cannot reach high reward "+str(top));app.controller.router.clear("negative control")
 await load_room("P-R13")
 for actor:EnemyActor in app.room.enemies.values():actor.set_physics_process(false)
 var latch:=app.room.get_node("RewardReturn") as WorldReturnLatch
 await fixture(latch.position)
 check(not latch.available(app.player.position,"main"),"HP01 unclaimed cannot open return")
 await fixture(Vector2(384,2222));app._commit_action("pickup_HP01")
 await fixture(latch.position);app._commit_action(latch.action_id);await ticks(3)
 check(app.state.has(latch.action_id),"HP01 claimed + physical lever opens return")
 await fixture(Vector2(5672,1838))
 app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for frame:int in 80:
  await ticks(1)
  if app.player.position.y>2000:break
 app.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
 for frame:int in 100:
  await ticks(1)
  if app.player.position.x<5340:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor():break
 check(app.player.is_on_floor() and absf(app.player.position.y-2062)<5,"P13 descending recoil under canopy "+str(app.player.position))
 app.controller.router.clear("drop complete")
 await hop(Vector2(5024,2062),Vector2(4720,1902),Vector2(.8,.6),"P13 vertical rise between wall spikes",16)
 await hop(Vector2(4384,1902),Vector2(4080,2062),Vector2.RIGHT,"P13 downward turn",8)
 await hop(Vector2(3744,2062),Vector2(3440,2030),Vector2.RIGHT,"P13 wider fourth gap",16)
 await fixture(Vector2(2980,2030));app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for frame:int in 90:
  await ticks(1)
  if app.player.position.y>2172:break
 app.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
 for frame:int in 80:
  await ticks(1)
  if app.player.position.x<2640:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor():break
 check(app.player.position.x<2670 and absf(app.player.position.y-2222)<5,"P13 final narrow recoil exit "+str(app.player.position))
 app.controller.router.clear("final gap")
 await fixture(Vector2(944,2788));check(not app.player.is_on_floor(),"P13 old platform21 no longer caps lift shaft")
 await load_room("P-R26")
 check(app.room.enemies.size()==2,"P26 moving/stationary enemy roles")
 check(app.room.gear_obstacles[0].travel[0]>0 and app.room.gear_obstacles[0].travel[1]>0,"P26 diagonal sweep")
 await fixture(Vector2(2240,1518));app._commit_action("open_P26_hidden_chest");await ticks(2)
 check(app.state.value.receipts.has("open_P26_hidden_chest"),"P26 chest committed once")
 await load_room("P-R24")
 await fixture(Vector2(1984,1102));await ticks(4)
 check(app.music.requested_track==&"plains_boss","P24 wave encounter requests boss music")
 for i:int in 3:
  await ticks(65)
  for actor:EnemyActor in app.room.enemies.values():
   check(actor.definition.health_definition.max_health in [9.0,14.0],"P24 weak/medium health")
   actor.health.apply_damage(ActorResourceRequest.new(StringName("wave_fixture_"+str(i)),actor.health.epoch,999,actor.health.get_instance_id()))
  await ticks(6)
 await ticks(10)
 check(app.room.battle_finished and app.music.requested_track==&"plains","P24 clear restores exploration track")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
 print("PLAINS FEEDBACK4: ",failures," failures");quit(failures)
