extends SceneTree
## Travel using the ordinary controller and field scene. The return-visit fixtures
## represent the off-screen G08 / F08 progress explicitly, separately from first play.
const SCENE := preload("res://rooms/world/P02.tscn")
var field: FieldTerracePilot
var failures := 0
var checks := 0
var fired := 0
var wall_kicks := 0
var touch
var low_coin_total := 0

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
	if touch!=null:
		touch.move(axis)
		return
	field.active.controller.router.set_move_axis(axis)

func action(name: StringName, aim := Vector2.ZERO) -> void:
	if touch!=null:
		if name==&"shoot_release": touch.fire(aim)
		elif name==&"jump" or name==&"jump_release": touch.jump(name==&"jump")
		return
	field.active.controller.router.request_action(name,aim)

func bind_controller(_room: String) -> void:
	if touch!=null: touch.attach(field.active)
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
	if touch!=null:
		touch.tap(touch.controls.interact_center)
		await tick(4)
		return
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
	mark("p01_start")
	if not require(field.active.room.room_id=="P01" and await ground(270),"new play begins on the actual P01 field"): return
	var hp:=field.active.controller.actor_resources.health.current
	var sign_reader:=field.active.sign_reader
	if not require(sign_reader!=null and not sign_reader.hint.visible,"the reading key does not appear at the distant spawn"): return
	if not require(not field.active.state.has("gun") and not field.active.controller.shoot_ability.enabled,"P01 begins unarmed"): return
	await tick(18)
	var unarmed_shots:=fired
	action(&"shoot_release",Vector2.DOWN)
	await tick(6)
	if not require(fired==unarmed_shots and await ground(270),"pulling the trigger before pickup cannot fire or launch the player"): return
	if not require(await go(155),"walk to the visible weapon after standing up"): return
	await interact()
	if not require(field.active.state.has("gun") and field.active.controller.shoot_ability.enabled and not sign_reader.reading,"interaction at the loose gun equips it without opening the sign"): return
	mark("p01_gun")
	if not require(await go(162),"walk out from the registered birthplace"): return
	await tick(64)
	mark("p01_read_prompt")
	if not require(sign_reader.hint.visible and (touch!=null or ("↑" in sign_reader.hint.text and "W" in sign_reader.hint.text)),"the nearby board shows the available reading keys before any interaction"): return
	await interact()
	if not require(sign_reader.reading and "反冲" in sign_reader.message.text,"the sign teaches the downward shot at the first safe field"): return
	if not require(not sign_reader.hint.visible,"reading the open notice hides its approach prompt"): return
	await tick(70)
	if touch!=null:
		var close_button:=sign_reader.panel.find_children("*","Button",true,false)[0] as Button
		touch.tap(close_button.get_global_rect().get_center())
		await tick(3)
	else:
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
	if not require(await go(364) and await ground(102),"stand beside the physical loft chest"): return
	var old_gold:int=field.active.services.ledger().gold
	await tick(8)
	await interact()
	# Coins follow the normal pickup physics, so walk the top after opening.
	await tick(60)
	if not require(await go(402) and await go(267) and await go(364),"walk the practice loft to pick up the actual bouncing money bag"): return
	await tick(20)
	if not require(field.active.services.ledger().gold==old_gold+5,"the opened chest awards precisely five physically collected coins"): return
	mark("p01_chest")
	await interact()
	await tick(16)
	if not require(field.active.services.ledger().gold==old_gold+5,"the open chest cannot issue a second drop"): return
	if not require(await go(440) and await ground(270),"stepping off the deck returns to supported grass"): return
	var destination:=field.passage_attempts
	if not require(await go(650) and field.passage_attempts==destination and field.active.controller.actor_resources.health.current==hp,"practice and its fall do not cost health or trigger a distant gate"): return
	mark("p01_road")
	if not require(await cross("P02",1),"walk from P01 east into P02"): return
	mark("p01_end")

func climb_grass_recess(y: float) -> bool:
	if not require(await go(281),"take off from the open side of the grass ledge"): return false
	input_axis(-1)
	action(&"jump")
	await tick(4)
	input_axis(0)
	await tick(7)
	action(&"jump_release")
	return require(await go(304) and await ground(y),"steer back onto the next grass-bank tread")

