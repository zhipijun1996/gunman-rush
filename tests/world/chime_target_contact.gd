extends "res://tests/world/approved_final_rooms.gd"
## Real target projectiles, contact damage and movement. Declared local starting poses.
func run()->void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await live_room("P-R10",["P-R10:r9:teach_down"])
 var target:EnemyActor=app.room.enemies["P-R10:r9:teach_down"]
 var home:=target.motor.position
 var gold:int=app.services.ledger().gold
 var energy:=app.controller.combat_energy.current
 await fixture(Vector2(896,2030))
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(18)
 app.controller.router.set_source_axis(&"keyboard_mouse",0)
 await air_hit("P-R10:r9:teach_down")
 check(app.controller.combat_energy.current==energy,"practice hit grants air actions without renewable combat currency")
 await fixture(target.motor.position-Vector2(60,0)) # Isolate a second real hit from a clear local line of fire.
 app.controller.router.request_action(&"shoot_release",(target.motor.position-app.player.position-Vector2(0,-6)).normalized())
 await ticks(18)
 check(target.health.terminal,"two real 5-damage shots defeat the 9HP target")
 app.toggle_pause();await ticks(140)
 check(target.health.terminal,"pause freezes re-form timer")
 app.toggle_pause();await ticks(140)
 check(target.health.current==9 and target.damageable.active and target.motor.position.distance_to(home)<10,"target re-forms at its authored perch with a live hitbox")
 check(app.services.ledger().gold==gold,"target defeat never farms money")
 check(not app.room.snapshot().has("P-R10:r9:teach_down"),"temporary target death is absent from room save state")
 var restored:=app.room.spawn_enemy({"id":"target_old_save_fixture","behavior":"chime_target","point":[1100,1800]},app.controller,app.policy,app.lifetime,{"position":[200,400],"health":0},app.entry_anchor)
 check(restored.health.current==9 and restored.motor.position==Vector2(1100,1800),"old combat-flyer saves cannot relocate or disable practice targets")
 # Contact at the hovering body is safe, including after re-form.
 await fixture(target.motor.position)
 var hp:=app.controller.actor_resources.health.current
 await ticks(12)
 check(app.controller.actor_resources.health.current==hp,"passive target has no contact damage")
 check(target.attack_behavior._projectiles.is_empty(),"passive behavior never emits projectiles")
 # A real ordinary enemy retains damage but cannot be displaced by walking.
 await app.review.begin("P-R12","","base");await ticks(5)
 var guard:EnemyActor=app.room.enemies["P-R12:r8:west_patrol"]
 guard.set_physics_process(false) # Freeze AI to measure body pushing alone; contact stays live.
 var stand:=guard.motor.position
 await fixture(stand-Vector2(42,0))
 hp=app.controller.actor_resources.health.current
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 await ticks(24)
 check(app.controller.actor_resources.health.current<hp,"ordinary enemy contact still hurts")
 app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(18)
 check(app.player.position.x>stand.x+16,"hurt protection lets the player cross through the enemy")
 check(guard.motor.position.distance_to(stand)<.1,"player movement never pushes the enemy")
 check(app.player.is_on_floor(),"enemy pass-through keeps solid floor collision")
 app.controller.router.clear("contact complete")
 var older:=app.room.spawn_enemy({"id":"old_ground_fixture","behavior":"patrol","max_health":9,"point":[200,1326]},app.controller,app.policy,app.lifetime,{"position":[200,1326],"health":9},app.entry_anchor)
 check(is_equal_approx(older.motor.position.y+older.definition.collision_size.y*.5,1344),"old ground saves register the real sole on the nearby solid surface")
 await WorldAudioLifecycle.drain_world(app)
 print("CHIME TARGET / CONTACT: ",failures," failures");quit(failures)
