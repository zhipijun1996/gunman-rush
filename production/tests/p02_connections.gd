extends SceneTree
## Compare the four official door sections in independent physics worlds, then
## drive gravity and a ground jump through both actual lower receivers.
const LANDINGS := {"P01":"d001","P03":"d002","P16":"d009","P19":"d330"}
const SHAFT_HALF_WIDTH := 48.0
var catalog := WorldContentCatalog.new()
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL P02 landing ",message)

func frames(n: int) -> void:
	for i in n: await physics_frame

func landing_document(id: String) -> Dictionary:
	var result := catalog.room_document(id)
	return WorldRoomDocument.read(result.path) if result.ok else WorldRoomDocument.read(catalog.binding("rooms",id).row.document_path)

func enter(id: String, parent: Node) -> OrdinaryRoomSession:
	var room := OrdinaryRoomSession.new()
	parent.add_child(room)
	var error := room.open(landing_document(id),null,null,catalog,LANDINGS[id])
	expect(error.is_empty(),"open "+id+" "+error)
	await frames(4)
	return room

func leave(room: OrdinaryRoomSession) -> void:
	if is_instance_valid(room.audio_service): await room.audio_service.shutdown()
	room.free()
	await frames(2)

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
		var doc:=landing_document(id)
		var other: Dictionary=doc.exits[edge]
		var direction:=FixedWorldProvider.point(side.direction)
		var axis:=0 if direction.y!=0 else 1
		expect(direction==-FixedWorldProvider.point(other.direction),edge+" normals oppose")
		for i: int in 2:
			expect(absf((side.span[i]-side.point[axis])-(other.span[i]-other.point[axis]))<.01,edge+" aperture limits coincide")
		var isolated:=SubViewport.new()
		isolated.world_2d=World2D.new()
		root.add_child(isolated)
		var receiver:=await enter(id,isolated)
		if receiver.controller!=null:
			var a:=measured_section(field,side)
			var b:=measured_section(receiver,other)
			var expected:=PackedFloat32Array([18,18,18])
			if direction.y!=0:
				expected.clear()
				for row: int in 3:
					expected.append(-SHAFT_HALF_WIDTH)
					expected.append(SHAFT_HALF_WIDTH)
			var matched := true
			for sample in expected.size():
				matched = matched and absf(a[sample]-expected[sample])<.15 and absf(b[sample]-expected[sample])<.15
			expect(matched,"%s matched actual floor/walls over both adjacent strips: %s and %s" % [edge,a,b])
			if direction.y!=0:
				receiver.player.reset_at(receiver.player.position+Vector2(60,0))
				await frames(2)
				for host: OrdinaryRoomSession in [field,receiver]:
					var gate: Dictionary=side if host==field else other
					var center:=FixedWorldProvider.point(gate.point)
					var collider: CollisionShape2D=host.player.get_node("CollisionShape2D")
					var space:=host.get_world_2d().direct_space_state
					for x: float in [-34.0,0.0,34.0]:
						expect(WorldPassage.clearance(space,center+Vector2(x,0),collider,1),host.room.room_id+" full player body clears the shaft at x-offset "+str(x))
					expect(WorldPassage.supported(space,FixedWorldProvider.point(gate.spawn),collider,1),host.room.room_id+" actual safe seat supports both feet")
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
	var bottom: Dictionary=landing_document(id).exits[edge]
	var upper:=FixedWorldProvider.point(top.point)
	var lower:=FixedWorldProvider.point(bottom.point)
	if not catalog.condition_match(catalog.lookup("doors",edge).row,pilot.active.state.value.flags).matches:
		# Start this independent fixture on the opposite bank, outside the
		# observation area. Walk off the lip with the actual movement controller.
		pilot.active.player.reset_at(Vector2(161,608))
		await frames(30)
		expect(pilot.active.player.is_on_floor() and not pilot.active.state.has("discover_p02_low_slope"),"opposite grass bank starts outside the watch point")
		pilot.active.controller.router.set_move_axis(-1)
		await frames(28)
		expect(pilot.active.player.is_on_wall() and pilot.active.room.room_id=="P02" and not pilot.active.state.has("discover_p02_low_slope"),"the lower west bank ends at its solid foot rather than the western room boundary")
		pilot.active.controller.router.set_move_axis(1)
		for i: int in 75:
			await physics_frame
			if pilot.active.player.position.x>=upper.x-18: break
		pilot.active.controller.router.set_move_axis(0)
		for i: int in 60:
			await physics_frame
			if pilot.active.state.has("discover_p02_low_slope"): break
		expect(pilot.active.player.position.y<upper.y and pilot.active.room.room_id=="P02" and not pilot.crossing and pilot.active.state.has("discover_p02_low_slope"),"entering the actual root channel from the opposite bank records discovery before its door")
		expect(not pilot.active.state.value.explored.has(id) and not pilot.active.state.value.receipts.has("wr_P16_primary"),"seeing the hidden route grants no visit or reward")
		expect(await wait_for_arrival(pilot,id),"gravity takes the discovered alternate approach to the hidden room")
		pilot.active.controller.router.request_action(&"jump")
		expect(await wait_for_arrival(pilot,"P02"),"alternate grass approach also has a supported return")
		await frames(3)
	var collider: CollisionShape2D=pilot.active.player.get_node("CollisionShape2D")
	var half_body_width: float=(collider.shape as RectangleShape2D).size.x*.5
	var wall_margin:=half_body_width+0.25
	var leftmost: float=-SHAFT_HALF_WIDTH+wall_margin
	var rightmost: float=SHAFT_HALF_WIDTH-wall_margin
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
	var loaded := catalog.load_locked()
	if loaded.ok: loaded = catalog.load_bindings("res://config/imported_world/bindings.json")
	expect(loaded.ok,"official runtime room bindings")
	if loaded.ok:
		await paired_sections()
		await shaft_motion("P16","d009")
		await shaft_motion("P19","d330")
	print("P02 CONNECTIONS failures=",failures," checks=",checks)
	quit(1 if failures else 0)
