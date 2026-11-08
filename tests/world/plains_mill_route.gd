extends RefCounted
## The same physical route is used by the full loop and local counterexamples.
## Callers may supply a declared room start; this route never changes position/state.
var app: FixedWorldApp
var checkpoint := "entry"
var disable_recoil_at := ""
var west_departure_y := 840.0
func ticks(count: int) -> void:
	for _i: int in count: await app.get_tree().physics_frame
func axis(value: float) -> void:
	app.controller.router.set_source_axis(&"keyboard_mouse",value)
func clear() -> void:
	app.controller.router.clear("mill_route")
func walk_to(x: float, height: float, frames: int = 300) -> bool:
	for _i: int in frames:
		await ticks(1)
		var delta := x-app.player.position.x
		axis(signf(delta) if absf(delta)>4 else 0)
		if absf(delta)<8 and absf(app.player.position.y-height)<8 and app.player.is_on_floor():
			clear();return true
	clear();return false
func shoot_bell(id: String) -> bool:
	var bell := app.room.mechanisms[id] as WorldShotLatch
	app.controller.router.request_action(&"shoot_release",(bell.bell_position-app.player.position).normalized())
	await ticks(30)
	return bell.motion_target.motion_running
func board(carrier: WorldMovingPlatform) -> bool:
	# Wait for the low part of the cycle, then jump onto the actual collision.
	for _i: int in 420:
		await ticks(1)
		if carrier.position.distance_to(carrier.origin)<35: break
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	for i: int in 90:
		await ticks(1)
		var dx:=carrier.position.x-app.player.position.x
		axis(signf(dx) if absf(dx)>4 else 0)
		if i==24:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if i>8 and app.player.is_on_floor():
			clear()
			return absf(app.player.position.y-(carrier.position.y-carrier.platform_size.y/2-18))<6
	clear();return false
func transfer(target: Vector2, aim: Vector2) -> bool:
	if checkpoint==disable_recoil_at:app.controller.recoil_ability.enabled=false
	axis(signf(target.x-app.player.position.x))
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	await ticks(9)
	var apex:=app.player.position.y
	app.controller.router.request_action(&"shoot_release",aim.normalized())
	for i: int in 100:
		await ticks(1)
		apex=minf(apex,app.player.position.y)
		var dx:=target.x-app.player.position.x
		axis(signf(dx) if absf(dx)>4 else 0)
		if i==8:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if i>10 and app.player.is_on_floor():
			clear()
			print("MILL TRANSFER ",checkpoint," landed=",app.player.position," apex=",apex)
			return absf(app.player.position.y-target.y)<8
	clear();return false
func run(owner: FixedWorldApp) -> bool:
	app=owner
	if not await walk_to(384,1262):return false
	if not await shoot_bell("P-R26:carrier_west"):return false
	if not await walk_to(512,1262):return false
	var west:=app.room.get_node("Carrier0") as WorldMovingPlatform
	if not await board(west): print("MILL BOARD WEST FAILED ",app.player.position," ",west.position);return false
	checkpoint="west_transfer"
	for _i: int in 420:
		await ticks(1)
		if west.position.y<west_departure_y:break
	if not await transfer(Vector2(1040,686),Vector2(-.8,.6)):return false
	checkpoint="east_board"
	if not await walk_to(1184,686):return false
	if not await shoot_bell("P-R26:carrier_east"):return false
	var east:=app.room.get_node("Carrier1") as WorldMovingPlatform
	if not await board(east):print("MILL BOARD EAST FAILED ",app.player.position," ",east.position);return false
	checkpoint="east_transfer"
	for _i: int in 420:
		await ticks(1)
		if east.position.y<388:break
	if not await transfer(Vector2(1168,142),Vector2.DOWN):return false
	checkpoint="exit_landing"
	return true
