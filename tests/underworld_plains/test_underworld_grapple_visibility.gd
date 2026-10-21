extends SceneTree
## Real input/Controller/Motor with the formal shared body and hidden legacy FX.
## This GPU regression isolates essential grapple rendering, not a Forest route.
## Counterexample hides only the body canvas while its Controller physics callback is suspended: pixels
## away from the body must disappear, proving a rope was actually rendered.
var checks := 0
var failures: Array[String] = []
var world: Node2D
var motor: PlayerMotor
var controller: PlayerController
var art: UnderworldPlayer
var observed: Dictionary = {}
var case_observed: Dictionary = {}
var range_cases: Array[Dictionary] = []
var hook_anchor: GrappleAnchor
var evidence: Array[Dictionary] = []
const OUTPUT := "res://build/underworld_grapple_visibility"

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func frame() -> void:
	await physics_frame
	await RenderingServer.frame_post_draw
	observed[String(controller.traversal.state)] = true
	case_observed[String(controller.traversal.state)] = true

func fixture(with_anchor: bool, original_out_of_range := false) -> void:
	if is_instance_valid(world): world.free()
	hook_anchor = null
	case_observed.clear()
	world = Node2D.new()
	root.add_child(world)
	var background := ColorRect.new()
	background.position = Vector2(-1000, -1000)
	background.size = Vector2(4000, 3000)
	background.color = Color("172b25")
	background.z_index = -10
	world.add_child(background)
	var ground := StaticBody2D.new()
	ground.position = Vector2(500, 530)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(2000, 60)
	shape.shape = box
	ground.add_child(shape)
	world.add_child(ground)
	motor = preload("res://scenes/player/player.tscn").instantiate()
	motor.position = Vector2(280, 482) # Initial fixture spawn only.
	world.add_child(motor)
	controller = motor.get_node("Controller") as PlayerController
	for name: String in ["KeyboardMouseAdapter", "PlayerVisualAdapter"]:
		motor.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	motor.get_node("CourierVisual").hide()
	var legacy := motor.get_node("PlayerFeedback") as PlayerFeedback
	legacy.hide()
	legacy.effects_enabled = false # Reduced cosmetic FX must not hide the rope.
	art = UnderworldPlayer.new()
	art.motor = motor
	art.controller = controller
	motor.add_child(art)
	controller.traversal.grant(&"grapple")
	var camera := Camera2D.new()
	camera.position = Vector2(440, 270)
	world.add_child(camera)
	if with_anchor:
		hook_anchor = GrappleAnchor.new()
		# Original [480,260] is deliberately retained as the real range
		# rejection case. The accepted target changes only initial fixture
		# placement, never the production range or a running player's position.
		hook_anchor.position = Vector2(480,260) if original_out_of_range else Vector2(420,364)
		hook_anchor.hang_enabled = true
		world.add_child(hook_anchor)
	for tick: int in 4: await frame()
	check(art.visible and not legacy.visible and not motor.get_node("CourierVisual").visible, "Sole visible shared body retains hidden legacy particle/anchor drawings")

