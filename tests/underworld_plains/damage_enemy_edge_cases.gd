extends RefCounted
## Actual ground/aerial definitions, sole EnemyMotor and real player projectiles.
## Fixture-only initial actors/platform; no enemy pause or direct damage calls.
func run(tree: SceneTree, check: Callable) -> Array[Dictionary]:
	var all_rows: Array[Dictionary]=[]
	for specification: Dictionary in [
		{"name":"right_ground_edge","edge":600.0,"enemy_x":585.0,"player_x":430.0,"side":1.0,"aerial":false,"width":600.0},
		{"name":"left_ground_edge","edge":0.0,"enemy_x":15.0,"player_x":170.0,"side":-1.0,"aerial":false,"width":600.0},
		{"name":"wide_ground","edge":1000.0,"enemy_x":585.0,"player_x":430.0,"side":1.0,"aerial":false,"width":1000.0},
		{"name":"right_aerial_edge","edge":600.0,"enemy_x":585.0,"player_x":430.0,"side":1.0,"aerial":true,"width":600.0}]:
		var world := Node2D.new();world.position=Vector2(9000,0);tree.root.add_child(world)
		var floor_body := StaticBody2D.new();floor_body.position=Vector2(float(specification.width)*.5,400)
		var collision := CollisionShape2D.new();var shape := RectangleShape2D.new();shape.size=Vector2(float(specification.width),24);collision.shape=shape;floor_body.add_child(collision);world.add_child(floor_body)
		var player: PlayerMotor=load("res://game/player/player.tscn").instantiate();player.position=Vector2(float(specification.player_x),370);world.add_child(player)
		player.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED
		var controller := player.get_node("Controller") as PlayerController
		var enemy: EnemyMotor=load("res://game/enemies/scenes/patrol_drone.tscn").instantiate()
		enemy.position=Vector2(float(specification.enemy_x),372)
		var actor := enemy.get_node("Actor") as EnemyActor
		actor.definition=load("res://resources/enemies/plains_diver.tres" if bool(specification.aerial) else "res://resources/enemies/plains_sentry.tres")
		world.add_child(enemy)
		var policy := FrameDamagePolicy.new();policy.lifetime=DemoLifetime.new();world.add_child(policy)
		check.call(policy.bind_damageable(&"edge_enemy",actor.damageable,actor.health),"edge fixture actual policy receiver registers "+str(specification.name))
		actor.bind_encounter(controller,policy,policy.lifetime,&"edge_enemy",[])
		var hits: Array[Dictionary]=[]
		actor.damageable.damaged.connect(func(context: Dictionary) -> void:hits.append({"position":enemy.position,"direction":context.get("hit_direction",Vector2.ZERO),"event_id":str(context.get("event_id","")),"tick":Engine.get_physics_frames()}))
		for i: int in 4:await tree.physics_frame;await tree.process_frame
		check.call(player.is_on_floor(),"edge fixture player is genuinely grounded "+str(specification.name))
		controller.router.aim_direction=Vector2(float(specification.side),0)
		controller.router.request_action(&"shoot_release",Vector2(float(specification.side),0))
		var frames: Array[Dictionary]=[]
		for i: int in 24:
			await tree.physics_frame;await tree.process_frame
			var foot:=enemy.global_position+Vector2(0,16)
			var query:=PhysicsRayQueryParameters2D.create(foot+Vector2(0,-1),foot+Vector2(0,5),1,[enemy.get_rid()])
			var support:=enemy.get_world_2d().direct_space_state.intersect_ray(query)
			frames.append({"tick":Engine.get_physics_frames(),"position":enemy.position,"hp":actor.health.current,"knockback":enemy._knockback,"knockback_remaining":enemy._knockback_seconds,"hurt_stun":actor._damage_stun_remaining,"support":not support.is_empty() and (support.normal as Vector2).dot(Vector2.UP)>.7})
		check.call(hits.size()==1 and actor.health.current==actor.health.capacity-1,"real projectile commits one edge enemy hit "+str(specification.name))
		var end_position:=enemy.position
		var supported:=bool(frames[-1].support)
		if not bool(specification.aerial):
			check.call(supported,"ground hurt retains actual floor at platform edge "+str(specification.name))
			check.call(absf(enemy.position.y-372)<.1,"ground hurt has no permanent vertical float "+str(specification.name))
			if str(specification.name)=="wide_ground":check.call(not hits.is_empty() and enemy.position.x-float((hits[0].position as Vector2).x)>12,"wide ground still permits real horizontal hurt displacement")
		else:
			check.call(not hits.is_empty() and enemy.position.x>600,"aerial hurt is allowed beyond platform edge")
			check.call(frames.any(func(row: Dictionary) -> bool:return row.knockback_remaining>0 and (row.knockback as Vector2).x>100),"aerial hurt retains real force without floor requirement")
		all_rows.append({"case":specification,"definition":actor.definition.resource_path,"hits":hits,"final_position":end_position,"final_supported":supported,"frames":frames})
		policy.queue_free();world.queue_free();await tree.process_frame;await tree.process_frame
	return all_rows