func hidden_field_detour() -> bool:
	if not require(await go(459) and await ground(558),"step off the upper field into its drainage channel"): return false
	if not require(await go(307) and field.active.state.has("discover_p02_low_slope"),"find the root passage on foot"): return false
	mark("p02_grass")
	var bug:EnemyActor=field.active.room.enemies.grass_verge_grub
	for i: int in 7:
		if bug.health.terminal: break
		if not require(await go(307),"steady the shot on the bank"): return false
		action(&"shoot_release",(bug.motor.position-field.active.player.position+Vector2(0,5)).normalized())
		await tick(28)
	if not require(bug.health.terminal,"clear the low grass patrol with the gun picked up in P01"): return false
	if not await go(404): return false
	input_axis(-1)
	action(&"jump")
	await tick(5)
	action(&"shoot_release",Vector2(1,.15).normalized())
	if not require(await go(140),"vault the opening toward the lower west bank"): return false
	action(&"jump_release")
	if not require(await ground(590),"land on the west bank before the sealed hillside"): return false
	mark("p02_bank")
	input_axis(-1)
	await tick(52)
	if not require(field.active.player.is_on_wall() and field.active.player.position.x>35,"the west bank ends at the actual rock face before the screen edge"): return false
	mark("p02_foot")
	input_axis(0)
	await tick(36)
	if not require(await go(240) and await cross("P16",0) and await ground(270),"follow the real chute into P16"): return false
	action(&"jump")
	if not require(await cross("P02",0) and await ground(714),"P16 returns to a supported P02 ledge"): return false
	action(&"jump_release")
	if not await climb_grass_recess(636) or not await climb_grass_recess(558): return false
	if not require(await go(459) and await ground(558),"leave the optional passage on foot"): return false
	if not await jump_toward(508,462,"use the western shoulder to regain the upper field"): return false
	return await jump_toward(404,366,"return from the drainage route to the main western takeoff")

func cross_field_east() -> bool:
	if not await hidden_field_detour(): return false
	mark("p02_launch")
	await tick(35)
	if not require(await go(426) and await ground(366),"P02 western takeoff is reached on foot"): return false
	if not await jump_toward(817,366,"backward recoil clears the central break",Vector2(-1,.55),12): return false
	mark("p02_bell")
	await tick(40)
	if not await go(962): return false
	if not await jump_toward(1240,398,"ordinary jump lands on P02 upper east road",Vector2.ZERO,32): return false
	if not await go(1300): return false
	var grub: EnemyActor=field.active.room.enemies.east_road_grub
	for i: int in 260:
		if grub.motor.position.x-field.active.player.position.x<106 and grub.brain.direction<0: break
		await tick()
	if not await jump_toward(1600,398,"vault the field patrol on the shared road",Vector2.ZERO,35): return false
	mark("p02_east")
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
	if not require(await go(190) and await ground(302),"approach the ravine patrol from the lower entry shelf"): return false
	var grub: EnemyActor=field.active.room.enemies.ravine_floor_grub
	for i: int in 250:
		if grub.motor.position.x-field.active.player.position.x<114 and grub.brain.direction<0: break
		await tick()
	mark("p03_grub")
	if not await jump_toward(494,334,"jump over the approaching ravine grub and land beside the loose coins",Vector2.ZERO,36): return false
	if not require(not grub.health.terminal and field.active.controller.actor_resources.health.current==hp,"the grass patrol can be left alive without a contact hit"): return false
	var gold_before:int=field.active.services.ledger().gold
	await interact()
	if not require(field.active.services.ledger().gold==gold_before+5,"approaching and then interacting collects exactly five coins"): return false
	await interact()
	low_coin_total=gold_before+5
	if not require(field.active.services.ledger().gold==low_coin_total,"the same loose coin group cannot be collected twice"): return false
	mark("p03_bottom")
	await tick(28)
	if not await jump_toward(602,268,"land on the first supported switchback step"): return false
	if not require(await go(510) and await ground(334) and field.active.controller.actor_resources.health.current==hp,"a missed climb returns on foot to the same safe ravine floor"): return false
	mark("p03_retry")
	if not await jump_toward(614,268,"retry the lower rock"): return false
	for landing: Vector2 in [Vector2(759,200),Vector2(894,144),Vector2(1028,80)]:
		if not require(await go(landing.x-68),"walk to the next takeoff near its riser"): return false
		if not await jump_toward(landing.x,landing.y,"step up the east-bound switchback"): return false
	mark("p03_turn")
	await tick(32)
	if not require(await go(976),"stand near the western lip of the turning shelf"): return false
	if not await jump_toward(874,28,"reverse course and clear the open cut to the armed west road"): return false
	if not require(fired==shots_before and wall_kicks==walls_before and not field.active.controller.traversal.wall_enabled,"the ordinary jump route reaches the upper road without W or weapon boosts"): return false
	var sentry: EnemyActor=field.active.room.enemies.ridge_watch_sentry
	mark("p03_sentry")
	for i: int in 7:
		if sentry.health.terminal: break
		if not require(await go(798),"take a supported firing stance on the upper road"): return false
		var aim:Vector2=(sentry.motor.global_position-field.active.player.global_position+Vector2(0,6)).normalized()
		action(&"shoot_release",aim)
		await tick(28)
	if not require(sentry.health.terminal and field.active.player.is_on_floor(),"aimed shots clear the upper sentry while the player stays supported"): return false
	mark("p03_sentry_clear")
	for landing: Vector2 in [Vector2(520,-46),Vector2(389,-116),Vector2(259,-182),Vector2(145,-236),Vector2(10,-274)]:
		if not require(await go(landing.x+83),"walk to the next westbound rising ledge"): return false
		if not await jump_toward(landing.x,landing.y,"climb the westbound return high above the ravine"): return false
	mark("p03_road")
	if not require(await cross("P04",-1),"the upper road physically opens the next room on the west"): return false
	mark("p03_end")
	return true

