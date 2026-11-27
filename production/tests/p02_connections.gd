extends SceneTree

const SEGMENTS := "res://rooms/world/p02_connections/"
const LANDINGS := {"P01":"d001","P03":"d002","P16":"d009","P19":"d330"}
const Connection := preload("res://rooms/world/p02_connections/connection_room.gd")
var catalog := WorldContentCatalog.new()
var checks := 0
var failures := 0

class TestStorage extends WorldSaveService:
	var writable := true
	var saved := {}
	var rev := 0
	func commit(candidate: Dictionary, expected: int) -> bool:
		if not writable: return false
		saved=candidate.duplicate(true)
		rev=expected
		return true
	func load_profile() -> Dictionary: return {"accepted":true,"payload":saved.duplicate(true),"revision":rev}

func _initialize() -> void: run.call_deferred()

func expect(value: bool, description: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL P02 landing ",description)

func frames(n: int) -> void:
	for _n: int in n: await physics_frame

func walk(host: OrdinaryRoomSession, x: float) -> bool:
	var direction:=signf(x-host.player.position.x)
	host.controller.router.set_move_axis(direction)
	for _i: int in 180:
		if (x-host.player.position.x)*direction<=0:
			host.controller.router.set_move_axis(0)
			await frames(4)
			return true
		await physics_frame
	host.controller.router.set_move_axis(0)
	return false

func press_up(host: OrdinaryRoomSession) -> void:
	var input: KeyboardMouseAdapter = host.player.get_node("KeyboardMouseAdapter")
	for pressed: bool in [true,false]:
		var key := InputEventKey.new()
		key.physical_keycode=KEY_NONE
		key.keycode=KEY_UP
		key.pressed=pressed
		input._unhandled_input(key)
		await frames(2)

func enter(id: String, storage: TestStorage) -> OrdinaryRoomSession:
	var doc:=WorldRoomDocument.read(SEGMENTS+id+".json")
	var edge: String=LANDINGS[id]
	var side:=catalog.lookup("doors",edge)
	expect(side.ok and id in [side.row.a,side.row.b] and "P02" in [side.row.a,side.row.b],"authority for "+edge)
	doc.root.properties.start_point=doc.exits[edge].spawn
	var host:=OrdinaryRoomSession.new()
	root.add_child(host)
	var error:=host.open(doc,storage,null,catalog)
	expect(error.is_empty(),id+" "+error)
	if not error.is_empty(): return host
	Connection.install(host,doc,catalog)
	await frames(6)
	return host

func leave(host: OrdinaryRoomSession) -> void:
	if host.audio_service!=null: await host.audio_service.shutdown()
	host.free()
	await frames(2)

func route(id: String) -> void:
	var host:=await enter(id,TestStorage.new())
	if host.controller==null:
		await leave(host)
		return
	expect(host.player.is_on_floor(),id+" lands on real geometry")
	var doc:=WorldRoomDocument.read(SEGMENTS+id+".json")
	var door: Dictionary=doc.exits[LANDINGS[id]]
	var target:=FixedWorldProvider.point(door.point)
	if door.direction[1]<0:
		host.controller.router.request_action(&"jump")
		var crossed:=false
		for _i: int in 30:
			await physics_frame
			if host.player.position.y<=target.y and absf(host.player.position.x-target.x)<12:
				crossed=true
				break
		expect(crossed,id+" jumps up the clear return throat")
	else:
		expect(await walk(host,target.x) and host.player.is_on_floor(),id+" walks out along continuous tread")
	await leave(host)

func p16() -> void:
	var storage:=TestStorage.new()
	var host:=await enter("P16",storage)
	if host.controller==null:
		await leave(host)
		return
	var site: P02ConnectionRoom=host.room.find_children("*","P02ConnectionRoom",true,false)[0]
	var coins:=catalog.lookup("coin_caches",Connection.PURSE)
	var fragment:=catalog.lookup("rewards",Connection.SHARD)
	expect(not site.claim(Connection.SHARD,host.state.revision) and not site.claim(Connection.PURSE,host.state.revision),"arrival issues nothing")
	expect(await walk(host,site.points[Connection.PURSE].x),"walk to independent pouch")
	expect(site.label.text.begins_with("↑"),"actual pickup key shown at the pouch")
	storage.writable=false
	await press_up(host)
	expect(host.services.ledger().gold==0 and site.objects[Connection.PURSE].visible,"failed storage leaves pouch intact")
	storage.writable=true
	await press_up(host)
	expect(coins.ok and host.services.ledger().gold==coins.row.amount and host.state.value.receipts.has("income:"+Connection.PURSE),"real wallet credit uses authored amount and receipt")
	expect(not host.state.value.inventory.has("health_shard") and not site.claim(Connection.PURSE,host.state.revision),"pouch never awards HP01 or pays twice")
	expect(await walk(host,site.points[Connection.SHARD].x),"walk from pouch to separate shard pedestal")
	var old:=host.state.revision
	expect(not site.claim(Connection.SHARD,old-1),"stale request cannot take HP01")
	await press_up(host)
	expect(fragment.ok and fragment.row.formal_item_id=="HP01" and host.state.value.inventory.health_shard==fragment.row.quantity and host.state.value.receipts.has(Connection.SHARD),"HP01 lives in permanent fragment inventory")
	expect(not site.claim(Connection.SHARD,host.state.revision),"fragment cannot issue twice")
	expect(await walk(host,466),"walk out to P02 with both claims")
	await leave(host)
	host=await enter("P16",storage)
	if host.controller==null:
		await leave(host)
		return
	site=host.room.find_children("*","P02ConnectionRoom",true,false)[0]
	expect(host.services.ledger().gold==coins.row.amount and host.state.value.inventory.health_shard==1 and not site.objects[Connection.PURSE].visible and not site.objects[Connection.SHARD].visible,"reload restores both independent permanent claims")
	await leave(host)

func run() -> void:
	var locked:=catalog.load_locked()
	expect(locked.ok,"locked world model")
	if locked.ok:
		for id: String in LANDINGS: await route(id)
		await p16()
	expect(checks>=26,"every landing and both P16 sources finished")
	print("P02 CONNECTIONS failures=",failures," checks=",checks)
	quit(0 if failures==0 else 1)
