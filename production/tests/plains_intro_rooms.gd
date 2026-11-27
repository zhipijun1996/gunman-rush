extends SceneTree
## Travel using the ordinary controller and field scene. The return-visit fixtures
## represent the off-screen G08 / F08 progress explicitly, separately from first play.
const SCENE := preload("res://tests/plains_test_host.tscn")
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
	var grass_y:=field.active.room.start_point.y
	var gun:=FixedWorldProvider.point(field.active_doc.sites[PlainsOpening.SITE].at)
	var sign_at:=FixedWorldProvider.point(field.active_doc.entities.practice_notice.properties.point)
	var deck:=FixedWorldProvider.rect(field.active_doc.entities.practice_loft.properties.rect)
	var chest:=FixedWorldProvider.point(field.active_doc.entities.loft_coin_chest.properties.position)
	var east:=FixedWorldProvider.point(field.active_doc.exits.d001.spawn)
	if not require(field.active.room.room_id=="P01" and await ground(grass_y),"new play begins on the actual P01 field"): return
	var hp:=field.active.controller.actor_resources.health.current
	var sign_reader:=field.active.sign_reader
	if not require(sign_reader!=null and not sign_reader.hint.visible,"the reading key does not appear at the distant spawn"): return
	if not require(not field.active.state.has("gun") and not field.active.controller.shoot_ability.enabled,"P01 begins unarmed"): return
	await tick(18)
	var unarmed_shots:=fired
	action(&"shoot_release",Vector2.DOWN)
	await tick(6)
	if not require(fired==unarmed_shots and await ground(grass_y),"pulling the trigger before pickup cannot fire or launch the player"): return
	if not require(await go(gun.x),"walk to the visible weapon after standing up"): return
	await interact()
	if not require(field.active.state.has("gun") and field.active.controller.shoot_ability.enabled and not sign_reader.reading,"interaction at the loose gun equips it without opening the sign"): return
	mark("p01_gun")
	if not require(await go(sign_at.x-24),"walk out from the registered birthplace"): return
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
	if not require(await ground(grass_y),"plain jump returns to the training grass"): return
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
	if not require(fired==shot_count+1 and recoil_apex<plain_apex-30 and await ground(grass_y),"a real downward shot lifts the player above the same ordinary jump before a safe landing"): return
	if not require(await go(deck.get_center().x),"stand below the raised practice deck"): return
	action(&"jump")
	var under_deck_apex:=field.active.player.position.y
	for frame in 70:
		await tick()
		under_deck_apex=minf(under_deck_apex,field.active.player.position.y)
	action(&"jump_release")
	if not require(under_deck_apex>chest.y and await ground(grass_y),"a full ordinary jump beneath the loft cannot reach its tread and returns safely to the same grass"): return
	await tick(2)
	action(&"jump")
	await tick(7)
	action(&"shoot_release",Vector2.DOWN)
	await tick(34)
	action(&"jump_release")
	if not require(await ground(chest.y),"the training board receives the recoil jumper"): return
	mark("p01_deck")
	if not require(await go(chest.x) and await ground(chest.y),"stand beside the physical loft chest"): return
	var old_gold:int=field.active.services.ledger().gold
	await tick(8)
	await interact()
	# Coins follow the normal pickup physics, so walk the top after opening.
	await tick(60)
	if not require(await go(deck.end.x-12) and await go(deck.position.x+13) and await go(chest.x),"walk the practice loft to pick up the actual bouncing money bag"): return
	await tick(20)
	if not require(field.active.services.ledger().gold==old_gold+5,"the opened chest awards precisely five physically collected coins"): return
	mark("p01_chest")
	await interact()
	await tick(16)
	if not require(field.active.services.ledger().gold==old_gold+5,"the open chest cannot issue a second drop"): return
	if not require(await go(deck.end.x+32) and await ground(grass_y),"stepping off the deck returns to supported grass"): return
	var destination:=field.passage_attempts
	if not require(await go(east.x-96) and field.passage_attempts==destination and field.active.controller.actor_resources.health.current==hp,"practice and its fall do not cost health or trigger a distant gate"): return
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
	var lane := 388.0
	if not require(await go(lane) and await ground(576),"step off the west field into the optional grass lane"): return false
	var bug: EnemyActor = field.active.room.enemies.grass_verge_grub
	for i: int in 8:
		if bug.health.terminal: break
		var aim := (bug.motor.position-field.active.player.position+Vector2(0,3)).normalized()
		action(&"shoot_release",aim)
		await tick(26)
	if not require(bug.health.terminal,"the ordinary gun clears the sheltered field grub"): return false
	if not await go(307): return false
	# A close-range shot can recoil into the recessed bank. Return to its
	# observation lip before walking down to the passage.
	if field.active.player.position.y > 695:
		if not await climb_grass_recess(654): return false
	if field.active.player.position.y > 630:
		if not await climb_grass_recess(576): return false
	if not require(await ground(576) and field.active.state.has("discover_p02_low_slope"),"the grass observation lip is supported before descending"): return false
	await tick(26)
	var mouth:=Vector2(270,617)
	var shaft:=Vector2(242,736)
	var cover:=preload("p02_grass_mask.gd")
	if not require(cover.opacity(field.active,mouth)<.15 and cover.opacity(field.active,shaft)>.95,"close grass reveals the adjoining mouth while the lower shaft stays veiled"): return false
	mark("p02_grass")
	if not require(await go(240) and await cross("P16",0),"the discovered grass chute reaches its receiver"): return false
	var lower: Dictionary = field.active_doc.exits.d009
	if not require(await ground(float(lower.spawn[1])) and await go(float(lower.point[0])),"stand beneath the return opening"): return false
	action(&"jump")
	if not require(await cross("P02",0) and await ground(732),"P16 returns to the protected grass ledge"): return false
	action(&"jump_release")
	if not await climb_grass_recess(654) or not await climb_grass_recess(576): return false
	if not require(await go(389),"leave the revealed grass on foot"): return false
	if not await jump_toward(433,494,"use the western shoulder to regain the upper field"): return false
	return await jump_toward(336,413.8593,"regain the clear launch ground")

