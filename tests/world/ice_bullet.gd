extends "res://tests/world/approved_exploration_rooms.gd"
## Attack fixture equips the actual new definition; quest installation is tested separately.
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await app.review.begin("P-R10","","base");await ticks(5)
 var enemy:EnemyActor=app.room.enemies["P-R10:r9:teach_down"]
 for other:EnemyActor in app.room.enemies.values():
  if other!=enemy:other.cancel_attacks();other.process_mode=Node.PROCESS_MODE_DISABLED;other.motor.position=Vector2(-10000,-10000)
 # Durable enemy HP has one owner; a 50HP fixture leaves a visible survivor of the 15HP hit.
 var hd:=enemy.definition.health_definition.duplicate(true) as HealthDefinition
 hd.max_health=50;hd.initial_current=50
 enemy.health.configure(hd);enemy.damageable.bind_health(enemy.health)
 await fixture(Vector2(896,2030))
 var ability:=app.controller.shoot_ability
 check(ability.equip(preload("res://resources/weapons/pulse_ice.tres")),"ice loadout valid and primary retained")
 app.controller.combat_energy.current=80
 var before:=app.controller.combat_energy.current
 app.overlay.set_enabled(true);await ticks(2)
 app.controller.router.set_aim(&"touch",(enemy.motor.position-app.player.position-Vector2(0,-6)).normalized())
 check(app.controller.router.weapon_skill_label=="冰弹","touch skill label consumes equipped definition")
 for pressed:bool in [true,false]:
  var touch:=InputEventScreenTouch.new();touch.index=12;touch.position=app.overlay.skill_center;touch.pressed=pressed
  check(app.overlay.handle_touch(touch),"actual skill touch captured")
 await ticks(18)
 check(app.controller.router.weapon_skill_cooldown_ratio>0,"touch cooldown indicator consumes live skill timer")
 check(is_equal_approx(enemy.health.current,35),"ice commits exactly three times base 5 damage "+str(enemy.health.current))
 check(enemy.damageable.chill_remaining>0 and is_equal_approx(enemy.damageable.action_time_scale(),.5),"accepted ice hit slows a surviving enemy")
 check(enemy.motor.modulate.b>enemy.motor.modulate.r,"blue frost mask on real enemy")
 check(is_equal_approx(before-app.controller.combat_energy.current,20),"skill pays once and does not self-refund resonance")
 var age:=enemy.damageable.chill_remaining
 paused=true
 for i:int in 4:await process_frame
 check(enemy.damageable.chill_remaining==age,"pause freezes chill lifetime")
 paused=false
 app.controller.router.request_action(&"weapon_skill",Vector2.RIGHT);await ticks(3)
 check(app.controller.combat_energy.current==before-20,"cooldown rejects repeated skill without charging")
 await ticks(155)
 check(enemy.damageable.chill_remaining==0 and enemy.damageable.action_time_scale()==1 and enemy.motor.modulate==Color.WHITE,"expiry restores speed and palette")
 enemy.damageable.apply_chill(2.5,.5);enemy.damageable.apply_chill(2.5,.5)
 check(enemy.damageable.action_time_scale()==.5,"repeat chill refreshes without multiplying slow")
 enemy.reset();check(enemy.damageable.chill_remaining==0 and enemy.motor.modulate==Color.WHITE,"reset clears temporary chill")
 # Actual patrol displacement, with AI and collision; only the actor clock is slowed.
 var guard:EnemyActor=app.room.enemies["P-R10:lower_guard"]
 guard.reset();guard.process_mode=Node.PROCESS_MODE_DISABLED
 guard.motor.position=Vector2(640,2414);guard.brain.direction=1
 var origin:=guard.motor.position
 for i:int in 12:guard.physics_tick(1.0/60)
 var normal:=guard.motor.position.distance_to(origin)
 guard.motor.position=origin;guard.brain.direction=1;guard.damageable.apply_chill(2.5,.5)
 for i:int in 12:guard.physics_tick(1.0/60)
 var frozen:=guard.motor.position.distance_to(origin)
 check(normal>1 and absf(frozen/normal-.5)<.02,"real patrol distance halves: "+str(normal)+" -> "+str(frozen))
 guard.damageable.clear_chill()
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("ICE BULLET: ",failures," failures");quit(failures)
