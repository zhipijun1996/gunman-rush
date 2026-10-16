extends SceneTree
## Controlled wall delay proves transport only, never game/device performance.
const TRACE := preload("res://tests/level_formal_trace.gd")
class Stall:
	extends Node
	var armed := false
	var controller: PlayerController
	var not_before_tick := 0
	var stalls: Array = []
	func _process(_delta: float) -> void:
		if armed and controller._tick >= not_before_tick:
			armed = false
			var start := Time.get_ticks_usec()
			OS.delay_msec(130)
			stalls.append({"start_usec": start, "end_usec": Time.get_ticks_usec()})
var player: PlayerMotor
var controller: PlayerController
var driver: RefCounted
var stall: Stall
var shots: Array = []
var rejects: Array = []
var cases: Array = []
var blank_app: DemoApp
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(0, 320)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2000, 40)
	shape.shape = rectangle
	body.add_child(shape)
	root.add_child(body)
	player = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(0, 282)
	root.add_child(player)
	controller = player.get_node("Controller")
	controller.enable_shot_energy()
	controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, id: int): shots.append({"time_usec": Time.get_ticks_usec(), "id": id, "controller_tick": controller._tick}))
	controller.router.action_rejected.connect(func(reason: String): rejects.append(reason))
	stall = Stall.new()
	stall.controller = controller
	root.add_child(stall)
	blank_app = DemoApp.new() # Only null build accessor; not a substitute live-region claim.
	driver = TRACE.new()
	driver.tree = self
	driver.motor = player
	driver.controller = controller
	driver.app = blank_app
	driver.observe_input_timing = true
	controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, id: int): driver.event("shot_accepted_probe", {"controller_tick_at_signal": controller._tick, "shot_id": id}))
	for mode: String in ["legacy_predraw", "visible_postdraw", "postdraw_new_request_deliberately_expired"]:
		driver.visible_input_post_draw = mode != "legacy_predraw"
		await driver.tick(35)
		stall.not_before_tick = controller._tick + 1
		stall.armed = true
		await driver.tick()
		var shots_before := shots.size()
		var rejects_before := rejects.size()
		var energy_before := controller.actor_resources.stamina.current
		var requested := controller.router.request_action(&"shoot_release", Vector2.UP)
		var original: Dictionary = controller.router._queue.back().duplicate(true)
		if mode == "postdraw_new_request_deliberately_expired": OS.delay_msec(130)
		await driver.tick()
		var observed: Dictionary = driver.observed_frames.back()
		cases.append({"mode": mode, "requested": requested, "original_request": original, "observed_frame": observed, "boundary": observed.input_timing, "accepted_count": shots.size() - shots_before, "router_rejected_signal_count": rejects.size() - rejects_before, "energy_before": energy_before, "energy_after": controller.actor_resources.stamina.current, "stalls": stall.stalls.duplicate(true)})
	var ok: bool = cases[0].accepted_count == 0 and cases[0].boundary.queued[0].age_seconds > InputRouter.MAX_AGE_SECONDS and cases[1].accepted_count == 1 and cases[1].boundary.queued[0].age_seconds < InputRouter.MAX_AGE_SECONDS and cases[2].accepted_count == 0 and cases[2].boundary.queued[0].age_seconds > InputRouter.MAX_AGE_SECONDS
	var hashes: Dictionary = {}
	for path: String in ["res://tests/level_formal_trace.gd", "res://tools/level_formal_capture.gd", "res://scripts/input/input_router.gd", "res://scripts/player/player_controller.gd", "res://scripts/player/player_motor.gd", "res://build/region_production_v3/independent/capture_input_timing_review/probe.gd"]: hashes[path] = FileAccess.get_sha256(path)
	var file := FileAccess.open("res://build/region_production_v3/independent/capture_input_timing_review/probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Actual original Player/Router/normally scheduled Controller; actual production driver.tick; one controlled process delay per case; no manual stepping or resource grant; not content/device/performance proof", "passed": ok, "all_frames": driver.observed_frames, "cases": cases, "shots": shots, "source_hashes": hashes}) + "\n")
	file.close()
	player.free()
	blank_app.free()
	print("VISIBLE INPUT TIMING PROBE: ", ok)
	quit(0 if ok else 1)
