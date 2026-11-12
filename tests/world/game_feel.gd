extends "res://tests/world/approved_draft_actions.gd"
## Actual physics-space filtering and sweep limits; no new room geometry is authored.
func body(at:Vector2,size:Vector2,damageable:bool=false)->StaticBody2D:
	var node:=StaticBody2D.new();node.position=at;node.collision_layer=8 if damageable else 1
	var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=size;shape.shape=rect;node.add_child(shape)
	if damageable:
		var receiver:=Damageable.new();receiver.name="Damageable";receiver.faction=&"enemy";node.add_child(receiver)
	app.room.add_child(node);return node

func projectile(at:Vector2)->PlayerProjectile:
	var p:=PlayerProjectile.new();p.owner_controller=app.controller;p.owner_body=app.player;p.session_id=app.controller.session_id
	p.max_distance=app.player.tuning.projectile_range;p.direction=Vector2.RIGHT;p.speed=1200
	app.room.add_child(p);p.global_position=at;p.set_physics_process(false);return p

func run()->void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
	await load_room("P-R26");await ticks(3)
	app.player.process_mode=Node.PROCESS_MODE_DISABLED
	var origin:=Vector2(900,400)
	var target:=body(origin+Vector2(300,21),Vector2(20,20),true);await ticks(2)
	var assisted:=ShotAimAssist.resolve(app.controller,origin,Vector2.RIGHT,400)
	check(assisted.angle()>0 and assisted.angle()<=deg_to_rad(2),"near-cone valid target receives at most two degrees of correction")
	var wall:=body(origin+Vector2(150,0),Vector2(20,100));await ticks(2)
	check(ShotAimAssist.resolve(app.controller,origin,Vector2.RIGHT,400)==Vector2.RIGHT,"wall blocks attraction")
	wall.free();await ticks(2)
	target.position=origin+Vector2(410,10);await ticks(2)
	check(ShotAimAssist.resolve(app.controller,origin,Vector2.RIGHT,400)==Vector2.RIGHT,"out-of-range target never attracts")
	target.position=origin+Vector2(200,50);await ticks(2)
	check(ShotAimAssist.resolve(app.controller,origin,Vector2.RIGHT,400)==Vector2.RIGHT,"outside small cone never attracts")
	target.position=origin+Vector2(300,21)
	var receiver:=target.get_node("Damageable") as Damageable
	receiver.aim_eligibility=func()->bool:return false
	await ticks(2)
	check(ShotAimAssist.resolve(app.controller,origin,Vector2.RIGHT,400)==Vector2.RIGHT,"inactive interaction target never attracts")
	receiver.aim_eligibility=Callable();receiver._legacy_active=false
	check(ShotAimAssist.resolve(app.controller,origin,Vector2.RIGHT,400)==Vector2.RIGHT,"dead target never attracts")
	target.free();await ticks(2)
	var p:=projectile(origin);p.advance(.5)
	check(p.spent and p.global_position.is_equal_approx(origin+Vector2(400,0)),"large tick stops at exact four-hundred-unit endpoint")
	await ticks(2)
	p=projectile(origin)
	for i:int in 40:
		if p.spent:break
		p.advance(1.0/90)
	check(p.spent and p.global_position.is_equal_approx(origin+Vector2(400,0)),"small ticks reach same endpoint")
	await ticks(2)
	var bells:=0
	for latch:WorldShotLatch in app.room.mechanisms.values():
		for child:Node in latch.get_children():
			if child is Sprite2D and child.get_meta("underworld_access_bell",false):
				bells+=1;check(child.texture==UnderworldTerrain.mechanism_bell_texture(),"remote bell shares main bell source")
	check(bells==4,"both carriers expose all four unified remote bells")
	app.player.process_mode=Node.PROCESS_MODE_INHERIT
	await app.review.begin("P-R25","","base");await ticks(4)
	app.player.process_mode=Node.PROCESS_MODE_DISABLED
	for enemy:EnemyActor in app.room.enemies.values():enemy.process_mode=Node.PROCESS_MODE_DISABLED
	for id:String in ["P-R25:orchard_charger","P-R25:crown_diver"]:
		var enemy:EnemyActor=app.room.enemies[id]
		var behavior:=enemy.attack_behavior as EnemyAttackBehavior
		enemy.motor.position=Vector2(800,600);behavior.home=Vector2(1250,600);behavior.protected_points.clear();behavior.state=&"recovery"
		app.player.position=Vector2(1250,600);await ticks(2)
		check(not behavior._can_engage(),id+" rejects far player even at old home")
		app.player.position=Vector2(1000,600);behavior.home=Vector2(1900,600);await ticks(2)
		check(behavior._can_engage(),id+" detects near player from current body")
		wall=body(Vector2(900,600),Vector2(24,160));await ticks(2)
		check(not behavior._can_engage(),id+" cannot acquire through wall")
		wall.free();await ticks(2)
	app.player.process_mode=Node.PROCESS_MODE_INHERIT
	await WorldAudioLifecycle.drain_world(app);quit(failures)