func cross_field_east() -> bool:
	if not await hidden_field_detour(): return false
	mark("p02_launch")
	await tick(25)
	if not require(await go(354) and await ground(413.8593),"reach the outer west field"): return false
	if not await jump_toward(729,413.8593,"a backward recoil lands beneath the bell",Vector2(-1,.55),12): return false
	mark("p02_bell")
	await tick(20)
	if not await go(784): return false
	if not await jump_toward(1060,449.8593,"a normal jump crosses the shorter offset ditch",Vector2.ZERO,32): return false
	if not await go(1266): return false
	if not await jump_toward(1335,425.8593,"step up from the lower field toward the road",Vector2.ZERO,10): return false
	var grub: EnemyActor=field.active.room.enemies.east_road_grub
	for i: int in 190:
		if grub.motor.position.x-field.active.player.position.x<109 and grub.brain.direction<0: break
		await tick()
	if not await jump_toward(1577,425.8593,"vault the remaining road patrol",Vector2.ZERO,35): return false
	mark("p02_east")
	return require(await cross("P03",1) and await ground(float(field.active_doc.exits.d002.spawn[1])),"cross the physical east door into the ravine")

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
	if not await go(1580): return false
	var enemy: EnemyActor=field.active.room.enemies.east_road_grub
	for i: int in 280:
		if field.active.player.position.x-enemy.motor.position.x<112 and enemy.brain.direction>0: break
		await tick()
	if not await jump_toward(1300,425.8593,"westbound vault passes the live road patrol",Vector2.ZERO,32): return false
	if not await go(983): return false
	if not await jump_toward(739,413.8593,"return up the eastern fork using a rearward shot",Vector2(1,.50),12): return false
	if not await go(657): return false
	if not await jump_toward(305,413.8593,"reverse recoil crosses the main field break",Vector2(1,.55),12): return false
	return require(await cross("P01",-1) and await ground(float(field.active_doc.exits.d001.spawn[1])),"the three-room route returns to the supported P01 eastern apron")

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

# A player's full-height jump, with steering free after takeoff. Wait for the
# real descending landing before starting the next section of the switchback.
func switch_jump(takeoff: int, x: int, floor_y: int) -> bool:
	if not require(await go(takeoff),"stand on the takeoff lip at "+str(takeoff)): return false
	input_axis(0)
	action(&"jump")
	await tick(10)
	var reached:=await go(x)
	await tick(13)
	action(&"jump_release")
	return require(reached and await ground(floor_y-18),"land on the supported grass crown at "+str(Vector2(x,floor_y)))

func switch_drop(x: int, floor_y: int) -> bool:
	return require(await go(x) and await ground(floor_y-18),"recover onto the lower shelf at "+str(Vector2(x,floor_y)))

