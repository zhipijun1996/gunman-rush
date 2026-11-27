extends SceneTree
## A real G12 floor, ordinary input, the shipped terrain emitter and the
## production host. The extra strip makes hit/return timing deterministic.
class Store extends WorldSaveService:
	var writable := true
	var value := {}
	func commit(payload: Dictionary,_revision: int) -> bool:
		if not writable: return false
		value = payload.duplicate(true)
		return true
	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":{},"revision":0}
class Host extends WorldGameHost:
	func startup_destination() -> Dictionary: return {"ok":true,"room":"G12"}

var host: Host
var slot := Store.new()
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures+=1
		printerr("FAIL terrain ",label)
func ticks(n: int) -> void:
	for i in n: await physics_frame

func hit_again(id: String) -> bool:
	var s:=host.active
	var q:=DamageRequest.new()
	q.token=s.lifetime.token()
	q.health_epoch=s.controller.actor_resources.health.epoch
	q.actor_epoch=s.lifetime.actor_epoch
	q.target_id=&"player"
	q.source_id=&"other_strip"
	q.kind=DamageRequest.Kind.ENVIRONMENT
	q.return_to_safety=true
	q.event_id=StringName(id)
	return s.policy.submit(q)

func run() -> void:
	host=Host.new()
	host.storage=slot
	root.add_child(host)
	var room:=host.active
	await ticks(45)
	var anchor:=room.recovery.entry_point
	var epoch:=room.lifetime.actor_epoch
	var hp:=room.controller.actor_resources.health.current
	var cycle:int=room.state.value.cycle
	check(room.recovery.entry_verified,"old entering side was physically observed before taking damage")
	room.room.add_child(DemoContactEmitter.environment_rect(Rect2(850,567,32,44),room.policy,room.controller,&"test:terrain",true))
	room.controller.router.set_move_axis(1)
	var jumping := false
	for i in 360:
		await physics_frame
		if not jumping and room.player.position.x >= 330 and room.player.is_on_floor():
			room.controller.router.request_action(&"jump")
			jumping = true
		if jumping and room.player.position.x > 560: room.controller.router.request_action(&"jump_release")
		if host.terrain_return!=null: break
	if host.terrain_return==null:
		check(false,"walking into a real terrain strip starts the timeline at "+str(room.player.position))
		quit(1); return
	var sequence:=host.terrain_return
	var impact:=room.player.position
	var old_eye:=room.camera.get_screen_center_position()
	check(host.crossing and paused and not room.controller.active and impact.x>800 and room.controller.actor_resources.health.current==hp-1,"the accepted hit freezes at the physical point and charges one HP")
	check(not hit_again("during"),"additional physical contact is rejected during concealment")
	host.transfer("d001","P02")
	check(host.active==room and host.passage_attempts==0,"a handoff cannot start during the accepted terrain result")
	await ticks(3)
	var age:=sequence.age
	sequence.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await ticks(10)
	check(is_equal_approx(age,sequence.age) and room.player.position.is_equal_approx(impact),"focus loss holds the original body and timeline")
	sequence.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var opaque:=false
	for i in 60:
		await physics_frame
		if room.player.position.distance_to(impact)>10: break
		if host.curtain.color.a>.999: opaque=true
	check(opaque and host.curtain.color.a>.999 and room.player.position.distance_to(anchor)<3,"the hit location gets a full black frame before the actual safe-side return")
	check(room.camera.get_screen_center_position().distance_to(old_eye)>100 and room.camera.target==room.player,"the same camera snaps to the actual restored actor under cover")
	for i in 80:
		await physics_frame
		if not host.crossing: break
	check(not paused and room.controller.active and not host.curtain.visible and room.player.is_on_floor(),"fade-in finishes on real supporting ground before gameplay resumes")
	check(room.lifetime.actor_epoch==epoch+1 and slot.value.hp==hp-1 and slot.value.cycle==cycle,"one relocation saves the damage without healing or advancing a cycle")
	check(not hit_again("protected"),"spawn protection still covers a second independent hazard after reveal")
	await ticks(45)
	room.camera.reduced_effects=true
	room.recovery.entry_point=Vector2(-4000,-1000)
	check(hit_again("invalid_anchor"),"expired protection admits a genuine next terrain failure")
	await ticks(45)
	sequence=host.terrain_return
	if sequence==null:
		check(false,"invalid anchor remains in recoverable state")
		quit(1);return
	check(sequence.reduced and sequence.waiting and host.last_error=="terrain_anchor_unavailable" and room.player.position.distance_to(anchor)<3 and room.lifetime.actor_epoch==epoch+1,"reduced effects and invalid entry keep position and identity, with an explicit retry")
	room.recovery.entry_point=anchor
	slot.writable=false
	for down in [true,false]:
		var tap:=InputEventScreenTouch.new()
		tap.position=sequence.retry_button.get_global_rect().get_center()
		tap.index=2
		tap.pressed=down
		root.push_input(tap,true)
	await ticks(22)
	check(sequence.waiting and sequence.relocated and host.last_error=="terrain_save_failed" and room.lifetime.actor_epoch==epoch+2,"a rejected save retains the verified relocation, without replaying the hit")
	slot.writable=true
	sequence.retry_button.pressed.emit()
	await ticks(45)
	check(not paused and not host.crossing and room.controller.active and room.lifetime.actor_epoch==epoch+2 and slot.value.hp==hp-2 and slot.value.cycle==cycle,"retry saves only the unresolved checkpoint and restores protection")
	await ticks(45)
	check(hit_again("forced_replacement"),"third independent exposure can start")
	await ticks(3)
	host.enter_room("G08","")
	await ticks(8)
	check(host.active!=room and host.active.room.room_id=="G08" and not paused and not host.crossing and host.terrain_return==null and not host.curtain.visible,"a successful forced room replacement releases the old sequence and curtain")
	await ticks(45)
	check(hit_again("leave_world"),"destination can process a new, independently accepted failure")
	await ticks(3)
	host.free()
	await process_frame
	check(not paused,"exiting the application scene during concealment releases the pause it owned")
	print("WORLD TERRAIN RETURN failures=",failures," checks=",checks)
	quit(1 if failures else 0)
