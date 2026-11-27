extends SceneTree
## Travel using the ordinary controller and field scene. The return-visit fixtures
## represent the off-screen G08 / F08 progress explicitly, separately from first play.
const SCENE := preload("res://rooms/world/P02.tscn")
var field: FieldTerracePilot
var failures := 0
var checks := 0
var fired := 0
var wall_kicks := 0

func _initialize() -> void:
	run.call_deferred()

func tick(n := 1) -> void:
	for i: int in n: await physics_frame

func require(ok: bool, label: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL plains intro ",label," in ",field.active.room.room_id," at ",field.active.player.position," error=",field.last_error)
	return ok

func mark(id: String) -> void:
	var at := field.active.player.position
	print("INTRO_FRAME ",id," ",Engine.get_process_frames()," ",field.active.room.room_id," ",at)

func input_axis(axis: float) -> void:
	field.active.controller.router.set_move_axis(axis)

func action(name: StringName, aim := Vector2.ZERO) -> void:
	field.active.controller.router.request_action(name,aim)

func bind_controller(_room: String) -> void:
	field.active.controller.shoot_ability.shot_fired.connect(func(_aim: Vector2,_packet: int): fired+=1)
	field.active.controller.jump_ability.accepted_jump.connect(func(kind: StringName,_serial: int,_at: Vector2):
		if kind==&"wall": wall_kicks+=1)

func go(x: float) -> bool:
	var here := field.active
	var side := signf(x-here.player.position.x)
	input_axis(side)
	for i: int in 650:
		if field.active!=here: return false
		if (x-here.player.position.x)*side<=1:
			input_axis(0)
			return true
		await tick()
	input_axis(0)
	return false

func ground(y: float,limit := 150) -> bool:
	for i: int in limit:
		if field.active.player.is_on_floor() and absf(field.active.player.position.y-y)<2: return true
		await tick()
	return false

func cross(to: String, side: float) -> bool:
	var here := field.active
	input_axis(side)
	for i: int in 650:
		await tick()
		if field.active!=here and not field.crossing:
			input_axis(0)
			return field.active.room.room_id==to and field.active.player.is_on_floor() and field.last_error.is_empty()
	input_axis(0)
	return false

func interact() -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=KEY_UP
		event.pressed=pressed
		Input.parse_input_event(event)
		await tick(3)

func jump_toward(x: float, y: float, label: String, recoil := Vector2.ZERO, hold := 8) -> bool:
	input_axis(signf(x-field.active.player.position.x))
	action(&"jump")
	await tick(hold)
	if recoil!=Vector2.ZERO:
		action(&"shoot_release",recoil.normalized())
		await tick(17)
	var reached:=await go(x)
	action(&"jump_release")
	return require(reached and await ground(y),label)

func p01_practice() -> void:
	if not require(field.active.room.room_id=="P01" and await ground(270),"new play begins on the actual P01 field"): return
	var hp:=field.active.controller.actor_resources.health.current
	mark("p01_start")
	await tick(65)
	if not require(await go(162),"walk out from the registered birthplace"): return
	await tick(28)
	await interact()
	var sign_reader:=field.active.sign_reader
	if not require(sign_reader!=null and sign_reader.reading and "反冲" in sign_reader.message.text,"the sign teaches the downward shot at the first safe field"): return
	await tick(70)
	var escape:=InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	Input.parse_input_event(escape)
	await tick(2)
	escape=escape.duplicate()
	escape.pressed=false
	Input.parse_input_event(escape)
	await tick(2)
	if not require(not sign_reader.reading and not paused,"close the sign and resume normal play"): return
	# Same launch point and initial jump. Measure the extra motion from firing.
	action(&"jump")
	var plain_apex:=field.active.player.position.y
	for i: int in 80:
		await tick()
		plain_apex=minf(plain_apex,field.active.player.position.y)
	action(&"jump_release")
	if not require(await ground(270),"plain jump returns to the training grass"): return
	mark("p01_recoil")
	await tick(22)
	var shot_count:=fired
	action(&"jump")
	await tick(9)
	action(&"shoot_release",Vector2.DOWN)
	var recoil_apex:=field.active.player.position.y
	for i: int in 48:
		await tick()
		recoil_apex=minf(recoil_apex,field.active.player.position.y)
	action(&"jump_release")
	if not require(fired==shot_count+1 and recoil_apex<plain_apex-30 and await ground(270),"a real downward shot lifts the player above the same ordinary jump before a safe landing"): return
	if not require(await go(335),"stand below the raised practice deck"): return
	action(&"jump")
	await tick(7)
	action(&"shoot_release",Vector2.DOWN)
	await tick(34)
	action(&"jump_release")
	if not require(await ground(102),"the training board receives the recoil jumper"): return
	mark("p01_deck")
	await tick(45)
	if not require(await go(440) and await ground(270),"stepping off the deck returns to supported grass"): return
	var destination:=field.passage_attempts
	if not require(await go(650) and field.passage_attempts==destination and field.active.controller.actor_resources.health.current==hp,"practice and its fall do not cost health or trigger a distant gate"): return
	mark("p01_road")
	if not require(await cross("P02",1),"walk from P01 east into P02"): return
	mark("p01_end")

func cross_field_east() -> bool:
	if not require(await go(426) and await ground(366),"P02 western takeoff is reached on foot"): return false
	if not await jump_toward(817,366,"backward recoil clears the central break",Vector2(-1,.55),12): return false
	if not await go(962): return false
	if not await jump_toward(1240,398,"ordinary jump lands on P02 upper east road",Vector2.ZERO,32): return false
	if not await go(1300): return false
	var grub: EnemyActor=field.active.room.enemies.east_road_grub
	for i: int in 260:
		if grub.motor.position.x-field.active.player.position.x<106 and grub.brain.direction<0: break
		await tick()
	if not await jump_toward(1600,398,"vault the field patrol on the shared road",Vector2.ZERO,35): return false
	return require(await cross("P03",1),"move across the real P02–P03 west doorway")

func forest_shortcut() -> void:
	# This leg begins after the continuous return from P03 to P01.
	var locked_id := "forest_slope_return_open"
	var west: Dictionary=field.active_doc.exits.d223
	if not require(await go(float(west.spawn[0])+10) and await ground(float(west.spawn[1])),"walk downhill to the meadow side of the forest latch"): return
	await interact()
	if not require(not field.active.state.has(locked_id),"the meadow does not operate the forest-side latch"): return
	input_axis(-1)
	await tick(90)
	input_axis(0)
	if not require(field.active.room.room_id=="P01" and not field.active.state.value.explored.has("F08"),"pushing the unopened meadow gate cannot visit the forest"): return
	# Load an independent off-screen F08 approach. No move or opening is
	# credited to P01, and every step through the shortcut below is real input.
	field.enter_room("F08","")
	await tick(10)
	if not require(field.active.room.room_id=="F08" and not field.active.state.has(locked_id),"forest-side arrival fixture begins with the shortcut closed"): return
	var latch := FixedWorldProvider.point(field.active_doc.sites.d223.at)
	if not require(await go(latch.x) and await ground(latch.y),"reach the actual counterweight in the forest"): return
	if not require(not field.active.state.has(locked_id),"proximity alone does not operate the lever"): return
	await interact()
	if not require(field.active.state.has(locked_id),"the forest interaction records the shortcut opening"): return
	if not require(await cross("P01",1) and await cross("F08",-1),"the opened shortcut physically carries the player in both directions"): return
	require(field.active.state.has(locked_id),"the latch remains open after returning through the gate")

func return_across_field() -> bool:
	if not require(await cross("P02",-1),"leave the P03 lower road back to P02"): return false
	if not await go(1600): return false
	var enemy: EnemyActor=field.active.room.enemies.east_road_grub
	for i: int in 300:
		if field.active.player.position.x-enemy.motor.position.x<115 and enemy.brain.direction>0: break
		await tick()
	if not await jump_toward(1290,398,"westbound vault passes the live road patrol",Vector2.ZERO,32): return false
	if not await go(1151): return false
	if not await jump_toward(941,366,"return through the high east field",Vector2.ZERO,32): return false
	if not await go(731): return false
	if not await jump_toward(350,366,"reverse recoil crosses P02's main break",Vector2(1,.55),12): return false
	return require(await cross("P01",-1) and await ground(270),"the three-room route returns to the supported P01 eastern apron")

func carried_wall_progress() -> bool:
	var s:=field.active.state
	var candidate:=s.candidate()
	candidate.flags.append("W")
	return require(s.commit(candidate,s.revision) and field.active.controller.traversal.wall_enabled,"restored G08 W progress enables the ordinary wall ability")

func kick_to_gallery(ledge_x: float, ledge_y: float) -> bool:
	var side:=1.0
	input_axis(side)
	action(&"jump")
	var kicks_before:=wall_kicks
	for i: int in 330:
		await tick()
		var body:=field.active.player
		var traversal:=field.active.controller.traversal
		if body.position.y<ledge_y-2 and side>0 and body.position.x>=ledge_x-70:
			input_axis(1)
			break
		if traversal.state==&"wall_attach" and traversal.wall_ready:
			action(&"jump")
			await tick()
			side=signf(traversal.wall_normal)
			input_axis(side)
	if not require(await go(ledge_x) and await ground(ledge_y),"real alternating wall jumps reach the eastern gallery"): return false
	return require(wall_kicks>=kicks_before+2,"more than one newly accepted wall kick was necessary on this climb")

func p03_stairway() -> bool:
	var shots_before:=fired
	var walls_before:=wall_kicks
	var hp:=field.active.controller.actor_resources.health.current
	if not require(await go(494) and await ground(334),"descend the ravine and stop by its five loose coins"): return false
	var gold_before:int=field.active.services.ledger().gold
	await interact()
	if not require(field.active.services.ledger().gold==gold_before+5,"approaching and then interacting collects exactly five coins"): return false
	await interact()
	if not require(field.active.services.ledger().gold==gold_before+5,"the same loose coin group cannot be collected twice"): return false
	mark("p03_bottom")
	await tick(28)
	if not await jump_toward(602,268,"land on the first supported switchback step"): return false
	if not require(await go(510) and await ground(334) and field.active.controller.actor_resources.health.current==hp,"a missed climb returns on foot to the same safe ravine floor"): return false
	mark("p03_retry")
	if not await jump_toward(614,268,"retry the lower rock"): return false
	for landing: Vector2 in [Vector2(758,200),Vector2(880,130),Vector2(1014,62)]:
		if not require(await go(landing.x-68),"walk to the next takeoff near its riser"): return false
		if not await jump_toward(landing.x,landing.y,"step up the east-bound switchback"): return false
	mark("p03_turn")
	await tick(32)
	for landing: Vector2 in [Vector2(899,-6),Vector2(732,-72),Vector2(600,-140),Vector2(460,-206),Vector2(340,-274)]:
		if not await jump_toward(landing.x,landing.y,"climb the westbound return above the ravine"): return false
	if not require(fired==shots_before and wall_kicks==walls_before and not field.active.controller.traversal.wall_enabled,"the first climb succeeds with ordinary jumps and without W or weapon boosts"): return false
	mark("p03_road")
	if not await go(215): return false
	var grub: EnemyActor=field.active.room.enemies.old_road_grub
	for i: int in 220:
		if field.active.player.position.x-grub.motor.position.x<112 and grub.brain.direction>0: break
		await tick()
	if not await jump_toward(-90,-274,"vault the old-road patrol and keep the westward heading",Vector2.ZERO,32): return false
	if not require(await cross("P04",-1),"the upper road physically opens the next room on the west"): return false
	mark("p03_end")
	return true

func p03_east_return() -> bool:
	if not require(await cross("P03",1),"P04 returns to the P03 old road"): return false
	if not require(await go(951) and await ground(-6),"descend the old road to its outer lip"): return false
	var furthest:=field.active.player.position.x
	input_axis(1)
	action(&"jump")
	await tick(12)
	action(&"shoot_release",Vector2(-.48,.88).normalized())
	for i: int in 100:
		await tick()
		furthest=maxf(furthest,field.active.player.position.x)
	input_axis(0)
	action(&"jump_release")
	if not require(furthest<1300 and await ground(62),"even from the high switchback the physical ridge stops a forward recoil and returns the player to the turning platform"): return false
	if not require(await go(504) and await ground(334),"descend the east stairs to the original ravine floor"): return false
	await interact()
	if not require(field.active.services.ledger().gold==5,"re-entering from the high road cannot pay the low coins again"): return false
	if not require(await go(1434) and await ground(334),"walk under the overhang to the foot of the eastern rock wall"): return false
	var before:=wall_kicks
	var high:=field.active.player.position.y
	input_axis(1)
	action(&"jump")
	for i: int in 130:
		await tick()
		if i==18: action(&"shoot_release",Vector2.DOWN)
		if i in [30,43]: action(&"jump")
		high=minf(field.active.player.position.y,high)
	action(&"jump_release")
	input_axis(0)
	if not require(high>-46 and wall_kicks==before and await ground(334) and not field.active.state.value.gear_ids.carried.has("TG02"),"even a high recoil and repeated jump inputs do not scale the eastern wall before W"): return false
	if not carried_wall_progress(): return false
	mark("p03_w_start")
	await tick(38)
	if not await kick_to_gallery(1534,-46): return false
	var gear:=FixedWorldProvider.point(field.active_doc.sites.wr_TG02.at)
	if not require(await go(gear.x) and await ground(gear.y) and not field.active.state.value.gear_ids.carried.has("TG02"),"reach the east niche without automatic receipt"): return false
	await interact()
	await interact()
	if not require(field.active.state.value.inventory.get("time_gear",0)==1 and field.active.state.value.gear_ids.carried.count("TG02")==1,"the W revisit owns exactly one genuine TG02 gear"): return false
	mark("p03_gear")
	await tick(58)
	mark("p03_w_end")
	if not require(await cross("P13",1) and await cross("P03",-1),"the eastern ledge connects both ways through d017"): return false
	if not require(field.active.controller.traversal.wall_enabled and field.active.state.value.gear_ids.carried.count("TG02")==1 and field.active.state.value.inventory.get("time_gear",0)==1,"the acquired gear and G08 wall ability survive the eastern round trip"): return false
	if not require(await go(1418) and await ground(334),"a real drop from the eastern niche returns safely to the lower route"): return false
	if not require(await go(224) and await ground(334),"walk west to the foot of the original entry steps"): return false
	if not await jump_toward(135,302,"step back onto the lower entry shelf"): return false
	return await jump_toward(-111,270,"regain the west lower entrance from the gully",Vector2.ZERO,28)

func run() -> void:
	field=SCENE.instantiate()
	root.add_child(field)
	if field.active==null:
		printerr("Cannot start the official plains entrance: ",field.last_error)
		quit(1)
		return
	field.room_changed.connect(bind_controller)
	bind_controller(field.active.room.room_id)
	await tick(8)
	var args:=OS.get_cmdline_user_args()
	if "--film-p03" in args:
		# Begin this camera take at the real d002 receiving anchor. The full
		# regression below separately traverses the entire P01→P02→P03 journey.
		field.enter_room("P03","d002")
		await tick(5)
		if await p03_stairway(): await p03_east_return()
	else:
		await p01_practice()
		if failures==0 and "--film-p01" not in args:
			if await cross_field_east() and await p03_stairway() and await p03_east_return() and await return_across_field():
				await forest_shortcut()
	print("PLAINS INTRO failures=",failures," checks=",checks)
	await field.active.audio_service.shutdown()
	field.free()
	quit(1 if failures else 0)
