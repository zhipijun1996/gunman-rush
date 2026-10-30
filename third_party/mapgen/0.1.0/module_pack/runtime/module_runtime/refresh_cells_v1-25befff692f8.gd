extends RefCounted
const CARRY=preload("refresh_carrier_support_v1-a37785f5dbaf.gd")
const TIMED=preload("refresh_timed_latch_v1-94f453a25bbd.gd")

static func ordinary(data: Dictionary) -> Dictionary:
	var copy:=data.duplicate(true)
	copy.latches=copy.get("latches",[]).filter(func(l):return str(l.id) not in data.get("refresh_reopenable_latches",[]))
	return copy

static func install(data: Dictionary, host: Node2D, player: PlayerController, scope, cells) -> Array:
	var consumers: Array=[]
	for spec: Dictionary in data.get("latches",[]):
		if str(spec.id) not in data.get("refresh_reopenable_latches",[]):continue
		var latch=TIMED.new();latch.link_id=str(spec.id);latch.formal_presentation=true
		latch.prompt_text=str(spec.get("prompt",""));latch.open_seconds=float(spec.open_seconds)
		host.add_child(latch);latch.setup(player,scope.lifetime,Vector2(spec.bell[0],spec.bell[1]),Rect2(spec.gate[0],spec.gate[1],spec.gate[2],spec.gate[3]))
		latch.opened.connect(cells._bell_open.bind(latch,str(spec.id)));cells.latches.append(latch)

	for spec: Dictionary in data.get("refresh_carried_enemies",[]):
		var actor: EnemyActor=null
		for i: int in data.enemies.size():
			if str(data.enemies[i].id)==str(spec.enemy):actor=cells.enemies[i]
		for ferry: ModuleMovingPlatform in scope.module.moving_platforms:
			if str(ferry.definition.platform_id)!=str(spec.carrier) or actor==null:continue
			var support=CARRY.new();support.configure(actor,ferry);host.add_child(support);consumers.append(support)
	return consumers
