extends RefCounted
# Cell binding only: the existing EnemyActor, motor, brain, health and attack own all behavior.
const DIVER=preload("res://resources/enemies/plains_diver.tres")
static func ordinary(data: Dictionary) -> Dictionary:
	var result:=data.duplicate(true)
	result.enemies=[]
	for spec: Dictionary in data.get("enemies",[]):
		if str(spec.get("definition",""))!="plains_diver":result.enemies.append(spec)
	return result
static func install(data: Dictionary, host: Node2D, player: PlayerController, scope, cells) -> void:
	for spec: Dictionary in data.get("enemies",[]):
		if str(spec.get("definition",""))!="plains_diver":continue
		var body: EnemyMotor=load("res://scenes/enemies/patrol_drone.tscn").instantiate()
		var actor: EnemyActor=body.get_node("Actor")
		actor.definition=DIVER
		body.position=Vector2(spec.position[0],spec.position[1]);host.add_child(body)
		var id:=StringName("module/"+str(host.instance_key).uri_encode()+"/"+str(spec.id).uri_encode());scope.policy.bind_damageable(id,actor.damageable,actor.health)
		actor.bind_encounter(player,scope.policy,scope.lifetime,id,[])
		if actor.attack_behavior!=null:
			if spec.has("initial_idle_cooldown"):actor.attack_behavior.cooldown=float(spec.initial_idle_cooldown)
			actor.attack_behavior.state_changed.connect(cells._enemy_state.bind(str(id)))
		actor.damageable.damaged.connect(cells._enemy_hit.bind(str(id),player))
		var contact:=DemoContactEmitter.new();contact.policy=scope.policy;contact.controller=player;contact.source_id=id;contact.half_size=DIVER.collision_size/2;body.add_child(contact)
		actor.defeated.connect(cells._enemy_defeated.bind(contact,str(id)))
		cells.enemies.append(actor)
