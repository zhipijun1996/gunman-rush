extends SceneTree
## Exercise the production world scene, its input adapters and its actual rendered camera.

class IsolatedSlot extends PlayableWorldSave:
	var payload := {}
	var saved_revision := 0
	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":payload.duplicate(true),"revision":saved_revision}
	func commit(candidate: Dictionary, revision: int) -> bool:
		payload = candidate.duplicate(true)
		saved_revision = revision
		return true

var host: WorldGameHost
var checks := 0
var failures := 0
var audio_tracks: Array[WeakRef] = []
var observe_crossing := false
var changed_under_cover := false
var arrival_center := Vector2.INF

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL world camera ",label)

func ticks(count: int) -> void:
	for i in count: await physics_frame

func camera() -> WorldCamera:
	return root.get_camera_2d() as WorldCamera

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	root.push_input(event,true)

func finger(at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.index = 4
	event.pressed = down
	root.push_input(event,true)

func swipe(from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = to
	event.relative = to-from
	event.index = 4
	root.push_input(event,true)

func place(at: Vector2) -> void:
	host.active.player.reset_at(at)
	await ticks(3)
	camera().reset_view()
	await ticks(120)

func inspection(touch: bool) -> void:
	await place(Vector2(962,585))
	var c := camera()
	var body := host.active.player
	var controls := host.active.touch_controls
	controls.set_enabled(touch)
	var at := controls.left_center
	var end := at-Vector2(0,controls.radius)
	var before := c.get_screen_center_position()
	var feet := body.position
	if touch:
		finger(at,true)
		swipe(at,end)
	else:
		key(KEY_UP,true)
	await ticks(12)
	check(not c.looking and absf(c.get_screen_center_position().y-before.y)<2,"short hold waits for deliberate observation")
	await ticks(28)
	var dy40 := c.get_screen_center_position().y-before.y
	await ticks(50)
	var dy90 := c.get_screen_center_position().y-before.y
	check(c.looking and c.controller.router.camera_look_axis<-.9 and dy40 < -25 and dy90 < dy40-1,"real stationary hold moves the camera upward, including before settling")
	check(body.is_on_floor() and body.position.distance_to(feet)<1,"manual inspection leaves both feet on the same support")
	print("WORLD CAMERA INPUT ", "touch" if touch else "keyboard"," dy40=",dy40," dy90=",dy90," zoom=",c.zoom.x)
	if touch: finger(end,false)
	else: key(KEY_UP,false)
	await ticks(120)
	check(not c.looking and c.get_screen_center_position().distance_to(before)<2,"release restores ordinary framing")
	controls.set_enabled(false)

func contact(id: StringName) -> void:
	var session := host.active
	var hit := DamageRequest.new()
	hit.event_id = id
	hit.source_id = &"camera_regression_contact"
	hit.target_id = &"player"
	hit.kind = DamageRequest.Kind.MONSTER
	hit.amount = 1
	hit.token = session.lifetime.token()
	hit.actor_epoch = session.lifetime.actor_epoch
	hit.health_epoch = session.controller.actor_resources.health.epoch
	session.policy.submit(hit)
	session.policy.resolve_batch()

func tremor(c: WorldCamera) -> float:
	# The camera applies shake inside its final legal center range; Camera2D.offset stays zero.
	var delta := (c.get_screen_center_position()-c.base_center).abs()
	return maxf(delta.x,delta.y)

func damage_feedback() -> void:
	await place(Vector2(962,585))
	var c := camera()
	var health := host.active.controller.actor_resources.health
	var hp := health.current
	host.active.policy.protect_player()
	contact(&"protected_touch")
	var protected_peak := 0.0
	for i in 14:
		await physics_frame
		protected_peak = maxf(protected_peak,tremor(c))
	check(is_equal_approx(health.current,hp) and protected_peak<.01,"protected contact preserves health and produces no camera shake")
	await ticks(48)
	contact(&"accepted_touch")
	var peak := 0.0
	for i in 4:
		await physics_frame
		peak = maxf(peak,tremor(c))
	var feedback := preload("res://game/combat/damage/feedback.tres") as DamageFeedbackDefinition
	check(health.current<hp and peak>.1 and peak<=minf(feedback.impact_shake,float(c.settings.shake_max))+.01,"accepted health loss produces actual camera displacement within the configured impact strength")
	var departing_shake := tremor(c)
	host.enter_room("G23","",preload("system_room_fixture.gd").flat("G23"))
	var arriving := camera()
	var residual := 0.0
	for i in 8:
		await physics_frame
		residual = maxf(residual,tremor(arriving))
	check(departing_shake>.01 and host.active.room.room_id=="G23" and residual<.01,"crossing during a live impact clears shake on every sampled destination frame")
	print("WORLD CAMERA IMPACT protected=",protected_peak," hit=",peak," outgoing=",departing_shake," destination=",residual)

func room_limits() -> void:
	host.enter_room("G_IN01","",preload("system_room_fixture.gd").flat("G_IN01",Vector2i(958,570),412))
	await place(Vector2(312,394))
	var c := camera()
	var bounds := FixedWorldProvider.rect(host.active_doc.bounds)
	var half := root.get_visible_rect().size/(2*c.zoom)
	key(KEY_DOWN,true)
	await ticks(100)
	var center := c.get_screen_center_position()
	check(center.y+half.y<=bounds.end.y+1 and center.x-half.x>=bounds.position.x-1 and center.x+half.x<=bounds.end.x+1,"a short room clamps the view horizontally and below its floor")
	key(KEY_DOWN,false)
	await ticks(25)
	key(KEY_UP,true)
	await ticks(100)
	check(c.get_screen_center_position().y-half.y>=bounds.position.y-1 and c.zoom.is_equal_approx(Vector2.ONE*1.6),"upward look respects the actual ceiling without adapting the zoom")
	key(KEY_UP,false)

func landmarks() -> void:
	host.enter_room("P03","")
	if host.last_error!="" or host.active.room.room_id!="P03":
		check(false,"open authored P03 "+host.last_error)
		return
	var document := host.active_doc.duplicate(true)
	await place(FixedWorldProvider.rect(document.scenery.camera_landmark.bounds).get_center())
	var with_landmark := camera().get_screen_center_position()
	var observer := host.active.player.position
	document.scenery.erase("camera_landmark")
	host.enter_room("G12","",preload("system_room_fixture.gd").flat("G12"))
	host.enter_room("P03","",document)
	await place(observer)
	var ordinary := camera().get_screen_center_position()
	print("WORLD CAMERA LANDMARK baseline=",ordinary," framed=",with_landmark," body=",host.active.player.position," error=",host.last_error)
	check(with_landmark.x>ordinary.x+12 or with_landmark.y<ordinary.y-14,"the actual P03 ledge frames the unclaimed elevated collectible")
	await place(FixedWorldProvider.point(host.active_doc.exits.d003.spawn))
	check(camera().zones.active_id=="old_road" and camera().zoom.is_equal_approx(Vector2.ONE*float(document.camera.zoom)),"P03 upper road selects its own composition at the plains scale")

func zoom_and_conceal() -> void:
	# Build two camera areas on the flat rehearsal floor.
	# A single continuous walk changes the active viewing area; no camera reset during the walk.
	var doc := preload("system_room_fixture.gd").flat("G12")
	doc.camera = {"profile":"bounded_follow","zones":[
		{"id":"street","trigger":[0,0,820,774],"display":[0,0,1120,774],"profile":"bounded_follow","zoom":1.6},
		{"id":"hall","trigger":[820,0,956,774],"display":[656,0,1120,774],"profile":"bounded_follow","zoom":1.85,"conceal":[[872,265,238,95]]}
	],"links":[{"a":"street","b":"hall","axis":"x","direction":1,"band":[754,0,138,774],"display":[0,0,1776,774]}]}
	host.enter_room("G12","",doc)
	if host.last_error!="":
		check(false,"two-zone ordinary room authoring "+host.last_error)
		return
	await place(Vector2(630,585))
	var c := camera()
	var mask := host.active.room.camera_concealers.get("hall") as CanvasItem
	check(mask!=null and mask.visible and c.zones.active_id=="street" and is_equal_approx(c.zoom.x,1.6),"unentered room area uses the real concealment mask")
	key(KEY_D,true)
	var intermediate := false
	var band_visible := false
	for i in 170:
		await physics_frame
		intermediate = intermediate or (c.zoom.x>1.62 and c.zoom.x<1.82)
		band_visible = band_visible or (not c.frame.portal.is_empty() and mask!=null and not mask.visible)
		if host.active.player.position.x>=1012: break
	key(KEY_D,false)
	await ticks(150)
	check(intermediate and band_visible and mask!=null and not mask.visible and c.zones.active_id=="hall" and is_equal_approx(snappedf(c.zoom.x,.01),1.85),"walking through a real portal reveals the linked room and eases to its authored zoom")

func forest_duel() -> void:
	host.enter_room("F11","",preload("system_room_fixture.gd").duel("F11","enc_F11","enemy.forest_antler","hollow_antler"))
	if host.last_error!="" or host.active.room.room_id!="F11":
		check(false,"enter the forest duel "+host.last_error)
		return
	var session := host.active
	var progress := session.state.candidate()
	progress.flags.append("W")
	check(session.state.commit(progress,session.state.revision),"the isolated visitor has the F11 challenge prerequisite")
	var fight := session.encounters.front() as WorldRoomEncounter
	var c := camera()
	await place(fight.position+fight.start_offset)
	check(fight.awaiting_challenge and not fight.battle_active() and c.zones.active_id=="main","the unfought forest floor keeps ordinary framing")
	session.controller.router.request_action(&"interact")
	await ticks(32)
	var antler := session.room.enemies.get("hollow_antler") as EnemyActor
	if antler==null:
		check(false,"the invited forest opponent actually enters")
		return
	check(fight.battle_active() and c.zones.active_id=="arena","a deployed duel participant activates the floor's camera zone")
	key(KEY_UP,true)
	await ticks(42)
	check(not c.looking and c.zones.active_id=="arena","manual observation is suppressed while fighting in the bounded arena")
	key(KEY_UP,false)
	# This probe needs the real victory transition. Attack patterns are covered independently.
	var accepted := antler.damageable.receive_damage({"event_id":"camera_forest_finish","amount":antler.health.current,
		"source_faction":&"player","target_actor_id":antler.damageable.actor_id,"target_epoch":antler.damageable.damage_epoch,"hit_direction":Vector2.RIGHT})
	session.policy.resolve_batch()
	await ticks(12)
	check(accepted and antler.health.terminal and fight.battle_active(),"the camera remains in the engagement until victory is recorded")
	session.player.reset_at(fight.position)
	await ticks(6)
	session.controller.router.request_action(&"interact")
	await ticks(45)
	check(not fight.battle_active() and session.state.has(fight.encounter.completion_flag) and c.zones.active_id=="main","confirmed victory hands the camera back to the ordinary room")

func on_room_changed(id: String) -> void:
	if not observe_crossing or id!="P03": return
	var c := camera()
	changed_under_cover = host.crossing and host.curtain.visible and host.curtain.color.a>.99 and c!=null and c.target==host.active.player
	if c!=null: arrival_center=c.get_screen_center_position()

func passage() -> void:
	host.enter_room("P02","")
	await place(FixedWorldProvider.point(host.active_doc.exits.d002.spawn))
	var old_center := camera().get_screen_center_position()
	observe_crossing = true
	key(KEY_D,true)
	var first_reveal := Vector2.INF
	for i in 190:
		await physics_frame
		if host.active.room.room_id=="P03" and (not host.curtain.visible or host.curtain.color.a<.99):
			if not first_reveal.is_finite(): first_reveal=camera().get_screen_center_position()
			if not host.crossing: break
	key(KEY_D,false)
	observe_crossing = false
	print("WORLD CAMERA DOOR room=",host.active.room.room_id," error=",host.last_error," at=",host.active.player.position)
	check(host.active.room.room_id=="P03" and not host.crossing and host.last_error.is_empty(),"walk crosses the paired P02/P03 door")
	print("WORLD CAMERA TRANSFER covered=",changed_under_cover," old=",old_center," covered_center=",arrival_center," exposed_center=",first_reveal)
	check(changed_under_cover and arrival_center.is_finite() and first_reveal.is_finite() and first_reveal.distance_to(arrival_center)<60 and first_reveal.distance_to(old_center)>600,"first visible destination frame has no interpolation from the old room")
	host.enter_room("P01","")
	var before := host.active
	var denied: bool = not host.catalog.passage_access("P01","d223",before.state.value.flags).matches
	var exit_row: Dictionary = host.active_doc.exits.d223
	await place(FixedWorldProvider.point(exit_row.spawn))
	await host.transfer("d223","F08")
	check(denied and host.active==before and not host.crossing and not host.curtain.visible and root.get_camera_2d()==host.follow_camera and host.active.controller.active,"a denied door restores the original camera and controls after the curtain")

func run() -> void:
	root.size = Vector2i(1280,720)
	node_removed.connect(func(node:Node)->void:
		if node is GameAudio or node is GameAmbience: audio_tracks.append_array(node._playbacks))
	var scene := preload("res://rooms/world/world.tscn")
	host = scene.instantiate() as WorldGameHost
	check(host!=null,"play mounts the continuous world host")
	if host==null:
		quit(1)
		return
	host.storage = IsolatedSlot.new()
	host.room_changed.connect(on_room_changed)
	root.add_child(host)
	await ticks(6)
	check(host.active!=null and host.active.room.room_id=="P01" and camera()!=null and camera()==host.follow_camera and camera().target==host.active.player,"the world opens P01 with the original WorldCamera following the live player")
	if camera()!=null:
		host.enter_room("G12","",preload("system_room_fixture.gd").flat("G12"))
		await inspection(false)
		await inspection(true)
		await damage_feedback()
		await room_limits()
		await landmarks()
		await zoom_and_conceal()
		await forest_duel()
		await passage()
	if host.active!=null: await host.active.audio_service.shutdown()
	host.free()
	var until := Time.get_ticks_msec()+2000
	while audio_tracks.any(func(track:WeakRef)->bool:return track.get_ref()!=null) and Time.get_ticks_msec()<until: await process_frame
	print("WORLD CAMERA MIGRATION failures=",failures," checks=",checks)
	quit(1 if failures else 0)
