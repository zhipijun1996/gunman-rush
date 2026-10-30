extends Node
## Bind original ShotLatch/EnemyActor cells; record actual commits, not tags.
var latches: Array[ShotLatch]=[]
var enemies: Array[EnemyActor]=[]
var events: Array=[]
var owner_runner
var player_damage: Array=[]
var context

func setup(data: Dictionary, host: Node2D, player: PlayerController, scope) -> void:
	context=scope
	player.shoot_ability.shot_fired.connect(func(direction: Vector2, id: int):events.append({"frame":scope.frame,"type":"shot_origin","shot_id":id,"origin":[player.motor.position.x,player.motor.position.y],"muzzle":[player.shoot_ability.last_muzzle.x,player.shoot_ability.last_muzzle.y],"direction":[direction.x,direction.y]}))
	player.shoot_ability.projectile_impacted.connect(func(point: Vector2, direction: Vector2):events.append({"frame":scope.frame,"type":"projectile_impact","point":[point.x,point.y],"direction":[direction.x,direction.y]}))
	scope.policy.batch_resolved.connect(func(results: Array[DamageResult]):
		for result: DamageResult in results:
			var row:={"frame":scope.frame,"type":"damage","target":str(result.request.target_id),"source":str(result.request.source_id),"amount":result.request.amount,"hp":result.health.current}
			events.append(row)
			if result.request.target_id==&"player":player_damage.append(row))
	for spec: Dictionary in data.get("latches",[]):
		var latch:=ShotLatch.new();latch.link_id=str(spec.id);latch.formal_presentation=true
		latch.prompt_text=str(spec.get("prompt",""));latch.open_seconds=float(spec.get("open_seconds",0))
		host.add_child(latch)
		latch.setup(player,scope.lifetime,Vector2(spec.bell[0],spec.bell[1]),Rect2(spec.gate[0],spec.gate[1],spec.gate[2],spec.gate[3]))
		if spec.has("ferry_id"):
			for moving: ModuleMovingPlatform in scope.module.moving_platforms:
				if str(moving.definition.platform_id)==str(spec.ferry_id):latch.bind_motion(moving)
		latch.opened.connect(_bell_open.bind(latch,str(spec.id)))
		latches.append(latch)
	for spec: Dictionary in data.get("enemies",[]):
		var resource_name:=str(spec.get("definition","plains_sentry"))
		if resource_name not in ["plains_sentry","plains_charger"]:
			owner_runner.setup_error="unsupported_plains_enemy";return
		var body: EnemyMotor=load("res://scenes/enemies/patrol_drone.tscn").instantiate()
		var actor: EnemyActor=body.get_node("Actor")
		actor.definition=load("res://resources/enemies/"+resource_name+".tres")
		body.position=Vector2(spec.position[0],spec.position[1]);host.add_child(body)
		var id:=StringName("module/"+str(host.instance_key).uri_encode()+"/"+str(spec.id).uri_encode());scope.policy.bind_damageable(id,actor.damageable,actor.health)
		actor.bind_encounter(player,scope.policy,scope.lifetime,id,[])
		if actor.attack_behavior!=null:
			if spec.has("initial_idle_cooldown"):actor.attack_behavior.cooldown=float(spec.initial_idle_cooldown)
			actor.attack_behavior.state_changed.connect(_enemy_state.bind(str(id)))
		actor.damageable.damaged.connect(_enemy_hit.bind(str(id),player))
		var contact:=DemoContactEmitter.new();contact.policy=scope.policy;contact.controller=player;contact.source_id=id;contact.half_size=actor.definition.collision_size/2;body.add_child(contact)
		actor.defeated.connect(_enemy_defeated.bind(contact,str(id)))
		enemies.append(actor)

func _bell_open(latch: ShotLatch, id: String) -> void:
	events.append({"frame":context.frame,"type":"bell_open","id":id,"count":latch.open_count})
func _enemy_state(state: StringName, id: String) -> void:
	events.append({"frame":context.frame,"type":"enemy_state","id":id,"state":str(state)})
func _enemy_hit(hit: Dictionary, id: String, player: PlayerController) -> void:
	events.append({"frame":context.frame,"type":"enemy_hit","id":id,"shot_id":hit.get("shot_id",-1),"fired_airborne":hit.get("fired_airborne",false),"player_airborne":not player.motor.is_on_floor(),"shots_before_refund":player.action_resources.shot_charges})
func _enemy_defeated(_actor: EnemyActor, contact: DemoContactEmitter, id: String) -> void:
	contact.enabled=false;events.append({"frame":context.frame,"type":"enemy_defeated","id":id})

func snapshot() -> Dictionary:
	var bells: Array=[];var actors: Array=[]
	for latch: ShotLatch in latches:bells.append({"id":latch.link_id,"open":latch.is_open,"open_count":latch.open_count,"sequence_step":latch.sequence_step})
	for actor: EnemyActor in enemies:
		actors.append({"id":str(actor.definition.stable_id),"x":actor.motor.position.x,"y":actor.motor.position.y,"hp":actor.health.current,"dead":actor.health.terminal,"state":str(actor.attack_behavior.state) if actor.attack_behavior!=null else "patrol"})
	return {"bells":bells,"enemies":actors,"events":events.duplicate(true),"player_damage":player_damage.duplicate(true)}
