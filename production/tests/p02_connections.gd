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

func enter(id: String, storage: TestStorage, viewport: Viewport=null) -> OrdinaryRoomSession:
	var doc:=WorldRoomDocument.read(SEGMENTS+id+".json")
	var edge: String=LANDINGS[id]
	var side:=catalog.lookup("doors",edge)
	expect(side.ok and id in [side.row.a,side.row.b] and "P02" in [side.row.a,side.row.b],"authority for "+edge)
	var host:=OrdinaryRoomSession.new()
	(viewport if viewport!=null else root).add_child(host)
	var error:=host.open(doc,storage,null,catalog,edge)
	expect(error.is_empty(),id+" "+error)
	if not error.is_empty(): return host
	Connection.install(host,doc,catalog)
	await frames(2)
	for _i: int in 40:
		if host.player.is_on_floor(): break
		await physics_frame
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
	var throat:=FixedWorldProvider.point(WorldRoomDocument.read(SEGMENTS+"P16.json").exits.d009.point)
	expect(await walk(host,throat.x) and host.player.is_on_floor(),"both claims can be carried to the planted foot of the upward return")
	host.controller.router.request_action(&"jump")
	for i: int in 30:
		await physics_frame
		if host.player.position.y<=throat.y: break
	expect(host.player.position.y<=throat.y and absf(host.player.position.x-throat.x)<10,"real ground jump reaches the P16 ceiling opening with both claims")
	await leave(host)
	host=await enter("P16",storage)
	if host.controller==null:
		await leave(host)
		return
	site=host.room.find_children("*","P02ConnectionRoom",true,false)[0]
	expect(host.services.ledger().gold==coins.row.amount and host.state.value.inventory.health_shard==1 and not site.objects[Connection.PURSE].visible and not site.objects[Connection.SHARD].visible,"reload restores both independent permanent claims")
	await leave(host)

func ray(host: OrdinaryRoomSession, start: Vector2, end: Vector2) -> Vector2:
	var query:=PhysicsRayQueryParameters2D.create(start,end,1,[host.player.get_rid()])
	var hit:=host.get_world_2d().direct_space_state.intersect_ray(query)
	return hit.get("position",Vector2.INF)

func measured_section(host: OrdinaryRoomSession, side: Dictionary) -> PackedFloat32Array:
	var point:=FixedWorldProvider.point(side.point)
	var sample:=PackedFloat32Array()
	if side.direction[0]!=0:
		for dx: float in [-24.0,0.0,24.0]:
			var start:=point+Vector2(dx,0)
			var ground:=ray(host,start,start+Vector2(0,64))
			sample.append(ground.y-point.y)
	else:
		for dy: float in [-12.0,0.0,12.0]:
			var start:=point+Vector2(0,dy)
			var west:=ray(host,start,start+Vector2(-80,0))
			var east:=ray(host,start,start+Vector2(80,0))
			sample.append(west.x-point.x)
			sample.append(east.x-point.x)
	return sample

func paired_sections() -> void:
	var original:=WorldRoomDocument.read("res://rooms/world/P02.json")
	var field:=OrdinaryRoomSession.new()
	root.add_child(field)
	var error:=field.open(original,null,null,catalog)
	expect(error.is_empty(),"P02 seam geometry opens "+error)
	if not error.is_empty():
		await leave(field)
		return
	await frames(3)
	for id: String in LANDINGS:
		var edge: String=LANDINGS[id]
		var side: Dictionary=original.exits[edge]
		var doc:=WorldRoomDocument.read(SEGMENTS+id+".json")
		var other: Dictionary=doc.exits[edge]
		var direction:=FixedWorldProvider.point(side.direction)
		var axis:=0 if direction.y!=0 else 1
		expect(direction==-FixedWorldProvider.point(other.direction),edge+" normals oppose")
		for i: int in 2:
			expect(side.span[i]-side.point[axis]==other.span[i]-other.point[axis],edge+" aperture limits coincide")
		var isolated:=SubViewport.new()
		isolated.world_2d=World2D.new()
		root.add_child(isolated)
		var receiver:=await enter(id,TestStorage.new(),isolated)
		if receiver.controller!=null:
			var a:=measured_section(field,side)
			var b:=measured_section(receiver,other)
			var expected:=PackedFloat32Array([18,18,18])
			if direction.y!=0:
				expected.clear()
				for row: int in 3:
					expected.append(side.span[0]-side.point[0])
					expected.append(side.span[1]-side.point[0])
			expect(a==expected and b==expected,"%s matched actual floor/walls over both adjacent strips: %s and %s" % [edge,a,b])
			if direction.y!=0:
				receiver.player.reset_at(receiver.player.position+Vector2(60,0))
				await frames(2)
				for host: OrdinaryRoomSession in [field,receiver]:
					var gate: Dictionary=side if host==field else other
					var center:=FixedWorldProvider.point(gate.point)
					var collider: CollisionShape2D=host.player.get_node("CollisionShape2D")
					var space:=host.get_world_2d().direct_space_state
					for x: float in [-34.0,0.0,34.0]:
						expect(P02PassageTransition.clearance(space,center+Vector2(x,0),collider,1),host.room.room_id+" full player body clears the shaft at x-offset "+str(x))
					expect(P02PassageTransition.supported(space,FixedWorldProvider.point(gate.spawn),collider,1),host.room.room_id+" actual safe seat supports both feet")
		await leave(receiver)
		isolated.free()
	await leave(field)

