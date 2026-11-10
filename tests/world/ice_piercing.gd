extends "res://tests/world/approved_exploration_rooms.gd"
## Actual swept projectile; stationary durable enemies isolate piercing from AI dodges.
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R10")
 await fixture(Vector2(896,2030))
 var targets:Array[EnemyActor]=[]
 for id:String in ["P-R10:r9:teach_down","P-R10:r9:teach_diagonal","P-R10:r9:combo_left","P-R10:r9:combo_right"]:
  var enemy:EnemyActor=app.room.enemies[id]
  enemy.motor.position=Vector2(1000+targets.size()*80,2024)
  var hd:=enemy.definition.health_definition.duplicate(true) as HealthDefinition;hd.max_health=50;hd.initial_current=50
  enemy.health.configure(hd);enemy.damageable.bind_health(enemy.health);targets.append(enemy)
 var wall:=StaticBody2D.new();wall.position=Vector2(1200,1992);wall.collision_layer=1
 var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(24,128);shape.shape=rect;wall.add_child(shape);app.room.add_child(wall)
 app.controller.shoot_ability.equip(preload("res://resources/weapons/pulse_ice.tres"));app.controller.combat_energy.current=100
 await ticks(3)
 app.controller.router.request_action(&"weapon_skill",Vector2.RIGHT);await ticks(10)
 check(app.controller.shoot_ability.behavior().phase==&"charge" and app.controller.shoot_ability._projectiles.is_empty(),"accepted active skill has a real anticipation before release")
 await ticks(65)
 for i:int in 3:check(targets[i].health.current==35,"pierced target "+str(i)+" receives full 15 exactly once")
 check(targets[3].health.current==50,"solid wall blocks ice and protects target beyond")
 check(app.controller.shoot_ability._projectiles.filter(func(p:Variant)->bool:return is_instance_valid(p) and not p.spent).is_empty(),"wall retires penetrating projectile")
 await ticks(90)
 app.controller.router.request_action(&"weapon_skill",Vector2.RIGHT);await ticks(8)
 app.controller.router.clear("cancelled ice anticipation");await ticks(45)
 check(app.controller.shoot_ability.behavior().phase==&"idle" and targets[0].health.current==35,"cancel during charge leaves no delayed shot")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("ICE PIERCING: ",failures," failures");quit(failures)
