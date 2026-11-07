class_name WindkeeperWorldBinding
extends RefCounted
## This Boss owns its concrete arena/contact adapter; ordinary rooms know only the result.
func install(host: Node2D,identity: StringName,position: Vector2,bounds: Rect2,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime) -> Dictionary:
	var boss := BossFactory.create(identity)
	boss.position = position
	host.add_child(boss)
	var encounter := boss.get_node("Encounter") as BossEncounter
	policy.bind_damageable(&"P_WINDKEEPER",boss.get_node("Damageable"),encounter.health)
	encounter.configure_arena(bounds.position.x,bounds.end.x,controller.motor)
	var segment := SegmentRespawn.new()
	segment.configure(controller,lifetime)
	(encounter as WindkeeperEncounter).bind_stage_geometry(host.get_node("Arena") as PlatformingModule,controller,policy,lifetime,segment)
	encounter.projectile_created.connect(func(projectile: BossProjectile) -> void:
		var ticket := lifetime.token()
		projectile.hit.connect(func(body: Node,event_id: StringName,amount: float) -> void:
			if body != controller.motor or not lifetime.accepts(ticket): return
			var request := DamageRequest.new()
			request.token = ticket
			request.actor_epoch = ticket.actor_epoch
			request.health_epoch = controller.actor_resources.health.epoch
			request.target_id = &"player"
			request.source_id = &"boss_projectile"
			request.event_id = event_id
			request.amount = amount
			policy.submit(request)))
	var boss_contact := DemoContactEmitter.attach(boss,policy,controller,&"boss_body",DamageRequest.Kind.MONSTER,Vector2(72,62))
	boss_contact.contact_rect_provider = (encounter as WindkeeperEncounter).body_contact_rect
	boss_contact.contact_test_provider = (encounter as WindkeeperPressureEncounter).body_contact_sweep
	boss_contact.enabled = false
	return {"boss":boss,"encounter":encounter,"contact":boss_contact}
