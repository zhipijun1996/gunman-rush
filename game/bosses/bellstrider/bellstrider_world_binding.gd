class_name BellstriderWorldBinding
extends RefCounted
## Fixed-world adapter to the existing complete Bellstrider encounter.
func install(host: Node2D,identity: StringName,position: Vector2,bounds: Rect2,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime) -> Dictionary:
	var boss:=BossFactory.create(identity)
	boss.position=position;host.add_child(boss)
	var encounter:=boss.get_node("Encounter") as BellstriderEncounter
	policy.bind_damageable(&"P_BELLSTRIDER",boss.get_node("Damageable"),encounter.health)
	encounter.configure_arena(bounds.position.x,bounds.end.x,controller.motor)
	encounter.projectile_created.connect(func(projectile: BossProjectile) -> void:
		var ticket:=lifetime.token()
		projectile.hit.connect(func(body: Node,event_id: StringName,amount: float) -> void:
			if body!=controller.motor or not lifetime.accepts(ticket):return
			var request:=DamageRequest.new();request.token=ticket;request.actor_epoch=ticket.actor_epoch;request.health_epoch=controller.actor_resources.health.epoch
			request.target_id=&"player";request.source_id=&"bellstrider_projectile";request.event_id=event_id;request.amount=amount;policy.submit(request)))
	var contact:=DemoContactEmitter.attach(boss,policy,controller,&"bellstrider_body",DamageRequest.Kind.MONSTER,Vector2(64,48))
	contact.contact_rect_provider=encounter.body_contact_rect
	contact.contact_test_provider=encounter.body_contact_sweep
	contact.enabled=false
	return {"boss":boss,"encounter":encounter,"contact":contact}