func p03_stairway() -> bool:
	mark("p03_start")
	if not require(await ground(1350),"P02 feeds the lower western field road"): return false
	var hp:=field.active.controller.actor_resources.health.current
	var grub: EnemyActor=field.active.room.enemies.ravine_floor_grub
	var before_shots:=fired
	if not await switch_jump(155,250,1340): return false
	var before:int=field.active.services.ledger().gold
	await interact()
	low_coin_total=field.active.services.ledger().gold
	await interact()
	if not require(low_coin_total==before+5 and field.active.services.ledger().gold==low_coin_total,"actively search the visible stone cache only once"): return false
	if not require(not grub.health.terminal and fired==before_shots,"the early field patrol can be passed on the stone bank without clearing it"): return false
	mark("p03_bottom")
	if not await switch_jump(309,353,1240): return false
	if not await switch_drop(298,1340): return false
	if not require(field.active.controller.actor_resources.health.current==hp,"an early miss lands on the previous shelf without damage"): return false
	mark("p03_retry")
	if not await switch_jump(309,357,1240): return false
	if not await switch_jump(366,455,1136): return false
	mark("p03_turn")
	await tick(22)
	if not await switch_jump(434,359,1040): return false
	if not await switch_jump(341,231,943): return false
	var sentry: EnemyActor=field.active.room.enemies.ridge_watch_sentry
	mark("p03_sentry")
	for i: int in 4:
		if sentry.health.terminal: break
		if not require(await go(226),"east edge of the west guard's bench"): return false
		var direction:=field.active.player.position.direction_to(sentry.motor.position+Vector2(0,4))
		action(&"shoot_release",direction)
		await tick(30)
	if not require(sentry.health.terminal,"a supported shot clears the watching sentry while leaving the low grub alive"): return false
	mark("p03_sentry_clear")
	if not await switch_jump(238,296,846): return false
	mark("p03_look")
	await tick(35)
	var view:=root.get_visible_rect()
	var relic: WorldSpriteAnimation=field.connection.objects.wr_TG02.get_child(0)
	var body:=field.active.player.get_node("CollisionShape2D") as CollisionShape2D
	if not require(relic.is_visible_in_tree() and view.encloses(relic.get_global_transform_with_canvas()*relic.get_rect()) and view.encloses(body.get_global_transform_with_canvas()*body.shape.get_rect()),"the first-visit traverse frames both the standing player and the actual glint across the ridge"): return false
	mark("p03_look_end")
	if not await switch_jump(382,435,743): return false
	if not await switch_jump(411,353,645): return false
	if not await switch_jump(291,226,540): return false
	if not await switch_jump(238,300,442): return false
	if not await switch_jump(365,418,341): return false
	if not await switch_jump(402,337,249): return false
	if not await switch_jump(254,199,168): return false
	mark("p03_road")
	if not require(wall_kicks==0 and not field.active.controller.traversal.wall_enabled,"first climb and all reversals use the basic jump without W"): return false
	if not require(await cross("P04",-1),"leave the upper road for P04"): return false
	mark("p03_end")
	return true

func p03_east_return() -> bool:
	if not require(await cross("P03",1),"walk back from P04 through the upper P03 gate"): return false
	# Attempt to skip the wall trial by riding a recoil east from the upper road.
	if not await go(214): return false
	input_axis(1)
	action(&"jump")
	await tick(12)
	action(&"shoot_release",Vector2(-1,.25).normalized())
	await tick(87)
	action(&"jump_release")
	input_axis(0)
	if not require(field.active.player.position.x<496 and not field.active.state.value.gear_ids.carried.has("TG02"),"solid limestone separates the high road from the eastern hollow"): return false
	# Repeatedly walk off the exposed edges. Catch decks interrupt a missed ascent.
	for step in [[350,442],[230,540],[345,645],[205,761],[318,846],[189,943],[355,1040],[438,1136],[250,1158],[211,1340]]:
		if not await switch_drop(step[0],step[1]): return false
	if not require(await go(306),"overlook the lower field patrol from the stone lip"): return false
	var grub: EnemyActor=field.active.room.enemies.ravine_floor_grub
	for i: int in 3:
		if grub.health.terminal: break
		var dir:=field.active.player.position.direction_to(grub.motor.position+Vector2(0,4))
		action(&"shoot_release",dir)
		await tick(32)
	if not await switch_drop(350,1424): return false
	if not require(await go(630) and await ground(1406),"traverse beneath the backbone to the actual eastern wall foot"): return false
	var kicks_before:=wall_kicks
	var apex:=field.active.player.position.y
	input_axis(1)
	action(&"jump")
	for i: int in 118:
		await tick()
		if i==13: action(&"shoot_release",Vector2.DOWN)
		if i in [29,46]: action(&"jump")
		apex=minf(apex,field.active.player.position.y)
	input_axis(0)
	action(&"jump_release")
	if not require(apex>888 and wall_kicks==kicks_before and await ground(1406),"a pre-W gun recoil cannot reach the east ledge from its real approach"): return false
	if not carried_wall_progress(): return false
	mark("p03_w_start")
	if not await kick_to_gallery(680,870): return false
	var gear:=FixedWorldProvider.point(field.active_doc.sites.wr_TG02.at)
	if not require(await go(gear.x) and await ground(gear.y) and not field.active.state.value.gear_ids.carried.has("TG02"),"stand at the gear without receiving it automatically"): return false
	await interact()
	await interact()
	if not require(field.active.state.value.gear_ids.carried.count("TG02")==1,"W access pays one TG02 on interaction"): return false
	mark("p03_gear")
	await tick(42)
	mark("p03_w_end")
	if not require(await cross("P13",1) and await cross("P03",-1),"walk through both sides of d017 without a door-level condition"): return false
	if not require(field.active.state.value.gear_ids.carried.count("TG02")==1,"the true gear survives the eastern round trip"): return false
	if not await switch_drop(605,1424): return false
	if not await go(353): return false
	if not await switch_jump(350,299,1340): return false
	return await switch_drop(142,1368)

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
