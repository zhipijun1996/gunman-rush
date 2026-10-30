extends "mechanics-bfede37128d4.gd"
## Coordinate adapter only. The original SimpleRoomReward owns transactions.
var content_host: Node2D
var instance_key:=""

func setup(data: Dictionary, host: Node2D, player: PlayerController, transaction_scope, cells) -> void:
	var without_rewards:=data.duplicate(true);without_rewards.reward_sites=[]
	super.setup(without_rewards,host,player,transaction_scope,cells)
	specs=data.get("reward_sites",[]).duplicate(true)
	for spec: Dictionary in specs:
		var definition:=SimpleRewardDefinition.new()
		definition.stable_id=StringName("module/"+instance_key+"/"+str(spec.id))
		definition.kind=SimpleRewardDefinition.Kind.COINS;definition.amount=float(spec.amount)
		var service:=SimpleRoomReward.new()
		if not service.configure(definition,transaction_scope.lifetime,player.actor_resources.health,wallet):
			owner_runner.setup_error="invalid_package_reward";return
		services[str(spec.id)]=service
		var sprite:=Sprite2D.new();host.add_child(sprite);sprites[str(spec.id)]=sprite
		UnderworldObjects.place_chest(sprite,Vector2(spec.position[0],spec.position[1]+18),false)

func capture() -> void:
	for spec: Dictionary in specs:
		var service: SimpleRoomReward=services[str(spec.id)]
		if service.claimed or not actor.motor.is_on_floor():continue
		var region:=Rect2(spec.region[0],spec.region[1],spec.region[2],spec.region[3])
		if not region.has_point(content_host.to_local(actor.motor.global_position)):continue
		var receipt:=service.claim(context.lifetime.token(),StringName("workshop:"+str(spec.id)))
		events.append({"frame":context.frame,"type":"chest_claim","id":spec.id,"accepted":receipt.accepted(),"amount":receipt.amount_applied,"balance":receipt.coins})
		UnderworldObjects.place_chest(sprites[str(spec.id)],Vector2(spec.position[0],spec.position[1]+18),service.claimed)
