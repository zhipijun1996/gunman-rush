class_name ProjectileTurnOrder
extends Node
## A station can start moving part-way through a physics tick. Dispatch potential
## button shots first by contact time, then all other projectiles sample its
## resulting angle timeline at their own contact time.
var domain: Node

static func install(host: Node) -> void:
	if host==null or host.has_meta(&"projectile_turn_order"): return
	var clock := ProjectileTurnOrder.new()
	clock.domain = host
	clock.process_physics_priority = -160
	host.set_meta(&"projectile_turn_order",true)
	host.add_child.call_deferred(clock)

func _physics_process(delta: float) -> void:
	var pending: Array[PlayerProjectile] = []
	for node: Node in get_tree().get_nodes_in_group("ordinary_flight_player"):
		var round := node as PlayerProjectile
		if round==null or round.spent or not round.is_physics_processing() or not round.can_process(): continue
		if ProjectileField.domain_for(round)==domain: pending.append(round)
	var fields := ProjectileField.fields_for(domain)
	while not pending.is_empty():
		var closest := INF
		var first: PlayerProjectile
		for round: PlayerProjectile in pending:
			var step := minf(delta,maxf(0,round.lifetime-round._age))
			var reach := round.speed*step+round.radius+round.launch_motion.length()
			var near_button := false
			for field: ProjectileField in fields:
				if field is ProjectileMirror and field.orientation_mode=="indexed" and round.global_position.distance_to(field.to_global(field.control_offset))<=reach+field.control_radius:
					near_button=true
					break
			if not near_button or step<=0: continue
			var when := round.flight.button_time(round,step)
			if when<closest or (first!=null and when==closest and round.get_instance_id()<first.get_instance_id()):
				closest = when
				first = round
		if first==null: return
		pending.erase(first)
		first.ordered_frame = Engine.get_physics_frames()
		first.advance(delta)