func capture_rope() -> void:
	# Pausing the SceneTree intentionally cancels real input, so it cannot
	# freeze a live grapple for this render-only control. Suspend only the
	# sole Controller physics callback; no state, pose, resource or body write.
	var position_before := motor.global_position
	var state_before := controller.traversal.state
	var was_physics_processing := controller.is_physics_processing()
	controller.set_physics_process(false)
	var image := root.get_texture().get_image()
	image.save_png(OUTPUT + "/actual-flight.png")
	var transform := art.get_global_transform_with_canvas()
	var player_screen := transform * Vector2.ZERO
	var tip_screen := root.get_canvas_transform() * controller.traversal.hook_tip
	var scan := Rect2(player_screen, Vector2.ZERO).expand(tip_screen).grow(14)
	art.hide()
	await RenderingServer.frame_post_draw
	var hidden := root.get_texture().get_image()
	hidden.save_png(OUTPUT + "/render-only-hidden-control.png")
	var ink := Color("ddc089")
	var changed_rope_pixels := 0
	for y: int in range(maxi(0, floori(scan.position.y)), mini(image.get_height(), ceili(scan.end.y))):
		for x: int in range(maxi(0, floori(scan.position.x)), mini(image.get_width(), ceili(scan.end.x))):
			if Vector2(x,y).distance_to(player_screen) < 38: continue
			var color := image.get_pixel(x,y)
			var control := hidden.get_pixel(x,y)
			var color_error := absf(color.r-ink.r)+absf(color.g-ink.g)+absf(color.b-ink.b)
			var changed := absf(color.r-control.r)+absf(color.g-control.g)+absf(color.b-control.b)
			if color_error < 0.40 and changed > 0.25: changed_rope_pixels += 1
	check(changed_rope_pixels >= 15, "Actual rope pixels beyond the body disappear in the isolated hidden-body GPU counterexample")
	check(motor.global_position == position_before and controller.traversal.state == state_before, "GPU counterexample changes no gameplay position or traversal state")
	evidence.append({"state":String(state_before),"changed_rope_pixels":changed_rope_pixels,"motor_position":[position_before.x,position_before.y],"hook_tip":[controller.traversal.hook_tip.x,controller.traversal.hook_tip.y],"legacy_feedback_visible":motor.get_node("PlayerFeedback").visible,"cosmetic_effects_enabled":(motor.get_node("PlayerFeedback") as PlayerFeedback).effects_enabled})
	art.show()
	controller.set_physics_process(was_physics_processing)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GPU grapple visibility regression requires a real renderer, e.g. xvfb-run; headless lifecycle tests are separate")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	await fixture(true)
	var origin := motor.global_position+Vector2(0,-6)
	var legal_offset := hook_anchor.global_position-origin
	check(legal_offset.length()+controller.traversal.definition.hook_capture_radius < controller.traversal.definition.hook_range, "Accepted fixture target and whole head margin lie inside the actual production range")
	range_cases.append({"case":"inside_actual_range","origin":[origin.x,origin.y],"target":[hook_anchor.global_position.x,hook_anchor.global_position.y],"distance":legal_offset.length(),"actual_range":controller.traversal.definition.hook_range})
	check(controller.router.request_action(&"grapple", legal_offset.normalized()), "Actual Router accepts the legal-target grapple intent")
	var sampled := false
	for tick: int in 90:
		await frame()
		if not sampled and controller.traversal.state == &"hook_fly" and motor.global_position.distance_to(controller.traversal.hook_tip) > 90:
			await capture_rope()
			sampled = true
		if controller.traversal.state == &"hook_hang": break
	check(sampled, "Real accepted Router hook produced a measurable flight before attachment")
	check(controller.traversal.state == &"hook_hang", "Real body reaches the hanging target without fixture teleport")
	controller.router.clear("explicit_presentation_cancel")
	await frame()
	check(controller.traversal.state == &"free", "Real input cancellation clears grapple attachment")
	root.get_texture().get_image().save_png(OUTPUT + "/actual-cancelled.png")
	range_cases[-1].observed_states = case_observed.keys()
	await fixture(true,true)
	origin = motor.global_position+Vector2(0,-6)
	var far_offset := hook_anchor.global_position-origin
	check(far_offset.length()-controller.traversal.definition.hook_capture_radius*2.0 > controller.traversal.definition.hook_range, "Original over-range target remains outside the real swept capture reach")
	range_cases.append({"case":"original_outside_actual_range","origin":[origin.x,origin.y],"target":[hook_anchor.global_position.x,hook_anchor.global_position.y],"distance":far_offset.length(),"actual_range":controller.traversal.definition.hook_range})
	check(controller.router.request_action(&"grapple", far_offset.normalized()), "Actual Router accepts a cast without promising an unreachable attachment")
	for tick: int in 100:
		await frame()
		if tick > 8 and controller.traversal.state == &"free": break
	check(case_observed.has("hook_miss") and case_observed.has("hook_retract") and not case_observed.has("hook_pull") and not case_observed.has("hook_hang"), "Original over-range target produces actual miss/retract and never a fabricated attachment")
	range_cases[-1].observed_states = case_observed.keys()
	for state: String in ["hook_cast","hook_fly","hook_pull","hook_hang","hook_miss","hook_retract","free"]:
		check(observed.has(state), "Actual traversal lifecycle observed " + state)
	check(controller.traversal.state == &"free", "Original over-range cast retracts and restores control")
	var report := {"checks":checks,"failures":failures,"states":observed.keys(),"gpu_samples":evidence,"range_cases":range_cases,"scope":"Real Router/Controller/Motor isolated shared-body GPU visibility with formal hidden-feedback ownership and reduced cosmetic effects. Hidden-body counterexample suspends only the actual Controller physics callback; real pause/cancel semantics remain unchanged. Not a full Forest route, campaign, physical-device or user art acceptance."}
	FileAccess.open(OUTPUT + "/report.json", FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	world.free()
	for tick: int in 4: await process_frame
	print("UNDERWORLD_GRAPPLE_VISIBILITY checks=",checks," failures=",failures.size()," gpu_samples=",evidence.size())
	quit(0 if failures.is_empty() else 1)
