extends SceneTree

var failures := 0
const ROOM := "res://tests/crossing_sensor_demo.json"

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func ticks(count: int) -> void:
	for frame: int in count: await physics_frame

func run() -> void:
	var doc := WorldRoomDocument.read(ROOM)
	for bad: Dictionary in [{"line_points":[[0,0],[0,0]]},{"line_points":[[0,0]]},{"cross_direction":"right"},{"trigger_mode":"repeat"}]:
		var invalid := doc.duplicate(true)
		invalid.entities.trip.properties.merge(bad,true)
		check(WorldRoomDocument.instantiate(invalid).has("error"), "reject "+str(bad))
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	if not error.is_empty():
		check(false,error)
		quit(1)
		return
	var sensor: WorldCrossingSensor = session.room.element_runtime.nodes.trip
	var gate: WorldElementGate = session.room.element_runtime.nodes.gate
	await ticks(20)
	session.controller.router.set_move_axis(1)
	await ticks(54)
	check(session.player.position.x > 332 and sensor.active and gate.active,"walk across and open")
	session.controller.router.set_move_axis(-1)
	await ticks(64)
	session.controller.router.set_move_axis(0)
	check(session.player.position.x < 308 and not sensor.active and not gate.active,"return across toggles")
	session.player.reset_at(Vector2(380,366))
	await ticks(4)
	check(not sensor.active, "teleport across is silent")
	sensor.cross_direction = "negative_to_positive"
	session.player.apply_impulse(Vector2(-4200,0))
	await ticks(3)
	check(session.player.position.x < 308 and not sensor.active,"reject reverse high-speed crossing")
	session.player.reset_at(Vector2(264,328))
	session.player.apply_impulse(Vector2(4200,0))
	await ticks(3)
	check(session.player.position.x > 332 and sensor.active and gate.active,"forward airborne sweep opens")
	sensor.cross_direction = "positive_to_negative"
	session.player.reset_at(Vector2(390,220))
	session.player.apply_impulse(Vector2(-4200,0))
	await ticks(3)
	check(sensor.active, "passing beyond segment ends is silent")
	session.player.reset_at(Vector2(380,366))
	session.player.apply_impulse(Vector2(-4200,0))
	await ticks(3)
	check(not sensor.active and not gate.active,"reverse filter accepts reverse sweep")
	session.player.reset_at(Vector2(320,366))
	await ticks(12)
	check(not sensor.active, "resting on line does not activate")
	sensor.trigger_mode = "once"
	sensor.cross_direction = "both"
	session.player.reset_at(Vector2(290,366))
	session.player.apply_impulse(Vector2(4200,0))
	await ticks(3)
	session.player.reset_at(Vector2(356,366))
	session.player.apply_impulse(Vector2(-4200,0))
	await ticks(3)
	check(sensor.active and gate.active, "once stays open on subsequent crossing")
	check(session.state.value.mechanisms.is_empty(), "no permanent progress from temporary crossing")
	check(await session.audio_service.shutdown(), "audio released")
	session.free()
	var fresh := OrdinaryRoomSession.new()
	root.add_child(fresh)
	check(fresh.open(doc).is_empty() and not fresh.room.element_runtime.nodes.trip.active, "new attempt starts on entry side")
	check(await fresh.audio_service.shutdown(), "fresh audio released")
	fresh.free()
	print("CROSSING SENSOR failures=",failures)
	quit(1 if failures else 0)
