extends SceneTree
## Mobile-size host path through the forest latch, W shaft and two chosen fights.
var errors := 0
var checks := 0
var host: WorldGameHost
class Storage extends WorldSaveService:
	var data := {}
	var sequence := 0
	func commit(value: Dictionary, revision: int) -> bool:
		data=value.duplicate(true)
		sequence=revision
		return true
	func load_profile() -> Dictionary:
		return {"accepted":true,"revision":sequence,"payload":data.duplicate(true)}
class ForestHost extends WorldGameHost:
	func startup_destination() -> Dictionary:
		storage=Storage.new()
		return {"ok":true,"room":"F08"}

func _initialize() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i: int in n: await physics_frame
func check(result: bool,note: String) -> void:
	checks+=1
	if not result:
		errors+=1
		printerr("FAIL forest route ",note," ",host.active.player.position)
func run() -> void:
	host=ForestHost.new()
	root.add_child(host)
	await frames(7)
	await shortcut()
	await front_gate()
	await duel("F11","hollow_antler")
	host.enter_room("F19","")
	await frames(7)
	host.active.player.reset_at(host.active.room.rest_point)
	await frames(5)
	host.active.controller.router.request_action(&"interact")
	await frames(4)
	check(host.active.equipment_menu.panel.visible and host.active.equipment_menu.mode=="rest","open the veranda station")
	host.active.equipment_menu.rest.pressed.emit()
	for tick in 300:
		await frames(1)
		if not is_instance_valid(host.active.rest_sequence) or not host.active.rest_sequence.active: break
	check(host.active.state.value.rest.room=="F19" and not paused,"veranda charge completed and gameplay resumed")
	check(host.active.controller.actor_resources.health.current==host.active.controller.actor_resources.health.capacity,"rest at the actual practice-house veranda")
	await duel("F_IN01","reed_mentor")
	print("THORN FOREST ROUTES checks=",checks," failures=",errors)
	await host.active.audio_service.shutdown()
	host.free()
	quit(1 if errors else 0)

func shortcut() -> void:
	var session:=host.active
	session.controller.router.set_move_axis(1)
	for tick: int in 150:
		await frames(1)
		if session.player.position.x>=642: break
	session.controller.router.set_move_axis(0)
	await frames(6)
	session.controller.router.request_action(&"interact")
	await frames(8)
	check(session.state.has("forest_slope_return_open"),"walk from the forest to its inside handle")
	session.controller.router.set_move_axis(1)
	for tick: int in 180:
		await frames(1)
		if host.active!=session and not host.crossing: break
	check(host.active.room.room_id=="P01" and not host.crossing,"the same controller walks into the plains")
	host.active.controller.router.set_move_axis(0)

func front_gate() -> void:
	host.enter_room("F01","d222")
	await frames(8)
	var session:=host.active
	check(session.room.room_id=="F01" and not session.state.has("W"),"neutral forest vestibule")
	session.controller.router.set_move_axis(-1)
	await frames(138)
	var foot := session.player.position
	check(foot.x>1014 and foot.x<1042 and foot.y>750,"unassisted approach stops on the exterior buttress")
	session.controller.router.request_action(&"jump")
	await frames(66)
	check(session.player.position.x>1014 and session.player.position.y>750,"ordinary jump returns to the same forecourt")
	# The real G08 world event normally owns this save flag. This independent
	# replay starts at the moment that ability has been brought back to the tree.
	var next:=session.state.candidate()
	next.flags.append("W")
	check(session.state.commit(next,session.state.revision),"carry the W ability back from G08")
	var kicks:=0
	var climbed:=false
	session.controller.router.set_move_axis(-1)
	session.controller.router.request_action(&"jump")
	for tick: int in 430:
		await frames(1)
		var travel:=session.controller.traversal
		if session.player.position.y<312:
			session.controller.router.set_move_axis(-1)
			if session.player.position.x<996:
				climbed=true
				break
		elif travel.state==&"wall_attach" and travel.wall_ready:
			var side:=travel.wall_normal
			session.controller.router.request_action(&"jump")
			await frames(1)
			session.controller.router.set_move_axis(side)
			kicks+=1
	session.controller.router.set_move_axis(0)
	check(kicks>=2 and climbed,"alternating real W jumps climb the root ridge; kicks="+str(kicks))

func duel(room_id: String, id: String) -> void:
	host.enter_room(room_id,"")
	await frames(5)
	var session:=host.active
	if not session.room.room_id==room_id:
		check(false,room_id+" opens")
		return
	var fight := session.encounters.front() as WorldRoomEncounter
	check(fight.awaiting_challenge and not session.room.enemies.has(id),room_id+" remains quiet until invited")
	session.player.reset_at(fight.position)
	await frames(7)
	session.controller.router.request_action(&"interact")
	await frames(8)
	if not session.room.enemies.has(id):
		check(false,"physical invitation deploys "+id)
		return
	var actor: EnemyActor=session.room.enemies[id]
	var original_hp:=actor.health.current
	var observed := {}
	var cross := false
	var attacks := false
	for tick: int in 1700:
		if actor.health.terminal: break
		await frames(1)
		if not is_instance_valid(actor):
			check(false,room_id+" duel survived the chosen route")
			return
		var behavior:=actor.attack_behavior
		observed[behavior.state]=true
		if behavior.state==&"attack" and behavior.attack_goal.y<behavior.home.y and absf(actor.motor.position.x-actor.attack_behavior.attack_origin.x)>14:
			cross=true
		if not behavior._projectiles.is_empty(): attacks=true
		var wanted_x := clampf(actor.motor.position.x-132,590,1080)
		session.controller.router.set_move_axis(signf(wanted_x-session.player.position.x) if absf(wanted_x-session.player.position.x)>12 else 0.0)
		var catch_projectile := id=="reed_mentor" and behavior.state==&"attack" and actor.motor.position.distance_to(session.player.position)<360
		var avoid_body := behavior.state==&"attack" and actor.motor.position.distance_to(session.player.position)<155
		if (catch_projectile or avoid_body) and session.player.is_on_floor():
			session.controller.router.request_action(&"jump")
		if tick%30==0 and session.player.position.distance_to(actor.motor.position)<260 and (actor.health.current>original_hp*.5 or cross):
			session.controller.router.request_action(&"shoot_release",session.player.position.direction_to(actor.motor.position))
	session.controller.router.set_move_axis(0)
	check(observed.has(&"telegraph") and observed.has(&"recovery") and attacks,id+" commits a visible ranged first attack and recovers")
	check(actor.health.current<original_hp,id+" accepts actual player projectiles")
	check(cross,id+" makes a physical late-phase pounce or relocation")
	check(actor.health.terminal,id+" can be defeated by the normal weapon")
	if not actor.health.terminal:return
	session.player.reset_at(fight.position)
	await frames(14)
	var gold: int = session.services.ledger().gold
	session.controller.router.request_action(&"interact")
	await frames(12)
	check(session.state.has("encounter_"+room_id+"_clear") and session.services.ledger().gold==gold+130,id+" grants exactly its locked first victory purse")
