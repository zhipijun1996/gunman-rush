extends "res://tests/world/focus_heal.gd"
## Real world persistence after deaths on authored polygon terrain, followed by held C.
func run()->void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate()
 app.save_path="user://native_playtest_regressions.json";app.settings_path="user://native_playtest_preferences.json"
 for path:String in [app.save_path,app.settings_path]:
  for suffix:String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(path+suffix)
 root.add_child(app);app.start_new();await settle();await ticks(20)
 await app.load_room("P-R34","");await settle();await ticks(4)
 check(app.room.room_id=="P-R34","actual old market loaded with file-backed save")
 var patrol:EnemyActor=app.room.enemies["P-R34:r8:entry_cache_patrol"]
 patrol.set_physics_process(false);patrol.motor.position=Vector2(200,384)
 var flyer:EnemyActor=app.room.enemies["P-R34:r8:east_air_sentry"]
 flyer.set_physics_process(false)
 var flyer_start:=flyer.motor.position
 await ticks(60)
 check(patrol.motor.supported_at(patrol.motor.position) and absf(patrol.motor.position.y-432)<1,"unsupported walking enemy falls onto actual polygon floor "+str(patrol.motor.position)+" support="+str(patrol.motor.supported_at(patrol.motor.position)))
 check(flyer.motor.position==flyer_start,"aerial sentry does not receive ground gravity")
 patrol.set_physics_process(true);flyer.set_physics_process(true)
 for id:String in app.room.enemies:
  var enemy:EnemyActor=app.room.enemies[id]
  check(enemy.damageable.receive_damage({"event_id":StringName(id+":fixture"),"amount":99,"source_faction":&"player","source_actor_id":app.player.get_instance_id(),"target_actor_id":enemy.damageable.actor_id,"target_epoch":enemy.damageable.damage_epoch}),"real accepted kill "+id)
 await ticks(150)
 var snapshot:=app._snapshot()
 var polygon_corpses:=0
 for row:Dictionary in snapshot.enemies.values():
  if row.has("corpse") and row.corpse.support.kind=="ground_polygon":polygon_corpses+=1
 check(polygon_corpses>=3,"market bodies really settled on three polygon supports")
 check(app.state.valid(snapshot),"whole world accepts actual polygon-supported corpse records")
 app._restore_hp(1);app.controller.combat_energy.grant("native_heal_fixture",100)
 app.player.reset_at(Vector2(1100,1038));await ticks(5)
 key(true);await ticks(64);key(false);await ticks(2)
 check(app.controller.actor_resources.health.current==2 and app.controller.combat_energy.current==65,"C actually heals after kills, spending exactly 35 resonance")
 check(app.focus_heal.flash>0,"successful durable heal releases real presentation")
 var loaded:=app.state.storage.load_profile()
 check(loaded.accepted and loaded.payload.hp==2 and loaded.payload.combat_energy==65,"file envelope and checksum reload healed resources")
 var bad:Dictionary=snapshot.enemies["P-R34:r8:east_hopper"].corpse.duplicate(true)
 bad.support.id=""
 check(not EnemyFeedback01Remains.valid_presentation_snapshot(bad),"blank polygon identity remains invalid")
 bad.support={"kind":"unknown","id":"x"}
 check(not EnemyFeedback01Remains.valid_presentation_snapshot(bad),"unknown support kinds remain invalid")
 await app.load_room("P-R31","");await settle()
 check(app.room.room_id=="P-R31" and app.state.value.room=="P-R31","dead polygon actors cannot block the next door commit")
 await app.load_room("P-R34","");await settle();await ticks(10)
 var hopper:EnemyActor=app.room.enemies["P-R34:r8:east_hopper"]
 var remains:=EnemyPresentationBinding.remains(hopper.motor.get_node("Presentation"))
 check(hopper.health.terminal and remains.restored and remains.restore_support_verified,"return restores dead body on its actual polygon, without revival")
 check(app.controller.actor_resources.health.current==2 and app.controller.combat_energy.current==65,"room round trip retains healed resources")
 app.player.reset_at(Vector2(2816,366));await ticks(4)
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 for frame:int in 180:
  await ticks(1)
  if not app.busy and app.room.room_id=="P-R35":break
 check(app.room.room_id=="P-R35" and not app.busy,"market right exit really crosses after corpse restore")
 app.controller.router.clear("door checked")
 await ticks(60)
 check(app.player.is_on_floor() and app.room.room_id=="P-R35","east exit arrival has real support after the drop")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
 print("NATIVE PLAYTEST REGRESSIONS: %d assertions, %d failures"%[checks,failures]);quit(failures)