func wait_for_arrival(pilot: FieldTerracePilot, room: String) -> bool:
	for _frame: int in 180:
		await physics_frame
		if not pilot.crossing and pilot.active.room.room_id==room:
			return pilot.last_error.is_empty() and pilot.active.player.is_on_floor()
	return false

func shaft_motion(id: String, edge: String) -> void:
	var pilot:=FieldTerracePilot.new()
	root.add_child(pilot)
	pilot.enter_room("P02","d001")
	var field:=WorldRoomDocument.read("res://rooms/world/P02.json")
	var top: Dictionary=field.exits[edge]
	var bottom: Dictionary=WorldRoomDocument.read(SEGMENTS+id+".json").exits[edge]
	var upper:=FixedWorldProvider.point(top.point)
	var lower:=FixedWorldProvider.point(bottom.point)
	if not catalog.condition_match(catalog.lookup("doors",edge).row,pilot.active.state.value.flags).matches:
		# Start this independent fixture on the opposite bank, outside the
		# observation area. Walk off the lip with the actual movement controller.
		pilot.active.player.reset_at(Vector2(top.span[0]-26,560))
		await frames(30)
		expect(pilot.active.player.is_on_floor() and not pilot.active.state.has("discover_p02_low_slope"),"opposite grass bank starts outside the watch point")
		pilot.active.controller.router.set_move_axis(1)
		for i: int in 30:
			await physics_frame
			if pilot.active.player.position.x>=upper.x-18: break
		pilot.active.controller.router.set_move_axis(0)
		for i: int in 60:
			await physics_frame
			if pilot.active.state.has("discover_p02_low_slope"): break
		expect(pilot.active.player.position.y<upper.y and pilot.active.room.room_id=="P02" and not pilot.crossing and pilot.active.state.has("discover_p02_low_slope"),"entering the actual root channel from the opposite bank records discovery before its door")
		expect(not pilot.active.state.value.explored.has(id) and not pilot.active.state.value.receipts.has(Connection.SHARD),"seeing the hidden route grants no visit or reward")
		expect(await wait_for_arrival(pilot,id),"gravity takes the discovered alternate approach to the hidden room")
		pilot.active.controller.router.request_action(&"jump")
		expect(await wait_for_arrival(pilot,"P02"),"alternate grass approach also has a supported return")
		await frames(3)
	var collider: CollisionShape2D=pilot.active.player.get_node("CollisionShape2D")
	var half_body_width: float=(collider.shape as RectangleShape2D).size.x*.5
	var wall_margin:=half_body_width+0.25
	var leftmost: float=top.span[0]+wall_margin-upper.x
	var rightmost: float=top.span[1]-wall_margin-upper.x
	for offset: float in [leftmost,0.0,rightmost]:
		# Start a full player body clear of both well cheeks. From this moment
		# the unchanged production controller owns gravity, jump and reception.
		pilot.active.player.reset_at(upper+Vector2(offset,-100))
		expect(await wait_for_arrival(pilot,id),edge+" gravity carries the body through the seam at "+str(offset))
		if pilot.active.room.room_id!=id: break
		expect(absf(pilot.active.player.position.x-(lower.x+offset))<1 and absf(pilot.active.player.position.y-bottom.spawn[1])<1,"descent lands under its own lane")
		pilot.active.controller.router.request_action(&"jump")
		expect(await wait_for_arrival(pilot,"P02"),edge+" jump returns to the actual near-side ledge at "+str(offset))
		if pilot.active.room.room_id!="P02": break
		var first: Vector2=pilot.entry_trace[0]
		var continuous:=absf(first.x-(upper.x+offset))<1
		for i: int in range(1,pilot.entry_trace.size()):
			var before: Vector2=pilot.entry_trace[i-1]
			var after: Vector2=pilot.entry_trace[i]
			continuous=continuous and before.distance_to(after)<16
		expect(continuous and pilot.active.player.position.distance_to(FixedWorldProvider.point(top.spawn))<4,"return starts on the same shaft axis and reaches the shelf through consecutive physics poses")
		await frames(3)
	await pilot.active.audio_service.shutdown()
	pilot.free()
	await frames(2)

func run() -> void:
	var locked:=catalog.load_locked()
	expect(locked.ok,"locked world model")
	if locked.ok:
		for id: String in LANDINGS: await route(id)
		await p16()
		await paired_sections()
		await shaft_motion("P16","d009")
		await shaft_motion("P19","d330")
	expect(checks>=99,"four paired openings, permanent claims and both shafts completed")
	print("P02 CONNECTIONS failures=",failures," checks=",checks)
	quit(0 if failures==0 else 1)