func p03_east_return() -> bool:
	if not require(await cross("P03",1),"P04 returns to the P03 old road"): return false
	if not require(await go(878) and await ground(28),"descend the old road to its outer lip"): return false
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
	if not require(furthest<1300 and await ground(80),"even from the high switchback the physical ridge stops a forward recoil and returns the player to the turning platform"): return false
	if not require(await go(504) and await ground(334),"descend the east stairs to the original ravine floor"): return false
	var revisited_gold:int=field.active.services.ledger().gold
	await interact()
	if not require(revisited_gold>=low_coin_total and field.active.services.ledger().gold==revisited_gold,"re-entering from the high road cannot pay the low coins again"): return false
	if not require(await go(1434) and await ground(334),"walk under the overhang to the foot of the eastern rock wall"): return false
	await tick(86)
	var view:=root.get_visible_rect()
	var content:=field.connection as WorldRoomDressing
	var relic:=content.objects.wr_TG02.get_child(0) as WorldSpriteAnimation
	var character_shape:=field.active.player.get_node("CollisionShape2D") as CollisionShape2D
	var player_on_screen:=character_shape.get_global_transform_with_canvas()*character_shape.shape.get_rect()
	var relic_on_screen:=relic.get_global_transform_with_canvas()*relic.get_rect()
	if not require(not field.active.controller.traversal.wall_enabled and relic.is_visible_in_tree() and view.encloses(player_on_screen) and view.encloses(relic_on_screen),"the unaided shaft-floor camera shows the real player and the actual unclaimed gear together"): return false
	mark("p03_look")
	await tick(86)
	mark("p03_look_end")
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
	if "--touch" in OS.get_cmdline_user_args():
		touch=preload("res://tests/plains_touch_driver.gd").new()
	field.room_changed.connect(bind_controller)
	bind_controller(field.active.room.room_id)
	await tick(8)
	var args:=OS.get_cmdline_user_args()
	if "--film-p02" in args:
		if not require(await preload("res://tests/plains_start_input.gd").take_ground_gun(field),"take the ground weapon before the P02 review"): quit(1); return
		if require(await cross("P02",1),"walk through P01's real east gate to begin the field review"):
			require(await cross_field_east(),"complete the P02 review")
	elif "--film-p03" in args:
		# Begin this camera take at the real d002 receiving anchor. The full
		# regression below separately traverses the entire P01→P02→P03 journey.
		if not require(await preload("res://tests/plains_start_input.gd").take_ground_gun(field),"collect the P01 ground gun before the separate P03 recording"): quit(1); return
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
