extends Node
## Isolated Cell composition. Original SimpleRoomReward owns coin transactions;
## original ShotLatch owns safe closing and platform start/pause.
var owner_runner
var actor: PlayerController
var context
var specs: Array=[]
var services: Dictionary={}
var wallet:=RunWallet.new()
var events: Array=[]
var sprites: Dictionary={}

func setup(data: Dictionary, host: Node2D, player: PlayerController, scope, cells) -> void:
	actor=player;context=scope;specs=data.get("reward_sites",[]).duplicate(true)
	for spec: Dictionary in data.get("latches",[]):
		for latch: ShotLatch in cells.latches:
			if str(latch.link_id)!=str(spec.id):continue
			if spec.has("return_access"):latch.add_access_bell(Vector2(spec.return_access[0],spec.return_access[1]),false,true)
			if latch.motion_mode:latch.opened.connect(func():events.append({"frame":context.frame,"type":"carrier_toggle","id":latch.link_id,"running":latch.motion_target.motion_running,"airborne":not actor.motor.is_on_floor()}))
	for spec: Dictionary in specs:
		var definition:=SimpleRewardDefinition.new()
		definition.stable_id=StringName("workshop/"+str(spec.id))
		definition.kind=SimpleRewardDefinition.Kind.COINS;definition.amount=float(spec.amount)
		var service:=SimpleRoomReward.new()
		if not service.configure(definition,scope.lifetime,actor.actor_resources.health,wallet):
			owner_runner.setup_error="invalid_workshop_reward";return
		services[str(spec.id)]=service
		var sprite:=Sprite2D.new();host.add_child(sprite);sprites[str(spec.id)]=sprite
		UnderworldObjects.place_chest(sprite,Vector2(spec.position[0],spec.position[1]+18),false)

func capture() -> void:
	for spec: Dictionary in specs:
		var service: SimpleRoomReward=services[str(spec.id)]
		if service.claimed or not actor.motor.is_on_floor():continue
		var region:=Rect2(spec.region[0],spec.region[1],spec.region[2],spec.region[3])
		if not region.has_point(actor.motor.position):continue
		var receipt:=service.claim(context.lifetime.token(),StringName("workshop:"+str(spec.id)))
		events.append({"frame":context.frame,"type":"chest_claim","id":spec.id,"accepted":receipt.accepted(),"amount":receipt.amount_applied,"balance":receipt.coins})
		UnderworldObjects.place_chest(sprites[str(spec.id)],Vector2(spec.position[0],spec.position[1]+18),service.claimed)

func snapshot() -> Dictionary:
	var carriers: Array=[]
	for carrier: ModuleMovingPlatform in context.module.moving_platforms:
		carriers.append({"id":str(carrier.definition.platform_id),"clock":carrier.motion_clock,"running":carrier.motion_running,"controlled":carrier.bell_controlled})
	return {"events":events.duplicate(true),"coins":wallet.balance,"carriers":carriers}
